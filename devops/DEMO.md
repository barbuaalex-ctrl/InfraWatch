# DemonstraÈ›ie InfraWatch

Comenzile sunt separate dupÄƒ calculatorul pe care trebuie rulate. ÃŽnlocuieÈ™te `VM_IP` È™i `EC2_PUBLIC_IP` cu adresele actuale. Nu copia textul promptului terminalului.

## 1. Verificarea aplicaÈ›iei â€” terminal pe Debian

```bash
cd ~/infrawatchapp
git status --short
docker compose --env-file devops/.env -f devops/compose.yaml ps
cat devops/nginx/active.inc
curl -i http://localhost:8080/health
```

AÈ™teptat: o instanÈ›Äƒ a aplicaÈ›iei activÄƒ, Nginx pornit È™i HTTP 200. Deschide `http://VM_IP:8080` Ã®n browser. InstanÈ›a opritÄƒ este cea de rezervÄƒ.

## 2. Deploy È™i rollback â€” Ã®n GitHub

ÃŽn Actions â†’ InfraWatch Deploy:

1. SelecteazÄƒ main È™i un tag publicat, de exemplu ci-14.
2. Pentru deploy normal, lasÄƒ test_rollback debifat.
3. UrmÄƒreÈ™te identificarea instanÈ›ei active, descÄƒrcarea imaginii, backup-ul È™i activarea È›intei.
4. VerificÄƒ din nou serviciile È™i /health folosind comenzile de mai sus.

PoÈ›i folosi acelaÈ™i tag pentru a demonstra alternarea instanÈ›elor; asta nu demonstreazÄƒ o modificare a funcÈ›ionalitÄƒÈ›ii aplicaÈ›iei.

Pentru rollback, ruleazÄƒ din nou workflow-ul cu test_rollback bifat. Este aÈ™teptatÄƒ o rulare roÈ™ie: scriptul provoacÄƒ intenÈ›ionat o eroare È™i revine la instanÈ›a anterioarÄƒ. AratÄƒ Ã®n log mesajul de revenire, apoi HTTP 200 È™i dashboardul funcÈ›ional.

Nu lansa douÄƒ deploy-uri sau comenzi manuale de activare Ã®n paralel.

## 3. PregÄƒtirea Terraform â€” terminal pe Debian

Necesare: Terraform, AWS CLI, profilul AWS default Ã®n `~/.aws/credentials`, cheia SSH localÄƒ È™i acces la internet. Nu pune cheile AWS sau cheia SSH privatÄƒ Ã®n repository.

```bash
cd ~/infrawatchapp/devops/terraform
aws sts get-caller-identity
ls -l ~/.ssh/infrawatch-ec2.pub
```

DacÄƒ este o instalare nouÄƒ È™i cheia nu existÄƒ, creeaz-o o singurÄƒ datÄƒ:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/infrawatch-ec2
```

Nu suprascrie o cheie existentÄƒ. Terraform Ã®ncarcÄƒ Ã®n AWS numai fiÈ™ierul public .pub; cheia privatÄƒ rÄƒmÃ¢ne pe Debian.

VerificÄƒ Ã®nainte de plan:

- Regiunea din providers.tf este eu-central-1, iar profilul este default.
- ReÈ›eaua foloseÈ™te VPC-ul implicit; acesta trebuie sÄƒ existe Ã®n regiune.
- Regula SSH din network.tf trebuie sÄƒ conÈ›inÄƒ IP-ul public al conexiunii curente, cu /32. DacÄƒ prezinÈ›i din altÄƒ reÈ›ea, actualizeazÄƒ regula È™i verificÄƒ planul. IP-ul VM-ului din LAN nu este IP-ul public.
- CÄƒile `../../app/` din main.tf sunt relative la devops/terraform È™i indicÄƒ sursele agentului din acelaÈ™i repository. VerificÄƒ existenÈ›a lor Ã®nainte de plan.

```bash
ls -l ../../app/agent/linux/agent.py ../../app/agent/version.json
terraform init
terraform validate
terraform plan -out=ec2-demo.tfplan
```

Planul salvat conÈ›ine exact modificÄƒrile pe care urmeazÄƒ sÄƒ le aplici. CiteÈ™te-l Ã®nainte de apply. DacÄƒ mediul nu are resursele proiectului, configuraÈ›ia creeazÄƒ trei resurse administrate: instanÈ›a, cheia publicÄƒ È™i Security Group-ul. DacÄƒ existÄƒ deja, planul poate arÄƒta alt rezultat.

```bash
terraform apply ec2-demo.tfplan
terraform output -raw server_ip
```

FoloseÈ™te IP-ul afiÈ™at. Nu reutiliza un IP dintr-o demonstraÈ›ie anterioarÄƒ.

## 4. Tunelul â€” porneÈ™te de pe Debian

AplicaÈ›ia rÄƒmÃ¢ne pe Debian. EC2 nu poate accesa direct adresa privatÄƒ a VM-ului de acasÄƒ. Tunelul face legÄƒtura de la portul local 9000 al EC2 cÄƒtre Nginx de pe Debian, prin conexiunea SSH.

```bash
ssh -i ~/.ssh/infrawatch-ec2 -o ExitOnForwardFailure=yes -R 127.0.0.1:9000:127.0.0.1:8080 ec2-user@EC2_PUBLIC_IP
```

AceastÄƒ comandÄƒ deschide È™i terminalul EC2. LasÄƒ sesiunea deschisÄƒ cÃ¢t timp demonstrezi monitorizarea. Portul 9000 nu este expus public pe EC2. DacÄƒ SSH refuzÄƒ conexiunea imediat dupÄƒ creare, aÈ™teaptÄƒ pornirea serverului È™i Ã®ncearcÄƒ din nou.

## 5. Verificarea agentului â€” acum Ã®n terminalul EC2

```bash
sudo cloud-init status --wait
sudo systemctl status infrawatch-agent --no-pager
sudo journalctl -u infrawatch-agent -n 20 --no-pager
```

User data instaleazÄƒ Python È™i agentul la prima pornire, creeazÄƒ utilizatorul serviciului È™i activeazÄƒ serviciul systemd. Agentul Ã®ncearcÄƒ sÄƒ contacteze `http://127.0.0.1:9000`, adresa capÄƒtului de tunel de pe EC2.

