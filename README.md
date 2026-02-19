# nix-riva-nim

[![CI](https://github.com/rbright/nix-riva-nim/actions/workflows/ci.yml/badge.svg)](https://github.com/rbright/nix-riva-nim/actions/workflows/ci.yml)

Nix-first local packaging and operations repo for NVIDIA Riva NIM (Parakeet ASR).

## What this repo provides

- NixOS module: `nixosModules.default` (`services.rivaNim`)
- Local operations/tasks via `just`
- Pre-commit hooks via `prek`
- CI gate for Nix formatting, linting, flake checks, and shell checks

## Quickstart

```sh
# list tasks
just --list

# local quality gate
just ci

# start and verify service locally
just gpu-smoke
just up
just health
```

## Install on NixOS

```nix
{
  imports = [ inputs.riva.nixosModules.default ];

  services.rivaNim = {
    enable = true;
    envFile = "/home/<user>/.config/riva/riva-nim.env";
    cacheDir = "/var/lib/riva-nim/cache";
    modelsDir = "/var/lib/riva-nim/models";
    runtimeUid = 1000;
    runtimeGid = 1000;
  };
}
```

### Required secret

```sh
install -d -m 700 "$HOME/.config/riva"
cat > "$HOME/.config/riva/riva-nim.env" <<'EOF'
NGC_API_KEY=YOUR_KEY_HERE
EOF
chmod 600 "$HOME/.config/riva/riva-nim.env"
```

## Build and validation

```sh
just fmt-check
just lint
just precommit-run
nix flake check --all-systems path:.
```

## Pre-commit hooks

```sh
just precommit-install
```

## Task reference

| Task | Purpose |
|---|---|
| `just gpu-smoke` | Verify Docker GPU access (`nvidia-smi` in container). |
| `just up` | Start/replace local Riva container. |
| `just down` | Stop and remove local Riva container. |
| `just health [timeout] [interval]` | Poll readiness endpoint with bounded wait + phase hints. |
| `just logs` | Follow raw container logs. |
| `just logs-verbose [since] [tail]` | Follow logs with timestamps/details. |
| `just logs-focus [since]` | Follow filtered high-signal startup/error logs. |
| `just logs-service [lines]` | Follow `docker-riva-nim.service` journal logs. |
| `just progress [tail]` | One-shot state snapshot (container/GPU/disk/logs). |
| `just fmt` | Format tracked Nix files. |
| `just fmt-check` | Check Nix formatting only. |
| `just lint-nix` | Run `statix`, `deadnix`, and formatting checks. |
| `just lint-shell` | Run `shellcheck` on repo shell scripts. |
| `just lint` | Run all lint checks. |
| `just precommit-install` | Install `prek` hooks into `.git/hooks`. |
| `just precommit-run` | Run all configured pre-commit hooks. |
| `just check` | Full local gate (`fmt-check`, `lint`, flake checks). |
| `just ci` | CI/local gate (`check` + `precommit-run`). |

## Runtime overrides

`just up` defaults:

- env file: `~/.config/riva/riva-nim.env`
- cache dir: `~/.cache/riva-nim/cache`
- models dir: `~/.cache/riva-nim/models`

Override per run:

```sh
RIVA_ENV_FILE=/path/to/riva.env just up
RIVA_CACHE_DIR=/path/to/cache just up
RIVA_MODELS_DIR=/path/to/models just up
```

## Notes

- `up` normalizes `NGC_API_KEY` (strips quotes/CR) and validates non-empty key.
- First cold startup can take several minutes while model/engine artifacts are built.
