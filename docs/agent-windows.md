# Tutorial â€” agentul Windows

Agentul ruleazÄƒ pe calculatorul pe care vrei sÄƒ Ã®l monitorizezi. Dashboardul InfraWatch poate rula pe alt calculator sau pe VM. Asocierea se face printr-un cod temporar; nu trebuie sÄƒ copiezi manual un token sau un server ID.

## 1. Alege adresa corectÄƒ

| Unde ruleazÄƒ agentul Windows | Adresa InfraWatch |
| --- | --- |
| Pe un PC din aceeaÈ™i reÈ›ea cu VM-ul Debian | http://VM_IP:8080 |
| Pe acelaÈ™i Windows pe care ruleazÄƒ aplicaÈ›ia cu npm start | http://127.0.0.1:3000 |
| Pe alt PC, cÃ¢nd aplicaÈ›ia ruleazÄƒ cu npm start | http://IP_CALCULATOR_APLICATIE:3000 |

ÃŽnlocuieÈ™te numele din exemple cu IP-ul real. ÃŽn configuraÈ›ia proiectului, intrarea prin Docker/Nginx este portul **8080**.

Pe Debian, poÈ›i afla adresele VM-ului cu `hostname -I`. Alege adresa din reÈ›eaua localÄƒ accesibilÄƒ de pe PC-ul Windows. Nu folosi adresa internÄƒ a unui container.

ÃŽnainte de a porni agentul, deschide adresa InfraWatch Ã®n browserul calculatorului Windows. DacÄƒ dashboardul nu se deschide, rezolvÄƒ Ã®ntÃ¢i conectivitatea.

`localhost` È™i `127.0.0.1` Ã®nseamnÄƒ calculatorul pe care ruleazÄƒ agentul. Pe laptop nu indicÄƒ automat VM-ul sau alt PC.

## 2. DescarcÄƒ È™i extrage

1. Deschide dashboardul È™i autentificÄƒ-te ca administrator.
2. IntrÄƒ Ã®n **Download agent**.
3. DescarcÄƒ arhiva pentru **Windows**, cu numele È™i versiunea afiÈ™ate.
4. Trimite arhiva pe calculatorul de monitorizat, dacÄƒ ai descÄƒrcat-o pe alt dispozitiv.
5. Extrage toate fiÈ™ierele Ã®ntr-un folder Ã®n care utilizatorul Windows poate scrie, de exemplu Documents.
6. Deschide folderul **InfraWatch-Agent** din arhivÄƒ.

Nu porni agentul direct din ZIP. PÄƒstreazÄƒ Ã®mpreunÄƒ fiÈ™ierele extrase, inclusiv scripturile È™i version.json.

## 3. PorneÈ™te È™i aprobÄƒ dispozitivul

1. Dublu-click pe **Start Agent.cmd**.
2. ÃŽn fereastra agentului, verificÄƒ **InfraWatch address**. Adresa este de obicei inclusÄƒ Ã®n descÄƒrcare; corecteaz-o dacÄƒ nu poate fi accesatÄƒ de pe acest PC.
3. ApasÄƒ **Start**.
4. Agentul afiÈ™eazÄƒ un cod de forma `ABC-234`.
5. ApasÄƒ **Copy code** sau selecteazÄƒ codul È™i copiazÄƒ-l cu Ctrl+C.
6. ÃŽn dashboard, deschide **Devices â†’ Add device â†’ Computer / Server**.
7. Introdu codul sau foloseÈ™te **Paste code**. PoÈ›i folosi È™i Ctrl+V Ã®n cÃ¢mp; cratima se adaugÄƒ automat la introducerea manualÄƒ.
8. Numele de afiÈ™are este opÈ›ional; fÄƒrÄƒ el se foloseÈ™te numele detectat al dispozitivului.
9. ApasÄƒ **Connect device**.

Codul este valabil cinci minute È™i poate fi aprobat o singurÄƒ datÄƒ. Nu trebuie sÄƒ introduci parola de administrator Ã®n agent: aprobarea se face Ã®n dashboard.

DupÄƒ aprobare, agentul afiÈ™eazÄƒ **CONNECTED**. ÃŽn dashboard apar dispozitivul È™i primele metrici.

## 4. Ce poÈ›i vedea

ÃŽn **Overview** vezi dispozitivele asociate. Din **Devices â†’ Device details** poÈ›i consulta graficele È™i informaÈ›iile detectate despre calculator.

- CPU È™i RAM: utilizarea curentÄƒ.
- GPU: utilizarea motoarelor 3D, dacÄƒ Windows È™i driverul oferÄƒ contoarele necesare.
- Disk: procentul de spaÈ›iu ocupat pe discul de sistem È™i GB liberi din total.
- Uptime: timpul de la pornirea sistemului.
- Componente: hostname, Windows, procesor, memorie, plÄƒci video È™i discuri.

