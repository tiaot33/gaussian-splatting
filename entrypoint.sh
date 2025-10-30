#!/usr/bin/env bash
set -e

# Enable conda in non-interactive shells and activate the project env
source /opt/conda/etc/profile.d/conda.sh
conda activate gaussian_splatting

# Run the given command in the activated environment
exec "$@"

