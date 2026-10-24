#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Aaron K. Clark
#
# Removes ChoomCheats: deletes the mod, removes its key bindings and
# recompiles the game scripts. redscript itself is left installed because
# other mods may use it.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib.sh
source "$REPO_DIR/scripts/lib.sh"

GAME=""
YES=0
while [ $# -gt 0 ]; do
  case "$1" in
    --game) GAME="$2"; shift 2 ;;
    --yes|-y) YES=1; shift ;;
    -h|--help) echo "Usage: scripts/uninstall.sh [--game DIR] [--yes]"; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done

GAME="$(find_game "$GAME")"
MAPPINGS="$GAME/r6/config/inputUserMappings.xml"
CONTEXTS="$GAME/r6/config/inputContexts.xml"

echo "ChoomCheats uninstaller"
echo "  Game folder: $GAME"
echo
echo "Planned changes:"
echo "  - delete r6/scripts/ChoomCheats"
echo "  - remove the ChoomCheats key bindings from inputUserMappings.xml and inputContexts.xml"
echo "  - recompile the game scripts (redscript stays installed)"
echo
confirm "$YES" "Proceed?" || { echo "Nothing changed."; exit 1; }

rm -rf "$GAME/r6/scripts/ChoomCheats"
remove_bindings "$MAPPINGS" "$CONTEXTS"
compile_scripts "$GAME/engine/tools/scc" "$GAME" || true
echo "ChoomCheats removed. Backups (*.choomcheats.bak) were kept in r6/config."
