# Tail container logs.
logs:
  docker logs -f "{{container}}"

# Tail container logs with timestamps + metadata.
logs-verbose since='30m' tail='500':
  docker logs -f --timestamps --details --since "{{since}}" --tail "{{tail}}" "{{container}}"

# Tail systemd service logs (includes restart-loop context and pre-start errors).
logs-service lines='200':
  journalctl -u "docker-{{container}}.service" -f -n "{{lines}}" --no-pager -o short-iso

# Focused startup/error stream for high-signal diagnostics.
logs-focus since='30m':
  docker logs -f --timestamps --since "{{since}}" "{{container}}" 2>&1 | \
    stdbuf -oL -eL grep -Ei 'error|exception|traceback|permission denied|unauthorized|download failed|building trt engine|quantizing model|starting riva model generation|starting nim inference server|materializing workspace|ready|health'

# One-shot progress snapshot: container state, process CPU, GPU usage, disk growth, and recent logs.
progress tail='50':
  RIVA_CONTAINER="{{container}}" \
  RIVA_PROGRESS_TAIL="{{tail}}" \
  ./scripts/progress.sh
