#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if ! docker info >/dev/null 2>&1; then
	echo "Docker daemon not reachable. Start Docker Desktop (or the Docker engine) and retry." >&2
	exit 1
fi

docker compose up -d

echo "Waiting for new-api health endpoint..."
for _ in $(seq 1 45); do
	if docker compose exec -T new-api wget -q -O - http://127.0.0.1:3000/api/status 2>/dev/null | grep -q '"success"' >/dev/null 2>&1; then
		echo "OK: /api/status reports success"
		docker compose exec -T new-api wget -q -O - http://127.0.0.1:3000/api/status
		echo
		exit 0
	fi
	sleep 2
done

echo "Timeout waiting for healthy status. Logs:" >&2
docker compose logs new-api --tail 80 >&2
exit 1