CiteÈ™te codul temporar din log, apoi Ã®n dashboard: Devices â†’ Add device â†’ Computer / Server. Introdu codul Ã®nainte sÄƒ expire È™i aprobÄƒ dispozitivul ca administrator.

AratÄƒ dispozitivul Ã®n Overview È™i Device details: hostname, Linux, CPU, RAM, uptime È™i spaÈ›iu liber. GPU este indisponibil pe agentul Linux.

Serviciul porneÈ™te automat la boot È™i pÄƒstreazÄƒ conexiunea aprobatÄƒ. Transmiterea metricilor depinde Ã®n continuare de dashboard È™i tunelul SSH. Un EC2 recreat este un dispozitiv nou È™i necesitÄƒ aprobare nouÄƒ.

## 6. Test local opÈ›ional â€” terminal separat pe Debian

DupÄƒ descÄƒrcarea È™i extragerea agentului Linux, deschide folderul InfraWatch-Agent:

```bash
python3 agent.py --server http://127.0.0.1:8080 --state-dir ~/.config/infrawatch-local-test
```

AprobÄƒ codul Ã®n dashboard dacÄƒ acest director nu conÈ›ine deja o conexiune validÄƒ. PÄƒstreazÄƒ acelaÈ™i director pentru reconectare. Ctrl+C opreÈ™te acest agent lansat manual.

`127.0.0.1` funcÈ›ioneazÄƒ aici deoarece agentul ruleazÄƒ pe acelaÈ™i Debian ca dashboardul. Pentru alt dispozitiv din LAN se foloseÈ™te adresa VM-ului. DacÄƒ o conexiune salvatÄƒ este respinsÄƒ dupÄƒ È™tergerea dispozitivului din aplicaÈ›ie, foloseÈ™te un director de stare nou È™i aprobÄƒ un cod nou.

## 7. DupÄƒ demonstraÈ›ie

ÃŽnchide sesiunea SSH cu `exit`; tunelul se Ã®nchide È™i EC2 va apÄƒrea offline dupÄƒ lipsa metricilor.

Pentru È™tergerea resurselor administrate de aceastÄƒ configuraÈ›ie, din terminalul Debian:

```bash
cd ~/infrawatchapp/devops/terraform
terraform plan -destroy -out=cleanup.tfplan
```

CiteÈ™te resursele propuse pentru È™tergere. Numai dacÄƒ acestea sunt cele pe care doreÈ™ti sÄƒ le elimini:

```bash
terraform apply cleanup.tfplan
```

È˜tergerea EC2 eliminÄƒ È™i discul rÄƒdÄƒcinÄƒ configurat pentru È™tergere la terminare. Nu È™terge fiÈ™ierul de stare Terraform pentru a opri infrastructura. DacÄƒ doar opreÈ™ti EC2 din consolÄƒ, discul rÄƒmÃ¢ne È™i poate genera costuri; la repornire IP-ul public se poate schimba. Terraform apply nu este o comandÄƒ generalÄƒ de pornire a unei instanÈ›e oprite.

Pentru a opri aplicaÈ›ia localÄƒ, dupÄƒ Ã®ncheierea demonstraÈ›iei:

```bash
cd ~/infrawatchapp
docker compose --env-file devops/.env -f devops/compose.yaml --profile standby stop
```

Comanda pÄƒstreazÄƒ containerele È™i volumul. La reluare, citeÈ™te active.inc, porneÈ™te explicit numai serviciul indicat acolo, aÈ™teaptÄƒ healthy È™i porneÈ™te Nginx.

## Ce explic la prezentare

- Docker Ã®mpacheteazÄƒ aplicaÈ›ia È™i dependenÈ›ele Ã®ntr-o imagine reproductibilÄƒ.
- GHCR pÄƒstreazÄƒ imaginile; tagul ci-N permite alegerea unui build.
- CI verificÄƒ sursele Ã®nainte de publicare. CD aplicÄƒ buildul ales pe runnerul Debian.
- Nginx oferÄƒ o adresÄƒ stabilÄƒ, indiferent de instanÈ›a activÄƒ.
- Volumul pÄƒstreazÄƒ datele cÃ¢nd containerul este Ã®nlocuit.
- Deploy-ul opreÈ™te scrierile pentru backup È™i activare; are o Ã®ntrerupere controlatÄƒ.
- Terraform descrie È™i creeazÄƒ serverul monitorizat; user data instaleazÄƒ agentul; systemd Ã®l supravegheazÄƒ.
- Tunelul SSH asigurÄƒ legÄƒtura cÄƒtre aplicaÈ›ia de acasÄƒ fÄƒrÄƒ expunerea publicÄƒ a dashboardului.
- Instalarea agentului este automatÄƒ, dar asocierea iniÈ›ialÄƒ se aprobÄƒ manual prin cod temporar.

PÄƒstreazÄƒ capturi cu CI reuÈ™it, deploy reuÈ™it, rollback demonstrat È™i dispozitivul EC2 online, pentru cazul Ã®n care conexiunea de la prezentare nu este disponibilÄƒ.