**Disk 98% Ã®n InfraWatch Ã®nseamnÄƒ capacitate ocupatÄƒ, nu activitate de scriere/citire de 98% Ã®n Task Manager.**

Metricile urmÄƒresc un interval de o secundÄƒ; reÈ›eaua È™i citirea contoarelor pot Ã®ntÃ¢rzia actualizÄƒrile. InformaÈ›iile despre componente se recitesc aproximativ o datÄƒ pe orÄƒ.

ÃŽn Device Settings poÈ›i ajusta pragurile È™i Ã®ntrerupe monitorizarea din aplicaÈ›ie. Administratorii primesc notificÄƒrile pentru alerte atunci cÃ¢nd sunt conectaÈ›i Ã®n dashboard.

## 5. Oprire È™i reconectare

- **Stop** opreÈ™te trimiterea metricilor.
- ÃŽnchiderea ferestrei opreÈ™te agentul.
- Pentru reluare, deschide acelaÈ™i folder, porneÈ™te Start Agent.cmd È™i apasÄƒ Start.
- Nu mai este necesar un cod nou dacÄƒ asocierea salvatÄƒ este Ã®ncÄƒ validÄƒ.

Conexiunea este pÄƒstratÄƒ Ã®n connection.json, cu protecÈ›ia oferitÄƒ de contul Windows. PÄƒstreazÄƒ folderul pe dispozitivul È™i sub utilizatorul care au fÄƒcut asocierea. Nu distribui fiÈ™ierele de conexiune.

AceastÄƒ variantÄƒ nu instaleazÄƒ un serviciu Windows È™i nu adaugÄƒ automat agentul la pornirea calculatorului. Fereastra trebuie sÄƒ rÄƒmÃ¢nÄƒ deschisÄƒ Ã®n timpul monitorizÄƒrii.

DupÄƒ aproximativ 30â€“35 de secunde fÄƒrÄƒ metrici, InfraWatch marcheazÄƒ dispozitivul offline.

## 6. Actualizare

Agentul Windows verificÄƒ disponibilitatea unei versiuni noi la conectare È™i apoi aproximativ la fiecare 30 de minute.

1. DacÄƒ butonul afiÈ™eazÄƒ o versiune nouÄƒ, apasÄƒ **Update**.
2. ConfirmÄƒ instalarea.
3. Agentul Ã®nlocuieÈ™te fiÈ™ierele necesare È™i pÄƒstreazÄƒ conexiunea. DacÄƒ monitorizarea era pornitÄƒ, Ã®ncearcÄƒ sÄƒ o reia.

Instalarea necesitÄƒ un click È™i confirmare; verificarea automatÄƒ nu Ã®nseamnÄƒ instalare automatÄƒ.

Pentru o versiune veche fÄƒrÄƒ updater, opreÈ™te agentul È™i copiazÄƒ fiÈ™ierele programului din noua arhivÄƒ Ã®n folderul existent. PÄƒstreazÄƒ **config.json** È™i **connection.json**. Nu folosi fiÈ™ierele de conexiune ale altui dispozitiv.

## 7. Probleme frecvente

| ProblemÄƒ | Ce verifici |
| --- | --- |
| Nu apare niciun cod | Adresa din agent trebuie sÄƒ deschidÄƒ dashboardul Ã®n browser pe acelaÈ™i PC. VerificÄƒ È™i cÄƒ aplicaÈ›ia ruleazÄƒ. |
| Cod expirat | ApasÄƒ Stop, apoi Start È™i aprobÄƒ noul cod Ã®n maximum cinci minute. |
| PAIR AGAIN | Dispozitivul poate fi È™ters din aplicaÈ›ie. ApasÄƒ Start È™i aprobÄƒ un cod nou. |
| PAUSED | Reia monitorizarea din Device Settings Ã®n dashboard. |
| Nu se pÄƒstreazÄƒ asocierea | Extrage agentul Ã®ntr-un folder Ã®n care utilizatorul are drept de scriere. |
| GPU indisponibil | Driverul poate sÄƒ nu ofere contoare compatibile; aceasta nu Ã®mpiedicÄƒ monitorizarea CPU/RAM. |
| Agentul nu se deschide | VerificÄƒ extragerea completÄƒ a arhivei È™i fiÈ™ierele Start Agent.cmd, Agent.ps1, Pairing-Agent.ps1 È™i version.json. DacÄƒ politica sistemului blocheazÄƒ scripturile, pÄƒstreazÄƒ mesajul exact pentru diagnostic. |
| Alt PC nu ajunge la VM | VerificÄƒ IP-ul VM-ului, configuraÈ›ia de reÈ›ea È™i regulile firewall pentru portul folosit. |

Tutorialul descrie asocierea prin cod din versiunea actualÄƒ. Un README vechi dintr-o arhivÄƒ poate menÈ›iona introducerea manualÄƒ a tokenului sau un interval de cinci secunde; aceÈ™tia nu sunt paÈ™ii fluxului actual.
