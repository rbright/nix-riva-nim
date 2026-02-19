#!/usr/bin/env bash
set -euo pipefail

container="${RIVA_CONTAINER:-riva-nim}"
health_url="${RIVA_HEALTH_URL:-http://127.0.0.1:9000/v1/health/ready}"
timeout_s="${RIVA_HEALTH_TIMEOUT:-120}"
interval_s="${RIVA_HEALTH_INTERVAL:-5}"

if ! [[ "$timeout_s" =~ ^[0-9]+$ ]] || ! [[ "$interval_s" =~ ^[0-9]+$ ]]; then
  echo "error: timeout and interval must be integers (seconds)." >&2
  exit 1
fi

deadline=$((SECONDS + timeout_s))
while (( SECONDS < deadline )); do
  if response="$(curl -fsS "$health_url" 2>/dev/null)"; then
    echo "$response"
    if echo "$response" | grep -qi 'ready'; then
      exit 0
    fi
  fi

  status="$(docker inspect --format '{{.State.Status}}' "$container" 2>/dev/null || true)"
  [[ -n "$status" ]] || status="missing"

  logs="$(docker logs --tail 80 "$container" 2>&1 || true)"

  if echo "$logs" | grep -Eqi 'manifestdownloaderror|download failed|permission denied|401 unauthorized|traceback|failed to start'; then
    echo "error: detected fatal startup errors in container logs." >&2
    echo "$logs" | tail -n 60 >&2
    exit 1
  fi

  phase="starting"
  if echo "$logs" | grep -Eqi 'starting riva model generation|building trt engine|quantizing model'; then
    phase="building-engine"
  elif echo "$logs" | grep -Eqi 'starting nim inference server|materializing workspace'; then
    phase="initializing"
  fi

  echo "waiting for riva readiness... (phase=$phase, container=$status, retry in ${interval_s}s)"
  sleep "$interval_s"
done

echo "error: riva did not become ready within ${timeout_s}s" >&2
docker logs --tail 80 "$container" >&2 || true
exit 1
