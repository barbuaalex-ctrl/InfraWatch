# Demonstrație InfraWatch

Comenzile sunt separate după calculatorul pe care trebuie rulate. Înlocuiește `VM_IP` și `EC2_PUBLIC_IP` cu adresele actuale. Nu copia textul promptului terminalului.

## 1. Verificarea aplicației — terminal pe Debian

```bash
cd ~/infrawatchapp
git status --short
docker compose --env-file devops/.env -f devops/compose.yaml ps
cat devops/nginx/active.inc
curl -i http://localhost:8080/health
```

Așteptat: o instanță a aplicației activă, Nginx pornit și HTTP 200. Deschide `http://VM_IP:8080` în browser. Instanța oprită este cea de rezervă.

## 2. Deploy și rollback — în GitHub

În Actions → InfraWatch Deploy:

1. Selectează main și un tag publicat, de exemplu ci-14.
2. Pentru deploy normal, lasă test_rollback debifat.
3. Urmărește identificarea instanței active, descărcarea imaginii, backup-ul și activarea țintei.
4. Verifică din nou serviciile și /health folosind comenzile de mai sus.

Poți folosi același tag pentru a demonstra alternarea instanțelor; asta nu demonstrează o modificare a funcționalității aplicației.

Pentru rollback, rulează din nou workflow-ul cu test_rollback bifat. Este așteptată o rulare roșie: scriptul provoacă intenționat o eroare și revine la instanța anterioară. Arată în log mesajul de revenire, apoi HTTP 200 și dashboardul funcțional.

Nu lansa două deploy-uri sau comenzi manuale de activare în paralel.

## 3. Pregătirea Terraform — terminal pe Debian

Necesare: Terraform, AWS CLI, profilul AWS default în `~/.aws/credentials`, cheia SSH locală și acces la internet. Nu pune cheile AWS sau cheia SSH privată în repository.

```bash
cd ~/infrawatchapp/devops/terraform
aws sts get-caller-identity
ls -l ~/.ssh/infrawatch-ec2.pub
```

Dacă este o instalare nouă și cheia nu există, creeaz-o o singură dată:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/infrawatch-ec2
```

Nu suprascrie o cheie existentă. Terraform încarcă în AWS numai fișierul public .pub; cheia privată rămâne pe Debian.

Verifică înainte de plan:

- Regiunea din providers.tf este eu-central-1, iar profilul este default.
- Rețeaua folosește VPC-ul implicit; acesta trebuie să existe în regiune.
- Regula SSH din network.tf trebuie să conțină IP-ul public al conexiunii curente, cu /32. Dacă prezinți din altă rețea, actualizează regula și verifică planul. IP-ul VM-ului din LAN nu este IP-ul public.
- Căile `../../app/` din main.tf sunt relative la devops/terraform și indică sursele agentului din același repository. Verifică existența lor înainte de plan.

```bash
ls -l ../../app/agent/linux/agent.py ../../app/agent/version.json
terraform init
terraform validate
terraform plan -out=ec2-demo.tfplan
```

Planul salvat conține exact modificările pe care urmează să le aplici. Citește-l înainte de apply. Dacă mediul nu are resursele proiectului, configurația creează trei resurse administrate: instanța, cheia publică și Security Group-ul. Dacă există deja, planul poate arăta alt rezultat.

```bash
terraform apply ec2-demo.tfplan
terraform output -raw server_ip
```

Folosește IP-ul afișat. Nu reutiliza un IP dintr-o demonstrație anterioară.

## 4. Tunelul — pornește de pe Debian

Aplicația rămâne pe Debian. EC2 nu poate accesa direct adresa privată a VM-ului de acasă. Tunelul face legătura de la portul local 9000 al EC2 către Nginx de pe Debian, prin conexiunea SSH.

```bash
ssh -i ~/.ssh/infrawatch-ec2 -o ExitOnForwardFailure=yes -R 127.0.0.1:9000:127.0.0.1:8080 ec2-user@EC2_PUBLIC_IP
```

Această comandă deschide și terminalul EC2. Lasă sesiunea deschisă cât timp demonstrezi monitorizarea. Portul 9000 nu este expus public pe EC2. Dacă SSH refuză conexiunea imediat după creare, așteaptă pornirea serverului și încearcă din nou.

## 5. Verificarea agentului — acum în terminalul EC2

```bash
sudo cloud-init status --wait
sudo systemctl status infrawatch-agent --no-pager
sudo journalctl -u infrawatch-agent -n 20 --no-pager
```

User data instalează Python și agentul la prima pornire, creează utilizatorul serviciului și activează serviciul systemd. Agentul încearcă să contacteze `http://127.0.0.1:9000`, adresa capătului de tunel de pe EC2.

