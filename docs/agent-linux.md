# Tutorial â€” agentul Linux

Agentul monitorizeazÄƒ calculatorul Linux pe care Ã®l porneÈ™ti: VM, server fizic sau EC2. Nu are nevoie de monitor ori interfaÈ›Äƒ graficÄƒ; Ã®l poÈ›i folosi din terminalul VS Code conectat prin SSH.

Ai nevoie de **Linux È™i Python 3.9 sau mai nou**. Agentul foloseÈ™te biblioteca standard Python: nu instalezi pachete cu pip È™i nu ai nevoie de sudo pentru rularea manualÄƒ.

## 1. Alege adresa dashboardului

| Unde ruleazÄƒ agentul | Adresa folositÄƒ Ã®n proiect |
| --- | --- |
| Pe acelaÈ™i Debian ca aplicaÈ›ia Docker/Nginx | http://127.0.0.1:8080 |
| Pe alt dispozitiv Linux din aceeaÈ™i reÈ›ea | http://VM_IP:8080 |
| Pe EC2, cu tunelul SSH descris mai jos | http://127.0.0.1:9000 |

`127.0.0.1` este Ã®ntotdeauna dispozitivul pe care ruleazÄƒ comanda. Un EC2 nu poate accesa direct un IP privat de acasÄƒ, precum 192.168.x.x.

Exemplul local foloseÈ™te portul 8080, deoarece aplicaÈ›ia este accesatÄƒ prin Nginx. Pentru o aplicaÈ›ie standalone pornitÄƒ cu npm start, portul implicit este 3000.

## 2. DescarcÄƒ È™i extrage â€” pe dispozitivul Linux

1. ÃŽn dashboard, autentificÄƒ-te ca administrator.
2. IntrÄƒ Ã®n **Download agent** È™i descarcÄƒ arhiva **Linux**.
3. TransferÄƒ ZIP-ul pe dispozitivul de monitorizat, dacÄƒ l-ai descÄƒrcat Ã®n altÄƒ parte.
4. Extrage arhiva.
5. Deschide folderul **InfraWatch-Agent** Ã®ntr-un terminal.

Pentru arhiva v0.10.0, dacÄƒ ZIP-ul se aflÄƒ Ã®n folderul curent:

```bash
unzip infrawatch-agent-linux-v0.10.0.zip
cd InfraWatch-Agent
python3 --version
python3 agent.py --version
```

ÃŽnlocuieÈ™te numele ZIP-ului cÃ¢nd descarci altÄƒ versiune. DacÄƒ unzip nu este instalat, poÈ›i extrage arhiva din interfaÈ›a graficÄƒ sau, pe Debian/Ubuntu, Ã®l poÈ›i instala cu `sudo apt install unzip`.

PÄƒstreazÄƒ agent.py È™i version.json Ã®mpreunÄƒ. Nu este necesar sÄƒ faci scriptul executabil cÃ¢nd Ã®l rulezi cu python3.

## 3. PorneÈ™te È™i aprobÄƒ dispozitivul

Pentru test pe acelaÈ™i Debian unde ruleazÄƒ aplicaÈ›ia:

```bash
python3 agent.py --server http://127.0.0.1:8080
```

Pentru alt server din reÈ›eaua localÄƒ:

```bash
python3 agent.py --server http://VM_IP:8080
```

ÃŽnlocuieÈ™te VM_IP cu adresa realÄƒ a VM-ului care gÄƒzduieÈ™te dashboardul.

1. ÃŽn terminal apare **Pairing code: ABC-234**.
2. CopiazÄƒ codul. ÃŽn terminalul integrat VS Code pe Linux poÈ›i folosi Ctrl+Shift+C.
3. ÃŽn dashboard deschide **Devices â†’ Add device â†’ Computer / Server**.
4. Introdu codul sau lipeÈ™te-l Ã®n cÃ¢mp. Numele de afiÈ™are este opÈ›ional.
5. ApasÄƒ **Connect device** Ã®nainte de expirarea codului, Ã®n maximum cinci minute.
6. AÈ™teaptÄƒ apariÈ›ia metricilor Ã®n dashboard.

La prima asociere nu introduci manual token sau server ID. Agentul le primeÈ™te dupÄƒ aprobarea fÄƒcutÄƒ de administrator.

