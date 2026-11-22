#!/usr/bin/env bash
# Build dist/repo-launcher.zip in the layout Claude.ai expects:
#   repo-launcher.zip
#   └── repo-launcher/
#       └── SKILL.md
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$root/dist"
rm -f "$root/dist/repo-launcher.zip"

cd "$root/skills"
zip -qr -X "$root/dist/repo-launcher.zip" repo-launcher

# fail loudly if SKILL.md isn't under the skill folder
# (list first, then grep: piping into grep -q under pipefail can fail at random)
listing="$(unzip -l "$root/dist/repo-launcher.zip")"
grep -q " repo-launcher/SKILL.md$" <<<"$listing" \
  || { echo "bad zip layout" >&2; exit 1; }

echo "built dist/repo-launcher.zip"
