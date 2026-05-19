#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

die() {
	echo "error: $*" >&2
	exit 1
}

SRC="${NEW_API_SRC:-}"
if [[ -z "${SRC}" ]]; then
	die "set NEW_API_SRC to your local clone of https://github.com/QuantumNous/new-api"
fi

if [[ ! -f "${SRC}/main.go" ]]; then
	die "NEW_API_SRC (${SRC}) does not look like New API (missing main.go)"
fi

if ! command -v bun >/dev/null 2>&1; then
	die "bun not found; install from https://bun.sh then retry"
fi

if ! command -v make >/dev/null 2>&1; then
	die "make not found (upstream builds frontends via makefile)"
fi

CGO_ENABLED="${CGO_ENABLED:-0}"
export CGO_ENABLED

cd "${SRC}"

echo "==> go mod download"
go mod download

echo "==> build frontends (make build-all-frontends)"
make build-all-frontends

OUT="${ROOT}/build/new-api"
mkdir -p "$(dirname "${OUT}")"

echo "==> go build -> ${OUT}"
# Allow optional cross-compile via GOOS/GOARCH (caller assumes SQLite/CGO implications).
go build -o "${OUT}" .

echo "OK: ${OUT}"
ls -lh "${OUT}"
