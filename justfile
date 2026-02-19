set shell := ["bash", "-euo", "pipefail", "-c"]
set positional-arguments

import ".just/common.just"
import ".just/runtime.just"
import ".just/observability.just"
import ".just/health.just"
import ".just/nix.just"
import ".just/hooks.just"
