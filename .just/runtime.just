# Verify NVIDIA GPU visibility from Docker.
gpu-smoke:
  docker run --rm --gpus all nvidia/cuda:12.4.1-base-ubuntu22.04 nvidia-smi

# Start the local Riva NIM container.
up:
  RIVA_CONTAINER="{{container}}" \
  RIVA_IMAGE="{{image}}" \
  RIVA_ENV_FILE="{{env_file}}" \
  RIVA_CACHE_DIR="{{cache_dir}}" \
  RIVA_MODELS_DIR="{{models_dir}}" \
  RIVA_TAGS_SELECTOR="{{tags_selector}}" \
  ./scripts/up.sh

# Stop and remove the Riva container.
down:
  docker rm -f "{{container}}" >/dev/null 2>&1 || true
