#!/usr/bin/env bash
set -euo pipefail

container="${RIVA_CONTAINER:-riva-nim}"
tail_n="${RIVA_PROGRESS_TAIL:-50}"

echo "== container state =="
docker inspect "$container" 2>/dev/null | jq -r '.[0] | "status=\(.State.Status) restartCount=\(.RestartCount) startedAt=\(.State.StartedAt)"' || echo "container not found"

echo
echo "== docker top =="
docker top "$container" -eo pid,ppid,user,pcpu,pmem,etime,args 2>/dev/null | sed -n '1,20p' || true

echo
echo "== gpu snapshot =="
nvidia-smi --query-gpu=utilization.gpu,utilization.memory,memory.used,memory.total --format=csv,noheader || true
nvidia-smi --query-compute-apps=pid,process_name,used_gpu_memory --format=csv,noheader | head -n 10 || true

echo
echo "== cache/model disk usage =="
du -sh /var/lib/riva-nim/cache /var/lib/riva-nim/models 2>/dev/null || true
du -sh "$HOME/.cache/riva-nim/cache" "$HOME/.cache/riva-nim/models" 2>/dev/null || true

echo
echo "== recent logs =="
docker logs --tail "$tail_n" "$container" 2>&1 || true
