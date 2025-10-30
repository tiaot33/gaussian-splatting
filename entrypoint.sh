#!/usr/bin/env bash
set -e

# Enable micromamba in non-interactive shells and activate the project env
if command -v micromamba >/dev/null 2>&1; then
  eval "$(micromamba shell hook -s bash)"
  micromamba activate gaussian_splatting
fi

# Run the given command in the activated environment
exec "$@"