Citește codul temporar din log, apoi în dashboard: Devices → Add device → Computer / Server. Introdu codul înainte să expire și aprobă dispozitivul ca administrator.

Arată dispozitivul în Overview și Device details: hostname, Linux, CPU, RAM, uptime și spațiu liber. GPU este indisponibil pe agentul Linux.

Serviciul pornește automat la boot și păstrează conexiunea aprobată. Transmiterea metricilor depinde în continuare de dashboard și tunelul SSH. Un EC2 recreat este un dispozitiv nou și necesită aprobare nouă.

## 6. Test local opțional — terminal separat pe Debian

După descărcarea și extragerea agentului Linux, deschide folderul InfraWatch-Agent:

```bash
python3 agent.py --server http://127.0.0.1:8080 --state-dir ~/.config/infrawatch-local-test
```

Aprobă codul în dashboard dacă acest director nu conține deja o conexiune validă. Păstrează același director pentru reconectare. Ctrl+C oprește acest agent lansat manual.

`127.0.0.1` funcționează aici deoarece agentul rulează pe același Debian ca dashboardul. Pentru alt dispozitiv din LAN se folosește adresa VM-ului. Dacă o conexiune salvată este respinsă după ștergerea dispozitivului din aplicație, folosește un director de stare nou și aprobă un cod nou.

## 7. După demonstrație

Închide sesiunea SSH cu `exit`; tunelul se închide și EC2 va apărea offline după lipsa metricilor.

Pentru ștergerea resurselor administrate de această configurație, din terminalul Debian:

```bash
cd ~/infrawatchapp/devops/terraform
terraform plan -destroy -out=cleanup.tfplan
```

Citește resursele propuse pentru ștergere. Numai dacă acestea sunt cele pe care dorești să le elimini:

```bash
terraform apply cleanup.tfplan
```

Ștergerea EC2 elimină și discul rădăcină configurat pentru ștergere la terminare. Nu șterge fișierul de stare Terraform pentru a opri infrastructura. Dacă doar oprești EC2 din consolă, discul rămâne și poate genera costuri; la repornire IP-ul public se poate schimba. Terraform apply nu este o comandă generală de pornire a unei instanțe oprite.

Pentru a opri aplicația locală, după încheierea demonstrației:

```bash
cd ~/infrawatchapp
docker compose --env-file devops/.env -f devops/compose.yaml --profile standby stop
```

Comanda păstrează containerele și volumul. La reluare, citește active.inc, pornește explicit numai serviciul indicat acolo, așteaptă healthy și pornește Nginx.

## Ce explic la prezentare

- Docker împachetează aplicația și dependențele într-o imagine reproductibilă.
- GHCR păstrează imaginile; tagul ci-N permite alegerea unui build.
- CI verifică sursele înainte de publicare. CD aplică buildul ales pe runnerul Debian.
- Nginx oferă o adresă stabilă, indiferent de instanța activă.
- Volumul păstrează datele când containerul este înlocuit.
- Deploy-ul oprește scrierile pentru backup și activare; are o întrerupere controlată.
- Terraform descrie și creează serverul monitorizat; user data instalează agentul; systemd îl supraveghează.
- Tunelul SSH asigură legătura către aplicația de acasă fără expunerea publică a dashboardului.
- Instalarea agentului este automată, dar asocierea inițială se aprobă manual prin cod temporar.

Păstrează capturi cu CI reușit, deploy reușit, rollback demonstrat și dispozitivul EC2 online, pentru cazul în care conexiunea de la prezentare nu este disponibilă.
