# InfraWatch â€” DevOps

## Organizarea proiectului

- `app/`: aplicaÈ›ia Node.js, interfaÈ›a È™i agenÈ›ii Windows/Linux.
- `devops/Dockerfile`: imaginea aplicaÈ›iei; instaleazÄƒ È™i Python pentru health check.
- `devops/compose.yaml`: cele douÄƒ instanÈ›e posibile ale aplicaÈ›iei È™i Nginx.
- `devops/nginx/`: configuraÈ›ia proxy-ului.
- `devops/deploy.sh`: verificare, backup, activare È™i rollback.
- `.github/workflows/`: integrarea continuÄƒ È™i deploy-ul.
- `devops/terraform/`: serverul AWS EC2 monitorizat.

Dashboardul ruleazÄƒ pe VM-ul Debian. EC2 ruleazÄƒ agentul Linux È™i trimite metrici cÄƒtre dashboard printr-un tunel SSH.

## Servicii È™i date

| Rol | Serviciu Compose | Container | Port pe VM |
| --- | --- | --- | --- |
| Blue | infrawatch | infrawatch | 3001 |
| Green | green | infrawatch-green | 127.0.0.1:3002 |
| Intrare pentru utilizatori | nginx | infrawatch-nginx | 8080 |

Portul intern al aplicaÈ›iei este 3000. Nginx primeÈ™te cererile pe 8080 È™i le trimite cÄƒtre instanÈ›a activÄƒ. Green se poate testa direct pe portul 3002 numai din VM.

Ambele instanÈ›e folosesc acelaÈ™i volum extern `infrawatch-data`, montat Ã®n `/app/backend/data`. AplicaÈ›ia stocheazÄƒ datele Ã®n fiÈ™iere JSON, de aceea **nu pornim Blue È™i Green simultan pe acest volum**.

Implementarea alterneazÄƒ Ã®ntre Blue È™i Green, dar are o scurtÄƒ Ã®ntrerupere controlatÄƒ la activare. Nu oferÄƒ deploy fÄƒrÄƒ Ã®ntrerupere. InstanÈ›a nouÄƒ este verificatÄƒ Ã®ntÃ¢i Ã®ntr-un container temporar fÄƒrÄƒ datele reale, apoi instanÈ›a veche este opritÄƒ Ã®naintea pornirii celei noi.

## Prima pornire cu Docker Compose

PaÈ™ii de mai jos sunt pentru o instalare nouÄƒ pe Linux, cu Docker Engine, pluginul Compose È™i Git deja instalate. DacÄƒ aplicaÈ›ia ruleazÄƒ deja, foloseÈ™te workflow-ul de deploy; nu reiniÈ›ializa configuraÈ›ia activÄƒ.

```bash
git clone https://github.com/barbuaalex-ctrl/InfraWatch.git
cd InfraWatch
docker volume create infrawatch-data
```

CreeazÄƒ `devops/.env` cu ambele valori. Exemplul foloseÈ™te imaginea publicatÄƒ È™i testatÄƒ `ci-14`:

```dotenv
IMAGE_TAG=ci-14
GREEN_IMAGE_TAG=ci-14
```

Exemplul existent `devops/.env.example` conÈ›ine doar `IMAGE_TAG`; pentru configuraÈ›ia actualÄƒ trebuie adÄƒugat È™i `GREEN_IMAGE_TAG`.

CreeazÄƒ `devops/nginx/active.inc` cu aceastÄƒ linie, pentru prima pornire pe Blue:

```nginx
proxy_pass http://infrawatch:3000;
```

RuleazÄƒ din rÄƒdÄƒcina repository-ului:

```bash
docker compose --env-file devops/.env -f devops/compose.yaml config
docker compose --env-file devops/.env -f devops/compose.yaml pull infrawatch nginx
docker compose --env-file devops/.env -f devops/compose.yaml up -d infrawatch
docker inspect infrawatch --format '{{.State.Health.Status}}'
```

AÈ™teaptÄƒ rezultatul `healthy`. DacÄƒ apare `starting`, repetÄƒ ultima comandÄƒ dupÄƒ cÃ¢teva secunde. DacÄƒ apare `unhealthy`, verificÄƒ logurile Ã®nainte sÄƒ continui.