Mesajul `Connected. Sending metrics every second.` aratÄƒ cÄƒ agentul a Ã®ncÄƒrcat o conexiune, dar confirmarea cÄƒ livrarea funcÈ›ioneazÄƒ este actualizarea dispozitivului Ã®n dashboard. DacÄƒ imediat dupÄƒ mesaj apare o eroare, urmeazÄƒ indicaÈ›ia ei.

## 4. Ce raporteazÄƒ

- CPU: utilizarea calculatÄƒ Ã®ntre citiri.
- RAM: procentul de memorie utilizatÄƒ.
- Disk: spaÈ›iul ocupat È™i GB liberi/total pe sistemul de fiÈ™iere rÄƒdÄƒcinÄƒ `/`.
- Uptime: timpul de la pornirea Linux.
- Inventar: hostname, distribuÈ›ie, kernel, arhitecturÄƒ, procesor, RAM È™i stocare.

GPU este **indisponibil** Ã®n agentul Linux actual. Nu este trimisÄƒ o valoare artificialÄƒ de 0%.

Metricile urmÄƒresc o actualizare pe secundÄƒ. ÃŽntÃ¢rzierile de reÈ›ea È™i erorile pot reduce frecvenÈ›a. Inventarul componentelor se actualizeazÄƒ aproximativ o datÄƒ pe orÄƒ.

Agentul Linux raporteazÄƒ capacitatea sistemului de fiÈ™iere `/`; nu reprezintÄƒ automat toate discurile montate È™i nici activitatea I/O dintr-un manager de procese.

## 5. Oprire È™i reconectare

Pentru agentul pornit manual:

- LasÄƒ terminalul deschis cÃ¢t timp doreÈ™ti monitorizarea.
- ApasÄƒ **Ctrl+C** pentru oprire.
- RuleazÄƒ din nou aceeaÈ™i comandÄƒ pentru reconectare.

Asocierea se pÄƒstreazÄƒ implicit Ã®n:

```text
~/.config/infrawatch-agent/connection.json
```

Nu trebuie sÄƒ aprobi alt cod la fiecare pornire. FoloseÈ™te acelaÈ™i utilizator Linux È™i acelaÈ™i director de stare. Rularea cu sudo ar folosi alt utilizator È™i poate crea o asociere separatÄƒ.

FiÈ™ierul de conexiune este privat È™i nu trebuie trimis altor persoane ori copiat pe alte dispozitive.

## 6. Test separat sau asociere nouÄƒ

DacÄƒ vrei sÄƒ separi testul local de o conexiune existentÄƒ:

```bash
python3 agent.py --server http://127.0.0.1:8080 --state-dir ~/.config/infrawatch-local-test
```

Agentul pÄƒstreazÄƒ asocierea Ã®n directorul indicat prin --state-dir. FoloseÈ™te acelaÈ™i director È™i la urmÄƒtoarea pornire.

DacÄƒ primeÈ™ti `Device connection rejected` dupÄƒ È™tergerea dispozitivului din dashboard, verificÄƒ mai Ã®ntÃ¢i cÄƒ ai adresa aplicaÈ›iei corecte. Pentru o asociere nouÄƒ, alege un director nefolosit:

```bash
python3 agent.py --server http://127.0.0.1:8080 --state-dir ~/.config/infrawatch-local-test-2
```

AprobÄƒ codul nou Ã®n dashboard. AceastÄƒ comandÄƒ creeazÄƒ o asociere nouÄƒ; nu reparÄƒ sau È™terge automat dispozitivul vechi.

DacÄƒ mesajul spune cÄƒ directorul aparÈ›ine altui server InfraWatch, foloseÈ™te adresa salvatÄƒ sau un director nou. Chiar È™i douÄƒ adrese care duc la aceeaÈ™i aplicaÈ›ie sunt comparate ca adrese diferite de agent.

## 7. Actualizarea agentului Linux

ÃŽn aceastÄƒ versiune, actualizarea Linux este manualÄƒ:

1. OpreÈ™te agentul cu Ctrl+C.
2. DescarcÄƒ È™i extrage noua arhivÄƒ Linux.
3. ÃŽnlocuieÈ™te agent.py È™i version.json.
4. PÄƒstreazÄƒ directorul de stare cu connection.json.
5. PorneÈ™te din nou agentul cu aceeaÈ™i adresÄƒ È™i acelaÈ™i --state-dir, dacÄƒ l-ai folosit.

Nu copia fiÈ™ierul de conexiune al altui dispozitiv. Updaterul cu buton din agentul Windows nu se aplicÄƒ agentului Linux.

## 8. EC2 creat prin Terraform Ã®n acest proiect

Terraform instaleazÄƒ deja agentul È™i serviciul systemd pe EC2. **Nu mai porni Ã®n paralel Ã®ncÄƒ o copie manualÄƒ a agentului pe EC2.**

De pe Debian, deschide tunelul cÄƒtre IP-ul EC2 afiÈ™at de Terraform:

```bash
ssh -i ~/.ssh/infrawatch-ec2 -o ExitOnForwardFailure=yes -R 127.0.0.1:9000:127.0.0.1:8080 ec2-user@EC2_PUBLIC_IP
```

ÃŽnlocuieÈ™te EC2_PUBLIC_IP. PÄƒstreazÄƒ sesiunea deschisÄƒ: portul 9000 de pe EC2 duce acum cÄƒtre aplicaÈ›ia de pe Debian.

ÃŽn terminalul EC2:

```bash
sudo cloud-init status --wait
sudo journalctl -u infrawatch-agent -n 20 --no-pager
```

CopiazÄƒ codul afiÈ™at È™i aprobÄƒ-l Ã®n dashboard. DacÄƒ serviciul ruleazÄƒ deja È™i are o asociere validÄƒ, nu mai apare un cod nou.

Comenzi utile, **rulate pe EC2**:

```bash
sudo systemctl status infrawatch-agent --no-pager
sudo systemctl stop infrawatch-agent
sudo systemctl start infrawatch-agent
sudo systemctl restart infrawatch-agent
```

Stop opreÈ™te serviciul acum, dar nu Ã®l dezactiveazÄƒ pentru urmÄƒtoarea pornire a sistemului. Serviciul creat de Terraform foloseÈ™te directorul de stare `/var/lib/infrawatch-agent`, diferit de cel al unui agent pornit manual de utilizator.

La reboot, systemd porneÈ™te agentul automat. Metricile ajung Ã®n dashboard numai dacÄƒ aplicaÈ›ia È™i tunelul funcÈ›ioneazÄƒ. DacÄƒ Ã®nchizi SSH, tunelul se Ã®nchide È™i dispozitivul va apÄƒrea offline.

Pentru detaliile Terraform È™i È™tergerea resurselor, vezi [ghidul demonstraÈ›iei](../devops/DEMO.md).

## 9. Probleme frecvente

| Mesaj sau simptom | Rezolvare |
| --- | --- |
| Cannot reach InfraWatch | VerificÄƒ adresa È™i portul din perspectiva dispozitivului pe care ruleazÄƒ agentul. Pentru EC2 verificÄƒ tunelul. |
| version.json is missing | Extrage arhiva completÄƒ È™i pÄƒstreazÄƒ version.json lÃ¢ngÄƒ agent.py. |
| Code expired | Agentul Linux solicitÄƒ automat un cod nou. CiteÈ™te ultimul cod din terminal/log. |
| Monitoring paused | Reia monitorizarea din Device Settings Ã®n dashboard. |
| Device connection rejected | VerificÄƒ aplicaÈ›ia È›intÄƒ; dacÄƒ dispozitivul a fost È™ters, asociazÄƒ-l din nou Ã®ntr-un director de stare nou. |
| Dispozitiv duplicat | Poate ai folosit alt utilizator sau alt --state-dir. Revino la asocierea corectÄƒ È™i opreÈ™te copia suplimentarÄƒ. |
| Offline dupÄƒ Ã®nchiderea terminalului | Pentru rularea manualÄƒ, procesul trebuie sÄƒ rÄƒmÃ¢nÄƒ activ. Pe EC2 foloseÈ™te serviciul deja creat. |
| IP-ul privat al VM-ului nu merge de pe EC2 | FoloseÈ™te tunelul; adresa privatÄƒ nu este accesibilÄƒ direct din AWS. |
