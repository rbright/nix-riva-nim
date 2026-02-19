# Install prek git hooks.
precommit-install:
  nix develop '{{ tooling_flake }}' -c prek install

# Run prek hooks over all files.
precommit-run:
  nix develop '{{ tooling_flake }}' -c prek run --all-files
