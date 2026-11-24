# InfraWatch — DevOps

## Fluxul proiectului

1. Codul este trimis pe GitHub.
2. GitHub Actions instalează dependențele și rulează testele.
3. Dacă testele trec, construiește imaginea Docker.
4. Imaginea este publicată în GHCR cu tagul ci-N.
5. Pe server alegem versiunea și o pornim prin Docker Compose.

Publicarea unei imagini nu actualizează automat serverul.

## Configurația actuală

- Blue: serviciul infrawatch, port 3001.
- Green: serviciul green, port 3002, accesibil doar din VM.
- Nginx: port 8080, adresa folosită de utilizatori.
- Fiecare instanță are propriul volum de date.
- Versiunile sunt configurate în devops/.env.
- Destinația traficului este configurată în devops/nginx/default.conf.

## Verificarea aplicației

Din rădăcina proiectului:

```bash
docker compose --env-file devops/.env -f devops/compose.yaml ps
curl -i http://localhost:8080/health
```

Rezultatul așteptat: instanța activă este healthy și /health răspunde cu 200.

## Schimbarea traficului

În devops/nginx/default.conf alegem destinația:

Blue:
proxy_pass http://infrawatch:3000;

Green:
proxy_pass http://green:3000;

Verificăm configurația:

```bash
docker exec infrawatch-nginx nginx -t
```

Doar dacă verificarea reușește, aplicăm:

```bash
docker exec infrawatch-nginx nginx -s reload
```

Instanța aleasă trebuie să fie pornită și healthy.

## Date și rollback

Aplicația salvează date în fișiere JSON.

Pentru transfer:
1. Oprim ambele instanțe.
2. Facem backup datelor active.
3. Sincronizăm datele către instanța aleasă.
4. Pornim și verificăm noua instanță.
5. Schimbăm traficul prin Nginx.

Transferul necesită o scurtă întrerupere.

La rollback, sincronizăm mai întâi datele actualizate.
Simpla schimbare Nginx către un volum vechi poate expune date neactualizate.
Revenirea la o imagine veche presupune și compatibilitatea ei cu datele noi.