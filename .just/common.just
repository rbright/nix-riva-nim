default:
  @just --list

tooling_flake := "path:" + justfile_directory()
container := "riva-nim"
image := "nvcr.io/nim/nvidia/parakeet-1-1b-ctc-en-us:latest"
env_file := env_var_or_default("RIVA_ENV_FILE", "")
cache_dir := env_var_or_default("RIVA_CACHE_DIR", "")
models_dir := env_var_or_default("RIVA_MODELS_DIR", "")
tags_selector := "name=parakeet-1-1b-ctc-en-us,mode=all"
health_url := "http://127.0.0.1:9000/v1/health/ready"