```bash
docker compose --env-file devops/.env -f devops/compose.yaml up -d nginx
curl -i http://localhost:8080/health
```

Rezultatul aÈ™teptat este HTTP 200 È™i `{"status":"ok"}`. Dashboardul se deschide la `http://VM_IP:8080`.

Serviciile aplicaÈ›iei au profilul `standby`: le pornim explicit dupÄƒ numele serviciului. Nu folosi `--profile standby up -d`, deoarece ar porni ambele instanÈ›e pe aceleaÈ™i date.

FiÈ™ierele `devops/.env` È™i `devops/nginx/active.inc` sunt locale È™i ignorate de Git. Primul pÄƒstreazÄƒ tagurile imaginilor, al doilea instanÈ›a activÄƒ. `default.conf` include `active.inc`; adresa internÄƒ foloseÈ™te HTTP.

## CI â€” testare È™i publicare

Workflow-ul `InfraWatch CI` ruleazÄƒ la push pe main, la pull request cÄƒtre main sau manual:

1. DescarcÄƒ sursele pe un runner GitHub Ubuntu.
2. InstaleazÄƒ Node.js 24 È™i dependenÈ›ele cu `npm ci`.
3. RuleazÄƒ `npm test` din `app/`.
4. ConstruieÈ™te imaginea Docker.
5. Pe main, se autentificÄƒ Ã®n GHCR cu tokenul automat `GITHUB_TOKEN` È™i publicÄƒ imaginea.

`ci-N` foloseÈ™te numÄƒrul rulÄƒrii workflow-ului. Este identificatorul buildului; versiunea aplicaÈ›iei È™i agentului este separatÄƒ, de exemplu `0.10.0`. Un push pe main publicÄƒ imaginea, dar nu schimbÄƒ automat aplicaÈ›ia de pe VM.

## CD â€” activare din GitHub Actions

ÃŽn GitHub: **Actions â†’ InfraWatch Deploy â†’ Run workflow**. SelecteazÄƒ main, introdu tagul unei imagini deja publicate È™i lasÄƒ simularea dezactivatÄƒ pentru un deploy normal.

DeclanÈ™area este manualÄƒ; paÈ™ii de deploy È™i rollback sunt automatizaÈ›i.

Workflow-ul are nevoie de un runner propriu Linux x64, online, cu eticheta `infrawatch-deploy`, acces la Docker È™i drept de scriere Ã®n checkout-ul aplicaÈ›iei. ÃŽn configuraÈ›ia proiectului, checkout-ul este `/home/adi/infrawatchapp`.

Workflow-ul nu face checkout sau git pull: executÄƒ scriptul È™i configuraÈ›ia existente Ã®n acel director. DupÄƒ schimbÄƒri ale scripturilor, actualizeazÄƒ checkout-ul local Ã®naintea deploy-ului. Calea este scrisÄƒ atÃ¢t Ã®n workflow, cÃ¢t È™i Ã®n script; pentru alt server trebuie adaptatÄƒ Ã®n ambele locuri.

### Variabilele folosite

| VariabilÄƒ | De ce existÄƒ |
| --- | --- |
| IMAGE | Adresa imaginii Ã®n registry, fÄƒrÄƒ tag. |
| RELEASE_TAG | Buildul ales pentru deploy, de exemplu ci-14. |
| ACTIVE_SERVICE | InstanÈ›a care primeÈ™te traficul acum, cititÄƒ din active.inc. |
| TARGET_SERVICE | CealaltÄƒ instanÈ›Äƒ, pe care activÄƒm versiunea aleasÄƒ. |
| TAG_KEY | Linia din .env care trebuie actualizatÄƒ: IMAGE_TAG sau GREEN_IMAGE_TAG. |
| SIMULATE_FAILURE | ActiveazÄƒ eroarea intenÈ›ionatÄƒ pentru demonstrarea rollback-ului. |
| GITHUB_ENV | FiÈ™ier oferit de GitHub Actions; valorile scrise aici devin variabile de mediu Ã®n paÈ™ii urmÄƒtori ai aceluiaÈ™i job. |

