#!/usr/bin/env bash
set -euo pipefail

container="${RIVA_CONTAINER:-riva-nim}"
image="${RIVA_IMAGE:-nvcr.io/nim/nvidia/parakeet-1-1b-ctc-en-us:latest}"
tags_selector="${RIVA_TAGS_SELECTOR:-name=parakeet-1-1b-ctc-en-us,mode=all}"

env_file="${RIVA_ENV_FILE:-}"
cache_dir="${RIVA_CACHE_DIR:-}"
models_dir="${RIVA_MODELS_DIR:-}"

if [[ -z "$env_file" ]]; then
  env_file="${HOME}/.config/riva/riva-nim.env"
fi
if [[ -z "$cache_dir" ]]; then
  cache_dir="${HOME}/.cache/riva-nim/cache"
fi
if [[ -z "$models_dir" ]]; then
  models_dir="${HOME}/.cache/riva-nim/models"
fi

temp_env=""
normalized_env=""
cleanup() {
  if [[ -n "$temp_env" && -f "$temp_env" ]]; then
    rm -f "$temp_env"
  fi
  if [[ -n "$normalized_env" && -f "$normalized_env" ]]; then
    rm -f "$normalized_env"
  fi
}
trap cleanup EXIT

fail() {
  echo "error: $*" >&2
  exit 1
}

ensure_dir() {
  local path="$1"
  if [[ -d "$path" ]]; then
    return
  fi

  if mkdir -p "$path" 2>/dev/null; then
    chmod 700 "$path"
    return
  fi

  if command -v sudo >/dev/null 2>&1; then
    sudo install -d -m 700 "$path"
    return
  fi

  fail "cannot create directory: $path"
}

run_env_file=""
if [[ -r "$env_file" ]]; then
  run_env_file="$env_file"
elif [[ -f "$env_file" ]]; then
  if ! command -v sudo >/dev/null 2>&1; then
    fail "$env_file exists but is not readable by $(whoami), and sudo is unavailable."
  fi

  temp_env="$(mktemp -t riva-nim-env.XXXXXX)"
  if ! sudo cat "$env_file" | tee "$temp_env" >/dev/null; then
    fail "failed to read $env_file via sudo"
  fi
  chmod 600 "$temp_env"
  run_env_file="$temp_env"
else
  fail "missing env file: $env_file"
fi

normalized_env="$(mktemp -t riva-nim-env-normalized.XXXXXX)"
if ! awk '
  BEGIN { found=0 }
  /^NGC_API_KEY=/ {
    value=substr($0,13)
    gsub(/\r/, "", value)
    if (value ~ /^".*"$/) {
      value=substr(value, 2, length(value)-2)
    }
    print "NGC_API_KEY=" value
    found=1
    next
  }
  { print }
  END { if (found == 0) exit 1 }
' "$run_env_file" > "$normalized_env"; then
  fail "env file is missing NGC_API_KEY=..."
fi
chmod 600 "$normalized_env"
run_env_file="$normalized_env"

if ! awk -F= '/^NGC_API_KEY=/{ if (length(substr($0,13)) > 0) ok=1 } END{ exit(ok?0:1) }' "$run_env_file"; then
  fail "NGC_API_KEY is present but empty after normalization"
fi

ensure_dir "$cache_dir"
ensure_dir "$models_dir"

docker rm -f "$container" >/dev/null 2>&1 || true

docker run -d \
  --name "$container" \
  --restart unless-stopped \
  --gpus all \
  --ulimit nofile=2048:2048 \
  --shm-size=8g \
  --env-file "$run_env_file" \
  -e NIM_TAGS_SELECTOR="$tags_selector" \
  -p 127.0.0.1:50051:50051 \
  -p 127.0.0.1:9000:9000 \
  -v "$cache_dir:/opt/nim/.cache" \
  -v "$models_dir:/data/models" \
  "$image"

echo "started container '$container'"
