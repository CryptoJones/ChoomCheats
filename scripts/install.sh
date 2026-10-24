#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Aaron K. Clark
#
# Installs ChoomCheats into Cyberpunk 2077 for macOS:
#   1. installs redscript 0.5.32 into the game folder if it is missing
#   2. copies the mod into r6/scripts/ChoomCheats
#   3. binds the four toggle actions to keys in r6/config (backups kept)
#   4. compiles the game scripts so the mod loads on the next launch
#
# Shows the plan and asks before changing anything. Safe to run again.

set -euo pipefail

REDSCRIPT_VERSION="0.5.32"
REDSCRIPT_URL="https://github.com/jac3km4/redscript/releases/download/v${REDSCRIPT_VERSION}/redscript-v${REDSCRIPT_VERSION}-macos.zip"
REDSCRIPT_SHA256="b9df6cc0144d786dff9590eb6db913d20744055ab694e52fc8c4584eaee39a8a"

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MOD_SRC="$REPO_DIR/src/r6/scripts/ChoomCheats"
# shellcheck source=scripts/lib.sh
source "$REPO_DIR/scripts/lib.sh"

usage() {
  cat <<EOF
Usage: scripts/install.sh [--game DIR] [--yes]
                          [--key-god KEY] [--key-money KEY]
                          [--key-invisible KEY] [--key-carry KEY]

  --game DIR   folder that contains Cyberpunk2077.app (auto-detected if omitted)
  --yes        don't ask for confirmation
  --key-*      key for each toggle, e.g. F6 or IK_F6 (defaults: F6 F7 F8 F10)

F9 is the game's Quick Load key, so it is not used by default.
EOF
}

GAME=""
YES=0
KEY_GOD="IK_F6"
KEY_MONEY="IK_F7"
KEY_INVISIBLE="IK_F8"
KEY_CARRY="IK_F10"

while [ $# -gt 0 ]; do
  case "$1" in
    --game) GAME="$2"; shift 2 ;;
    --yes|-y) YES=1; shift ;;
    --key-god) KEY_GOD="$(normalize_key "$2")"; shift 2 ;;
    --key-money) KEY_MONEY="$(normalize_key "$2")"; shift 2 ;;
    --key-invisible) KEY_INVISIBLE="$(normalize_key "$2")"; shift 2 ;;
    --key-carry) KEY_CARRY="$(normalize_key "$2")"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
done

GAME="$(find_game "$GAME")"
MAPPINGS="$GAME/r6/config/inputUserMappings.xml"
CONTEXTS="$GAME/r6/config/inputContexts.xml"
SCC="$GAME/engine/tools/scc"

# Warn when a chosen key is already bound by the game itself.
for key in "$KEY_GOD" "$KEY_MONEY" "$KEY_INVISIBLE" "$KEY_CARRY"; do
  if strip_block "$MAPPINGS" | grep -q "id=\"$key\""; then
    echo "Warning: $key is already bound to a game action; pressing it will do both." >&2
  fi
done

echo "ChoomCheats installer"
echo "  Game folder: $GAME"
echo
echo "Planned changes:"
if [ -x "$SCC" ]; then
  echo "  - redscript: already installed, left as is"
else
  echo "  - redscript: download $REDSCRIPT_VERSION, verify SHA-256, unpack into the game folder,"
  echo "    clear the download quarantine flag on engine/tools"
fi
echo "  - copy the mod to r6/scripts/ChoomCheats (replacing any older copy)"
echo "  - back up inputUserMappings.xml and inputContexts.xml (first run only, *.choomcheats.bak)"
echo "  - bind: infinite health=${KEY_GOD#IK_}  infinite money=${KEY_MONEY#IK_}  invisible=${KEY_INVISIBLE#IK_}  unlimited carry=${KEY_CARRY#IK_}"
echo "  - compile the game scripts with redscript"
echo
confirm "$YES" "Proceed?" || { echo "Nothing changed."; exit 1; }

# 1. redscript
if [ ! -x "$SCC" ]; then
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  zip="${CHOOM_REDSCRIPT_ZIP:-}"
  if [ -z "$zip" ]; then
    echo "Downloading redscript $REDSCRIPT_VERSION..."
    curl -fL --retry 3 -o "$tmp/redscript.zip" "$REDSCRIPT_URL"
    zip="$tmp/redscript.zip"
  fi
  actual="$(shasum -a 256 "$zip" | cut -d' ' -f1)"
  if [ "$actual" != "$REDSCRIPT_SHA256" ]; then
    echo "redscript download failed its checksum (got $actual). Nothing installed." >&2
    exit 1
  fi
  unzip -o -q "$zip" -d "$GAME"
  xattr -dr com.apple.quarantine "$GAME/engine/tools" 2>/dev/null || true
  chmod +x "$SCC" "$GAME/launch_modded.sh" 2>/dev/null || true
  echo "Installed redscript $REDSCRIPT_VERSION."
fi

# 2. mod files
rm -rf "$GAME/r6/scripts/ChoomCheats"
mkdir -p "$GAME/r6/scripts"
cp -R "$MOD_SRC" "$GAME/r6/scripts/ChoomCheats"
echo "Copied the mod."

# 3. key bindings
for f in "$MAPPINGS" "$CONTEXTS"; do
  [ -f "$f.choomcheats.bak" ] || cp -p "$f" "$f.choomcheats.bak"
done
write_bindings "$MAPPINGS" "$CONTEXTS" "$KEY_GOD" "$KEY_MONEY" "$KEY_INVISIBLE" "$KEY_CARRY"
echo "Bound the toggle keys."

# 4. compile
compile_scripts "$SCC" "$GAME"

echo
echo "Done. Start the game from GOG Galaxy, Steam or the game app as usual."
echo "In-game: ${KEY_GOD#IK_} health, ${KEY_MONEY#IK_} money, ${KEY_INVISIBLE#IK_} invisible, ${KEY_CARRY#IK_} carry"
echo "(hold fn on Mac keyboards). Re-run this script after a game update."
