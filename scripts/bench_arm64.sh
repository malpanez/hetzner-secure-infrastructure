#!/usr/bin/env bash
set -euo pipefail

TARGET_URL="${1:-http://127.0.0.1/}"
REQUESTS="${2:-100000}"
CONCURRENCY="${3:-100}"

timestamp="$(date +%Y%m%d-%H%M%S)"
output_file="bench-arm64-${timestamp}.txt"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

require_cmd ab
require_cmd uname
require_cmd free
require_cmd df

{
  echo "=== ARM64 Benchmark Run ==="
  echo "Date: $(date -u +"%Y-%m-%d %H:%M:%S UTC")"
  echo "Target: ${TARGET_URL}"
  echo "Requests: ${REQUESTS}"
  echo "Concurrency: ${CONCURRENCY}"
  echo

  echo "=== System ==="
  uname -a
  echo
  if command -v lscpu >/dev/null 2>&1; then
    echo "--- lscpu ---"
    lscpu
    echo
  fi
  echo "--- uptime ---"
  uptime
  echo
  echo "--- free -h ---"
  free -h
  echo
  echo "--- df -h ---"
  df -h
  echo

  echo "=== Software ==="
  if command -v nginx >/dev/null 2>&1; then
    echo "--- nginx -v ---"
    nginx -v 2>&1
    echo
  fi
  if command -v php >/dev/null 2>&1; then
    echo "--- php -v ---"
    php -v | head -n 2
    echo
  fi
  if command -v mariadb >/dev/null 2>&1; then
    echo "--- mariadb --version ---"
    mariadb --version
    echo
  fi
  if command -v mysqld >/dev/null 2>&1; then
    echo "--- mysqld --version ---"
    mysqld --version
    echo
  fi

  echo "=== Benchmark (ab) ==="
  ab -n "${REQUESTS}" -c "${CONCURRENCY}" "${TARGET_URL}"
} | tee "${output_file}"

echo
echo "Saved output to: ${output_file}"