Fiecare pas ruleazÄƒ separat. De aceea variabilele stabilite la alegerea È›intei sunt transmise prin `GITHUB_ENV`. Scriptul primeÈ™te astfel aceleaÈ™i decizii fÄƒrÄƒ sÄƒ identifice din nou instanÈ›a activÄƒ.

`concurrency` permite un singur deploy din acest workflow la un moment dat. `cancel-in-progress: false` evitÄƒ Ã®ntreruperea unui deploy Ã®n curs de cÄƒtre o nouÄƒ cerere. Nu protejeazÄƒ Ã®mpotriva comenzilor Docker executate manual Ã®n paralel.

### Ce face deploy.sh

1. VerificÄƒ formatul tagului È™i salveazÄƒ configuraÈ›ia localÄƒ Ã®ntr-un director de backup.
2. PorneÈ™te imaginea Ã®ntr-un container temporar fÄƒrÄƒ reÈ›ea, fÄƒrÄƒ volumul real È™i cu limita de memorie de 256 MB. VerificÄƒ aplicaÈ›ia din interiorul containerului.
3. OpreÈ™te cele douÄƒ servicii pentru a evita scrierile simultane.
4. CopiazÄƒ datele instanÈ›ei active Ã®n backup, sub `/home/adi/infrawatch-backups/`.
5. ActualizeazÄƒ tagul È›intei Ã®n .env, porneÈ™te È›inta È™i verificÄƒ health check-ul.
6. ConfirmÄƒ cÄƒ È›inta foloseÈ™te volumul `infrawatch-data`.
7. Scrie noua destinaÈ›ie Ã®n active.inc, verificÄƒ Nginx, reÃ®ncarcÄƒ configuraÈ›ia È™i verificÄƒ accesul prin 8080.

InstanÈ›a precedentÄƒ rÄƒmÃ¢ne opritÄƒ. Nu este necesar sÄƒ modifici manual Blue/Green la fiecare deploy.

### Rollback È™i limite

DacÄƒ apare o eroare Ã®n partea de activare, scriptul opreÈ™te È›inta, restabileÈ™te configuraÈ›ia salvatÄƒ, reporneÈ™te instanÈ›a precedentÄƒ È™i reÃ®ncarcÄƒ Nginx. DacÄƒ nu poate confirma oprirea È›intei sau repornirea instanÈ›ei precedente, raporteazÄƒ necesitatea unei verificÄƒri manuale.

OpÈ›iunea `test_rollback` provoacÄƒ o eroare dupÄƒ pornirea È™i verificarea È›intei, Ã®nainte de schimbarea traficului. Rularea apare ca eÈ™uatÄƒ chiar dacÄƒ revenirea reuÈ™eÈ™te: versiunea solicitatÄƒ nu a fost activatÄƒ. Verificarea finalÄƒ este HTTP 200 pe 8080.

Datele rÄƒmÃ¢n Ã®n volumul comun. Rollback-ul nu restaureazÄƒ automat fiÈ™ierele din backup È™i presupune compatibilitatea versiunii vechi cu datele existente. Nu existÄƒ monitorizare automatÄƒ de zece minute dupÄƒ deploy sau restaurare garantatÄƒ pentru orice schimbare de format a datelor.

Health check-ul Docker marcheazÄƒ starea aplicaÈ›iei. `restart: unless-stopped` nu reporneÈ™te un container doar pentru cÄƒ a devenit `unhealthy`.

## Terraform È™i demonstraÈ›ia

Terraform creeazÄƒ un EC2 Amazon Linux, o pereche de chei publice È™i un Security Group Ã®n VPC-ul implicit existent. User data instaleazÄƒ agentul È™i Ã®l porneÈ™te ca serviciu systemd. Conectarea dispozitivului Ã®n aplicaÈ›ie necesitÄƒ tunelul SSH È™i aprobarea codului temporar.

Comenzile, verificÄƒrile de dinaintea prezentÄƒrii È™i oprirea resurselor sunt Ã®n [ghidul demonstraÈ›iei](DEMO.md).
