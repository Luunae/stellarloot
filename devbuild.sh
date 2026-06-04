#!/usr/bin/env bash
# devbuild.sh — produce a local addon build at build/StellarLoot/ for dev testing.
#
# Usage:
#   ./devbuild.sh           Build only. Output: build/StellarLoot/.
#   ./devbuild.sh deploy    Build, then sync into "$STELLARLOOT_ADDONS_DIR/StellarLoot/"
#                           so a /reload in WoW picks it up. Set the env var to your
#                           WoW AddOns folder, e.g.:
#                             export STELLARLOOT_ADDONS_DIR="$HOME/.local/share/Steam/\
#                             steamapps/compatdata/<id>/pfx/drive_c/Program Files (x86)/\
#                             World of Warcraft/_classic_/Interface/AddOns"
#
# Output is the working tree (not just HEAD), so uncommitted edits are included.
# Version string in the .toc is set from `git describe --tags --always --dirty`.
#
# File list is read from StellarLoot.toc — the addon's own load manifest. A new
# .lua file must be added to the .toc to be loaded by WoW, so the build can't
# silently miss one. If the .toc references a missing file, the build aborts.

set -euo pipefail
cd "$(dirname "$0")"

# Source local config if present, for persistent settings like the AddOns dir.
# This file is gitignored — keep secrets/paths out of the repo.
if [[ -f .devbuild.env ]]; then
    # shellcheck disable=SC1091
    source .devbuild.env
fi

MODE="${1:-build}"
case "$MODE" in
    build|deploy) ;;
    *) echo "error: unknown mode '$MODE' (expected 'build' or 'deploy')" >&2; exit 2 ;;
esac

if [[ "$MODE" == "deploy" && -z "${STELLARLOOT_ADDONS_DIR:-}" ]]; then
    echo "error: deploy mode requires STELLARLOOT_ADDONS_DIR to point at your WoW AddOns folder" >&2
    exit 2
fi

TOC="StellarLoot.toc"
OUT="build/StellarLoot"
VERSION="$(git describe --tags --always --dirty 2>/dev/null || echo 'dev')"

# Extract file references from the .toc: any non-empty, non-directive line.
# Strips trailing CR (in case of CRLF line endings) and leading/trailing whitespace.
mapfile -t FILES < <(awk '!/^##/ && NF { sub(/\r$/, ""); gsub(/^[[:space:]]+|[[:space:]]+$/, ""); print }' "$TOC")

if [[ ${#FILES[@]} -eq 0 ]]; then
    echo "error: no file references found in $TOC" >&2
    exit 1
fi

# Verify every referenced file exists before copying anything.
missing=()
for f in "${FILES[@]}"; do
    [[ -f "$f" ]] || missing+=("$f")
done
if [[ ${#missing[@]} -gt 0 ]]; then
    echo "error: $TOC references files that don't exist:" >&2
    printf '  %s\n' "${missing[@]}" >&2
    exit 1
fi

rm -rf build
mkdir -p "$OUT"

cp "$TOC" "$OUT/$TOC"
for f in "${FILES[@]}"; do
    mkdir -p "$OUT/$(dirname "$f")"
    cp "$f" "$OUT/$f"
done

# Substitute @project-version@ in the TOC, same as the CF packager would.
sed -i "s/@project-version@/${VERSION}/" "$OUT/$TOC"

echo "Built $OUT (version: $VERSION, ${#FILES[@]} source files)"

if [[ "$MODE" == "deploy" ]]; then
    DEST="$STELLARLOOT_ADDONS_DIR/StellarLoot"
    if [[ ! -d "$STELLARLOOT_ADDONS_DIR" ]]; then
        echo "error: AddOns dir does not exist: $STELLARLOOT_ADDONS_DIR" >&2
        exit 1
    fi
    rm -rf "$DEST"
    cp -r "$OUT" "$DEST"
    echo "Deployed to $DEST — /reload in WoW to pick up."
else
    echo "Copy the directory into <WoW>/_classic_/Interface/AddOns/ to install."
fi
