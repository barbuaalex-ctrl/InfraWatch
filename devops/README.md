# InfraWatch — DevOps

## Organizarea proiectului

- `app/`: aplicația Node.js, interfața și agenții Windows/Linux.
- `devops/Dockerfile`: imaginea aplicației; instalează și Python pentru health check.
- `devops/compose.yaml`: cele două instanțe posibile ale aplicației și Nginx.
- `devops/nginx/`: configurația proxy-ului.
- `devops/deploy.sh`: verificare, backup, activare și rollback.
- `.github/workflows/`: integrarea continuă și deploy-ul.
- `devops/terraform/`: serverul AWS EC2 monitorizat.

Dashboardul rulează pe VM-ul Debian. EC2 rulează agentul Linux și trimite metrici către dashboard printr-un tunel SSH.

## Servicii și date

| Rol | Serviciu Compose | Container | Port pe VM |
| --- | --- | --- | --- |
| Blue | infrawatch | infrawatch | 3001 |
| Green | green | infrawatch-green | 127.0.0.1:3002 |
| Intrare pentru utilizatori | nginx | infrawatch-nginx | 8080 |

Portul intern al aplicației este 3000. Nginx primește cererile pe 8080 și le trimite către instanța activă. Green se poate testa direct pe portul 3002 numai din VM.

Ambele instanțe folosesc același volum extern `infrawatch-data`, montat în `/app/backend/data`. Aplicația stochează datele în fișiere JSON, de aceea **nu pornim Blue și Green simultan pe acest volum**.

Implementarea alternează între Blue și Green, dar are o scurtă întrerupere controlată la activare. Nu oferă deploy fără întrerupere. Instanța nouă este verificată întâi într-un container temporar fără datele reale, apoi instanța veche este oprită înaintea pornirii celei noi.

## Prima pornire cu Docker Compose

Pașii de mai jos sunt pentru o instalare nouă pe Linux, cu Docker Engine, pluginul Compose și Git deja instalate. Dacă aplicația rulează deja, folosește workflow-ul de deploy; nu reinițializa configurația activă.

```bash
git clone https://github.com/barbuaalex-ctrl/InfraWatch.git
cd InfraWatch
docker volume create infrawatch-data
```

Creează `devops/.env` cu ambele valori. Exemplul folosește imaginea publicată și testată `ci-14`:

```dotenv
IMAGE_TAG=ci-14
GREEN_IMAGE_TAG=ci-14
```

Exemplul existent `devops/.env.example` conține doar `IMAGE_TAG`; pentru configurația actuală trebuie adăugat și `GREEN_IMAGE_TAG`.

Creează `devops/nginx/active.inc` cu această linie, pentru prima pornire pe Blue:

```nginx
proxy_pass http://infrawatch:3000;
```

Rulează din rădăcina repository-ului:

```bash
docker compose --env-file devops/.env -f devops/compose.yaml config
docker compose --env-file devops/.env -f devops/compose.yaml pull infrawatch nginx
docker compose --env-file devops/.env -f devops/compose.yaml up -d infrawatch
docker inspect infrawatch --format '{{.State.Health.Status}}'
```

Așteaptă rezultatul `healthy`. Dacă apare `starting`, repetă ultima comandă după câteva secunde. Dacă apare `unhealthy`, verifică logurile înainte să continui.

```bash
docker compose --env-file devops/.env -f devops/compose.yaml up -d nginx
curl -i http://localhost:8080/health
```

Rezultatul așteptat este HTTP 200 și `{"status":"ok"}`. Dashboardul se deschide la `http://VM_IP:8080`.

Serviciile aplicației au profilul `standby`: le pornim explicit după numele serviciului. Nu folosi `--profile standby up -d`, deoarece ar porni ambele instanțe pe aceleași date.

Fișierele `devops/.env` și `devops/nginx/active.inc` sunt locale și ignorate de Git. Primul păstrează tagurile imaginilor, al doilea instanța activă. `default.conf` include `active.inc`; adresa internă folosește HTTP.

## CI — testare și publicare

Workflow-ul `InfraWatch CI` rulează la push pe main, la pull request către main sau manual:

1. Descarcă sursele pe un runner GitHub Ubuntu.
2. Instalează Node.js 24 și dependențele cu `npm ci`.
3. Rulează `npm test` din `app/`.
4. Construiește imaginea Docker.
5. Pe main, se autentifică în GHCR cu tokenul automat `GITHUB_TOKEN` și publică imaginea.

