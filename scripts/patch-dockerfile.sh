#!/usr/bin/env bash
# Applies the one change this repository makes to the upstream Dockerfile: the
# licence travels with the image, because OCL requires every distribution to
# reference the licence and its add-on conditions.
#
#   scripts/patch-dockerfile.sh <path to the upstream checkout>
set -euo pipefail

src="${1:?usage: $0 <upstream checkout>}"
dockerfile="$src/docker/server/Dockerfile"

test -f "$dockerfile" || { echo "::error::$dockerfile not found"; exit 1; }
test -f "$src/LICENSE" || { echo "::error::$src/LICENSE not found"; exit 1; }

cat >> "$dockerfile" <<'EOF'

# Added by prusa-connect-unofficial: ship the licence with the image.
COPY LICENSE /usr/share/licenses/prusa-connect/LICENSE
EOF

echo "patched $dockerfile"
