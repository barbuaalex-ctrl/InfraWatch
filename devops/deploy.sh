#!/bin/bash
set -Ee

cd /home/adi/infrawatchapp

compose=(docker compose --env-file devops/.env -f devops/compose.yaml)
image="$IMAGE:$RELEASE_TAG"

if ! [[ "$RELEASE_TAG" =~ ^ci-[0-9]+$ ]]; then
  echo "Tag invalid. Foloseste un tag precum ci-14."
  exit 1
fi

if [ "$ACTIVE_SERVICE" = "infrawatch" ]; then
  active_container="infrawatch"
  target_container="infrawatch-green"
else
  active_container="infrawatch-green"
  target_container="infrawatch"
fi

check_container="infrawatch-check-$GITHUB_RUN_ID-$GITHUB_RUN_ATTEMPT"
cutover_started=false

mkdir -p /home/adi/infrawatch-backups
umask 077
backup=$(mktemp -d /home/adi/infrawatch-backups/deploy-XXXXXX)
mkdir "$backup/data"
cp devops/.env "$backup/env"
cp devops/nginx/active.inc "$backup/active.inc"

wait_for_app() {
  for attempt in {1..30}; do
    if docker exec "$1" python3 /app/healthcheck.py; then
      return 0
    fi
    sleep 2
  done
  return 1
}

cleanup() {
  docker rm -f "$check_container" >/dev/null 2>&1 || true
}

rollback() {
  trap - ERR INT TERM
  set +e

  cp "$backup/env" devops/.env

  if [ "$cutover_started" = true ]; then
    echo "Deploy esuat. Revin la instanta precedenta."

    if ! docker stop "$target_container"; then
      echo "Nu pot confirma oprirea noii instante. Este necesara verificare manuala."
      exit 1
    fi

    cp "$backup/active.inc" devops/nginx/active.inc

    if ! docker start "$active_container" || ! wait_for_app "$active_container"; then
      echo "Instanta precedenta nu a repornit corect. Backup: $backup"
      exit 1
    fi

    if ! docker exec infrawatch-nginx nginx -t ||
       ! docker exec infrawatch-nginx nginx -s reload; then
      echo "Verifica Nginx. Backup: $backup"
      exit 1
    fi

    echo "Instanta precedenta este din nou activa."
  fi

  exit 1
}

trap cleanup EXIT
trap rollback ERR INT TERM

echo "Verific imaginea separat, fara datele aplicatiei."

docker run -d \
  --name "$check_container" \
  --network none \
  --memory 256m \
  "$image"

wait_for_app "$check_container"
docker rm -f "$check_container"

echo "Opresc instantele pentru backup si activare."
echo "Backup: $backup"

cutover_started=true
"${compose[@]}" stop "$ACTIVE_SERVICE" "$TARGET_SERVICE"

docker cp -a \
  "$active_container:/app/backend/data/." \
  "$backup/data/"

sed -i "s/^$TAG_KEY=.*/$TAG_KEY=$RELEASE_TAG/" devops/.env

echo "Pornesc noua versiune."

"${compose[@]}" up -d --no-deps "$TARGET_SERVICE"
wait_for_app "$target_container"

mounted_volume=$(docker inspect "$target_container" \
  --format '{{range .Mounts}}{{if eq .Destination "/app/backend/data"}}{{.Name}}{{end}}{{end}}')

test "$mounted_volume" = "infrawatch-data"

echo "Schimb traficul."

printf 'proxy_pass http://%s:3000;\n' "$TARGET_SERVICE" \
  > devops/nginx/active.inc

docker exec infrawatch-nginx nginx -t
docker exec infrawatch-nginx nginx -s reload

curl --fail --silent --show-error \
  --retry 5 --retry-delay 1 \
  http://127.0.0.1:8080/health

echo
echo "Deploy terminat: $TARGET_SERVICE foloseste $RELEASE_TAG."