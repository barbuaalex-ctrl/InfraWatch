# Tutorial — agentul Linux

Agentul monitorizează calculatorul Linux pe care îl pornești: VM, server fizic sau EC2. Nu are nevoie de monitor ori interfață grafică; îl poți folosi din terminalul VS Code conectat prin SSH.

Ai nevoie de **Linux și Python 3.9 sau mai nou**. Agentul folosește biblioteca standard Python: nu instalezi pachete cu pip și nu ai nevoie de sudo pentru rularea manuală.

## 1. Alege adresa dashboardului

| Unde rulează agentul | Adresa folosită în proiect |
| --- | --- |
| Pe același Debian ca aplicația Docker/Nginx | http://127.0.0.1:8080 |
| Pe alt dispozitiv Linux din aceeași rețea | http://VM_IP:8080 |
| Pe EC2, cu tunelul SSH descris mai jos | http://127.0.0.1:9000 |

`127.0.0.1` este întotdeauna dispozitivul pe care rulează comanda. Un EC2 nu poate accesa direct un IP privat de acasă, precum 192.168.x.x.

Exemplul local folosește portul 8080, deoarece aplicația este accesată prin Nginx. Pentru o aplicație standalone pornită cu npm start, portul implicit este 3000.

## 2. Descarcă și extrage — pe dispozitivul Linux

1. În dashboard, autentifică-te ca administrator.
2. Intră în **Download agent** și descarcă arhiva **Linux**.
3. Transferă ZIP-ul pe dispozitivul de monitorizat, dacă l-ai descărcat în altă parte.
4. Extrage arhiva.
5. Deschide folderul **InfraWatch-Agent** într-un terminal.

Pentru arhiva v0.10.0, dacă ZIP-ul se află în folderul curent:

```bash
unzip infrawatch-agent-linux-v0.10.0.zip
cd InfraWatch-Agent
python3 --version
python3 agent.py --version
```

Înlocuiește numele ZIP-ului când descarci altă versiune. Dacă unzip nu este instalat, poți extrage arhiva din interfața grafică sau, pe Debian/Ubuntu, îl poți instala cu `sudo apt install unzip`.

Păstrează agent.py și version.json împreună. Nu este necesar să faci scriptul executabil când îl rulezi cu python3.

## 3. Pornește și aprobă dispozitivul

Pentru test pe același Debian unde rulează aplicația:

```bash
python3 agent.py --server http://127.0.0.1:8080
```

Pentru alt server din rețeaua locală:

```bash
python3 agent.py --server http://VM_IP:8080
```

Înlocuiește VM_IP cu adresa reală a VM-ului care găzduiește dashboardul.

1. În terminal apare **Pairing code: ABC-234**.
2. Copiază codul. În terminalul integrat VS Code pe Linux poți folosi Ctrl+Shift+C.
3. În dashboard deschide **Devices → Add device → Computer / Server**.
4. Introdu codul sau lipește-l în câmp. Numele de afișare este opțional.
5. Apasă **Connect device** înainte de expirarea codului, în maximum cinci minute.
6. Așteaptă apariția metricilor în dashboard.

La prima asociere nu introduci manual token sau server ID. Agentul le primește după aprobarea făcută de administrator.

Mesajul `Connected. Sending metrics every second.` arată că agentul a încărcat o conexiune, dar confirmarea că livrarea funcționează este actualizarea dispozitivului în dashboard. Dacă imediat după mesaj apare o eroare, urmează indicația ei.

## 4. Ce raportează

- CPU: utilizarea calculată între citiri.
- RAM: procentul de memorie utilizată.
- Disk: spațiul ocupat și GB liberi/total pe sistemul de fișiere rădăcină `/`.
- Uptime: timpul de la pornirea Linux.
- Inventar: hostname, distribuție, kernel, arhitectură, procesor, RAM și stocare.

GPU este **indisponibil** în agentul Linux actual. Nu este trimisă o valoare artificială de 0%.

Metricile urmăresc o actualizare pe secundă. Întârzierile de rețea și erorile pot reduce frecvența. Inventarul componentelor se actualizează aproximativ o dată pe oră.

Agentul Linux raportează capacitatea sistemului de fișiere `/`; nu reprezintă automat toate discurile montate și nici activitatea I/O dintr-un manager de procese.

## 5. Oprire și reconectare

Pentru agentul pornit manual:

- Lasă terminalul deschis cât timp dorești monitorizarea.
- Apasă **Ctrl+C** pentru oprire.
- Rulează din nou aceeași comandă pentru reconectare.

Asocierea se păstrează implicit în:

```text
~/.config/infrawatch-agent/connection.json
```

