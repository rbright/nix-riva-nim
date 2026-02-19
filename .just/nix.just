# Format tracked Nix files.
fmt:
  nix develop '{{ tooling_flake }}' -c bash -euo pipefail -c 'mapfile -t files < <(rg --files -g "*.nix"); if [[ "${#files[@]}" -eq 0 ]]; then exit 0; fi; nixfmt "${files[@]}"'

# Check Nix formatting only.
fmt-check:
  nix develop '{{ tooling_flake }}' -c bash -euo pipefail -c 'mapfile -t files < <(rg --files -g "*.nix"); if [[ "${#files[@]}" -eq 0 ]]; then exit 0; fi; nixfmt --check "${files[@]}"'

# Backward-compatible alias.
fmt-nix: fmt

# Lint Nix configs (statix + deadnix + formatting check).
lint-nix:
  nix develop '{{ tooling_flake }}' -c statix check .
  nix develop '{{ tooling_flake }}' -c bash -euo pipefail -c 'mapfile -t files < <(rg --files -g "*.nix"); if [[ "${#files[@]}" -eq 0 ]]; then exit 0; fi; deadnix --fail --no-underscore "${files[@]}"'
  just fmt-check

# Lint shell scripts.
lint-shell:
  nix develop '{{ tooling_flake }}' -c shellcheck scripts/*.sh

# Run lint checks.
lint: lint-nix lint-shell
  @echo "✅ lint passed"

# Evaluate flake outputs.
build:
  nix flake show '{{ tooling_flake }}'

# Full validation gate.
check: fmt-check lint
  nix flake check --all-systems '{{ tooling_flake }}'
  @echo "✅ check passed"

# CI/local gate.
ci: check precommit-run
  @echo "✅ ci checks passed"
