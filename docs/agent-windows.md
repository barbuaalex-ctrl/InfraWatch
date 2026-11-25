# Tutorial — agentul Windows

Agentul rulează pe calculatorul pe care vrei să îl monitorizezi. Dashboardul InfraWatch poate rula pe alt calculator sau pe VM. Asocierea se face printr-un cod temporar; nu trebuie să copiezi manual un token sau un server ID.

## 1. Alege adresa corectă

| Unde rulează agentul Windows | Adresa InfraWatch |
| --- | --- |
| Pe un PC din aceeași rețea cu VM-ul Debian | http://VM_IP:8080 |
| Pe același Windows pe care rulează aplicația cu npm start | http://127.0.0.1:3000 |
| Pe alt PC, când aplicația rulează cu npm start | http://IP_CALCULATOR_APLICATIE:3000 |

Înlocuiește numele din exemple cu IP-ul real. În configurația proiectului, intrarea prin Docker/Nginx este portul **8080**.

Pe Debian, poți afla adresele VM-ului cu `hostname -I`. Alege adresa din rețeaua locală accesibilă de pe PC-ul Windows. Nu folosi adresa internă a unui container.

Înainte de a porni agentul, deschide adresa InfraWatch în browserul calculatorului Windows. Dacă dashboardul nu se deschide, rezolvă întâi conectivitatea.

`localhost` și `127.0.0.1` înseamnă calculatorul pe care rulează agentul. Pe laptop nu indică automat VM-ul sau alt PC.

## 2. Descarcă și extrage

1. Deschide dashboardul și autentifică-te ca administrator.
2. Intră în **Download agent**.
3. Descarcă arhiva pentru **Windows**, cu numele și versiunea afișate.
4. Trimite arhiva pe calculatorul de monitorizat, dacă ai descărcat-o pe alt dispozitiv.
5. Extrage toate fișierele într-un folder în care utilizatorul Windows poate scrie, de exemplu Documents.
6. Deschide folderul **InfraWatch-Agent** din arhivă.

Nu porni agentul direct din ZIP. Păstrează împreună fișierele extrase, inclusiv scripturile și version.json.

## 3. Pornește și aprobă dispozitivul

1. Dublu-click pe **Start Agent.cmd**.
2. În fereastra agentului, verifică **InfraWatch address**. Adresa este de obicei inclusă în descărcare; corecteaz-o dacă nu poate fi accesată de pe acest PC.
3. Apasă **Start**.
4. Agentul afișează un cod de forma `ABC-234`.
5. Apasă **Copy code** sau selectează codul și copiază-l cu Ctrl+C.
6. În dashboard, deschide **Devices → Add device → Computer / Server**.
7. Introdu codul sau folosește **Paste code**. Poți folosi și Ctrl+V în câmp; cratima se adaugă automat la introducerea manuală.
8. Numele de afișare este opțional; fără el se folosește numele detectat al dispozitivului.
9. Apasă **Connect device**.

Codul este valabil cinci minute și poate fi aprobat o singură dată. Nu trebuie să introduci parola de administrator în agent: aprobarea se face în dashboard.

După aprobare, agentul afișează **CONNECTED**. În dashboard apar dispozitivul și primele metrici.

## 4. Ce poți vedea

În **Overview** vezi dispozitivele asociate. Din **Devices → Device details** poți consulta graficele și informațiile detectate despre calculator.

- CPU și RAM: utilizarea curentă.
- GPU: utilizarea motoarelor 3D, dacă Windows și driverul oferă contoarele necesare.
- Disk: procentul de spațiu ocupat pe discul de sistem și GB liberi din total.
- Uptime: timpul de la pornirea sistemului.
- Componente: hostname, Windows, procesor, memorie, plăci video și discuri.

**Disk 98% în InfraWatch înseamnă capacitate ocupată, nu activitate de scriere/citire de 98% în Task Manager.**

Metricile urmăresc un interval de o secundă; rețeaua și citirea contoarelor pot întârzia actualizările. Informațiile despre componente se recitesc aproximativ o dată pe oră.

În Device Settings poți ajusta pragurile și întrerupe monitorizarea din aplicație. Administratorii primesc notificările pentru alerte atunci când sunt conectați în dashboard.

## 5. Oprire și reconectare

- **Stop** oprește trimiterea metricilor.
- Închiderea ferestrei oprește agentul.
- Pentru reluare, deschide același folder, pornește Start Agent.cmd și apasă Start.
- Nu mai este necesar un cod nou dacă asocierea salvată este încă validă.

Conexiunea este păstrată în connection.json, cu protecția oferită de contul Windows. Păstrează folderul pe dispozitivul și sub utilizatorul care au făcut asocierea. Nu distribui fișierele de conexiune.

Această variantă nu instalează un serviciu Windows și nu adaugă automat agentul la pornirea calculatorului. Fereastra trebuie să rămână deschisă în timpul monitorizării.

După aproximativ 30–35 de secunde fără metrici, InfraWatch marchează dispozitivul offline.

## 6. Actualizare

Agentul Windows verifică disponibilitatea unei versiuni noi la conectare și apoi aproximativ la fiecare 30 de minute.

1. Dacă butonul afișează o versiune nouă, apasă **Update**.
2. Confirmă instalarea.
3. Agentul înlocuiește fișierele necesare și păstrează conexiunea. Dacă monitorizarea era pornită, încearcă să o reia.

Instalarea necesită un click și confirmare; verificarea automată nu înseamnă instalare automată.

Pentru o versiune veche fără updater, oprește agentul și copiază fișierele programului din noua arhivă în folderul existent. Păstrează **config.json** și **connection.json**. Nu folosi fișierele de conexiune ale altui dispozitiv.

## 7. Probleme frecvente

| Problemă | Ce verifici |
| --- | --- |
| Nu apare niciun cod | Adresa din agent trebuie să deschidă dashboardul în browser pe același PC. Verifică și că aplicația rulează. |
| Cod expirat | Apasă Stop, apoi Start și aprobă noul cod în maximum cinci minute. |
| PAIR AGAIN | Dispozitivul poate fi șters din aplicație. Apasă Start și aprobă un cod nou. |
| PAUSED | Reia monitorizarea din Device Settings în dashboard. |
| Nu se păstrează asocierea | Extrage agentul într-un folder în care utilizatorul are drept de scriere. |
| GPU indisponibil | Driverul poate să nu ofere contoare compatibile; aceasta nu împiedică monitorizarea CPU/RAM. |
| Agentul nu se deschide | Verifică extragerea completă a arhivei și fișierele Start Agent.cmd, Agent.ps1, Pairing-Agent.ps1 și version.json. Dacă politica sistemului blochează scripturile, păstrează mesajul exact pentru diagnostic. |
| Alt PC nu ajunge la VM | Verifică IP-ul VM-ului, configurația de rețea și regulile firewall pentru portul folosit. |

Tutorialul descrie asocierea prin cod din versiunea actuală. Un README vechi dintr-o arhivă poate menționa introducerea manuală a tokenului sau un interval de cinci secunde; aceștia nu sunt pașii fluxului actual.