Nu trebuie să aprobi alt cod la fiecare pornire. Folosește același utilizator Linux și același director de stare. Rularea cu sudo ar folosi alt utilizator și poate crea o asociere separată.

Fișierul de conexiune este privat și nu trebuie trimis altor persoane ori copiat pe alte dispozitive.

## 6. Test separat sau asociere nouă

Dacă vrei să separi testul local de o conexiune existentă:

```bash
python3 agent.py --server http://127.0.0.1:8080 --state-dir ~/.config/infrawatch-local-test
```

Agentul păstrează asocierea în directorul indicat prin --state-dir. Folosește același director și la următoarea pornire.

Dacă primești `Device connection rejected` după ștergerea dispozitivului din dashboard, verifică mai întâi că ai adresa aplicației corecte. Pentru o asociere nouă, alege un director nefolosit:

```bash
python3 agent.py --server http://127.0.0.1:8080 --state-dir ~/.config/infrawatch-local-test-2
```

Aprobă codul nou în dashboard. Această comandă creează o asociere nouă; nu repară sau șterge automat dispozitivul vechi.

Dacă mesajul spune că directorul aparține altui server InfraWatch, folosește adresa salvată sau un director nou. Chiar și două adrese care duc la aceeași aplicație sunt comparate ca adrese diferite de agent.

## 7. Actualizarea agentului Linux

În această versiune, actualizarea Linux este manuală:

1. Oprește agentul cu Ctrl+C.
2. Descarcă și extrage noua arhivă Linux.
3. Înlocuiește agent.py și version.json.
4. Păstrează directorul de stare cu connection.json.
5. Pornește din nou agentul cu aceeași adresă și același --state-dir, dacă l-ai folosit.

Nu copia fișierul de conexiune al altui dispozitiv. Updaterul cu buton din agentul Windows nu se aplică agentului Linux.

## 8. EC2 creat prin Terraform în acest proiect

Terraform instalează deja agentul și serviciul systemd pe EC2. **Nu mai porni în paralel încă o copie manuală a agentului pe EC2.**

De pe Debian, deschide tunelul către IP-ul EC2 afișat de Terraform:

```bash
ssh -i ~/.ssh/infrawatch-ec2 -o ExitOnForwardFailure=yes -R 127.0.0.1:9000:127.0.0.1:8080 ec2-user@EC2_PUBLIC_IP
```

Înlocuiește EC2_PUBLIC_IP. Păstrează sesiunea deschisă: portul 9000 de pe EC2 duce acum către aplicația de pe Debian.

În terminalul EC2:

```bash
sudo cloud-init status --wait
sudo journalctl -u infrawatch-agent -n 20 --no-pager
```

Copiază codul afișat și aprobă-l în dashboard. Dacă serviciul rulează deja și are o asociere validă, nu mai apare un cod nou.

Comenzi utile, **rulate pe EC2**:

```bash
sudo systemctl status infrawatch-agent --no-pager
sudo systemctl stop infrawatch-agent
sudo systemctl start infrawatch-agent
sudo systemctl restart infrawatch-agent
```

Stop oprește serviciul acum, dar nu îl dezactivează pentru următoarea pornire a sistemului. Serviciul creat de Terraform folosește directorul de stare `/var/lib/infrawatch-agent`, diferit de cel al unui agent pornit manual de utilizator.

La reboot, systemd pornește agentul automat. Metricile ajung în dashboard numai dacă aplicația și tunelul funcționează. Dacă închizi SSH, tunelul se închide și dispozitivul va apărea offline.

Pentru detaliile Terraform și ștergerea resurselor, vezi [ghidul demonstrației](../devops/DEMO.md).

## 9. Probleme frecvente

| Mesaj sau simptom | Rezolvare |
| --- | --- |
| Cannot reach InfraWatch | Verifică adresa și portul din perspectiva dispozitivului pe care rulează agentul. Pentru EC2 verifică tunelul. |
| version.json is missing | Extrage arhiva completă și păstrează version.json lângă agent.py. |
| Code expired | Agentul Linux solicită automat un cod nou. Citește ultimul cod din terminal/log. |
| Monitoring paused | Reia monitorizarea din Device Settings în dashboard. |
| Device connection rejected | Verifică aplicația țintă; dacă dispozitivul a fost șters, asociază-l din nou într-un director de stare nou. |
| Dispozitiv duplicat | Poate ai folosit alt utilizator sau alt --state-dir. Revino la asocierea corectă și oprește copia suplimentară. |
| Offline după închiderea terminalului | Pentru rularea manuală, procesul trebuie să rămână activ. Pe EC2 folosește serviciul deja creat. |
| IP-ul privat al VM-ului nu merge de pe EC2 | Folosește tunelul; adresa privată nu este accesibilă direct din AWS. |