`ci-N` folosește numărul rulării workflow-ului. Este identificatorul buildului; versiunea aplicației și agentului este separată, de exemplu `0.10.0`. Un push pe main publică imaginea, dar nu schimbă automat aplicația de pe VM.

## CD — activare din GitHub Actions

În GitHub: **Actions → InfraWatch Deploy → Run workflow**. Selectează main, introdu tagul unei imagini deja publicate și lasă simularea dezactivată pentru un deploy normal.

Declanșarea este manuală; pașii de deploy și rollback sunt automatizați.

Workflow-ul are nevoie de un runner propriu Linux x64, online, cu eticheta `infrawatch-deploy`, acces la Docker și drept de scriere în checkout-ul aplicației. În configurația proiectului, checkout-ul este `/home/adi/infrawatchapp`.

Workflow-ul nu face checkout sau git pull: execută scriptul și configurația existente în acel director. După schimbări ale scripturilor, actualizează checkout-ul local înaintea deploy-ului. Calea este scrisă atât în workflow, cât și în script; pentru alt server trebuie adaptată în ambele locuri.

### Variabilele folosite

| Variabilă | De ce există |
| --- | --- |
| IMAGE | Adresa imaginii în registry, fără tag. |
| RELEASE_TAG | Buildul ales pentru deploy, de exemplu ci-14. |
| ACTIVE_SERVICE | Instanța care primește traficul acum, citită din active.inc. |
| TARGET_SERVICE | Cealaltă instanță, pe care activăm versiunea aleasă. |
| TAG_KEY | Linia din .env care trebuie actualizată: IMAGE_TAG sau GREEN_IMAGE_TAG. |
| SIMULATE_FAILURE | Activează eroarea intenționată pentru demonstrarea rollback-ului. |
| GITHUB_ENV | Fișier oferit de GitHub Actions; valorile scrise aici devin variabile de mediu în pașii următori ai aceluiași job. |

Fiecare pas rulează separat. De aceea variabilele stabilite la alegerea țintei sunt transmise prin `GITHUB_ENV`. Scriptul primește astfel aceleași decizii fără să identifice din nou instanța activă.

`concurrency` permite un singur deploy din acest workflow la un moment dat. `cancel-in-progress: false` evită întreruperea unui deploy în curs de către o nouă cerere. Nu protejează împotriva comenzilor Docker executate manual în paralel.

### Ce face deploy.sh

1. Verifică formatul tagului și salvează configurația locală într-un director de backup.
2. Pornește imaginea într-un container temporar fără rețea, fără volumul real și cu limita de memorie de 256 MB. Verifică aplicația din interiorul containerului.
3. Oprește cele două servicii pentru a evita scrierile simultane.
4. Copiază datele instanței active în backup, sub `/home/adi/infrawatch-backups/`.
5. Actualizează tagul țintei în .env, pornește ținta și verifică health check-ul.
6. Confirmă că ținta folosește volumul `infrawatch-data`.
7. Scrie noua destinație în active.inc, verifică Nginx, reîncarcă configurația și verifică accesul prin 8080.

Instanța precedentă rămâne oprită. Nu este necesar să modifici manual Blue/Green la fiecare deploy.

### Rollback și limite

Dacă apare o eroare în partea de activare, scriptul oprește ținta, restabilește configurația salvată, repornește instanța precedentă și reîncarcă Nginx. Dacă nu poate confirma oprirea țintei sau repornirea instanței precedente, raportează necesitatea unei verificări manuale.

Opțiunea `test_rollback` provoacă o eroare după pornirea și verificarea țintei, înainte de schimbarea traficului. Rularea apare ca eșuată chiar dacă revenirea reușește: versiunea solicitată nu a fost activată. Verificarea finală este HTTP 200 pe 8080.

Datele rămân în volumul comun. Rollback-ul nu restaurează automat fișierele din backup și presupune compatibilitatea versiunii vechi cu datele existente. Nu există monitorizare automată de zece minute după deploy sau restaurare garantată pentru orice schimbare de format a datelor.

Health check-ul Docker marchează starea aplicației. `restart: unless-stopped` nu repornește un container doar pentru că a devenit `unhealthy`.

## Terraform și demonstrația

Terraform creează un EC2 Amazon Linux, o pereche de chei publice și un Security Group în VPC-ul implicit existent. User data instalează agentul și îl pornește ca serviciu systemd. Conectarea dispozitivului în aplicație necesită tunelul SSH și aprobarea codului temporar.

Comenzile, verificările de dinaintea prezentării și oprirea resurselor sunt în [ghidul demonstrației](DEMO.md).
