# Wait for ready endpoint (first boot/model build can take several minutes).
health timeout='120' interval='5':
  RIVA_CONTAINER="{{container}}" \
  RIVA_HEALTH_URL="{{health_url}}" \
  RIVA_HEALTH_TIMEOUT="{{timeout}}" \
  RIVA_HEALTH_INTERVAL="{{interval}}" \
  ./scripts/health.sh
