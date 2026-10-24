# shellcheck shell=bash
# shellcheck disable=SC2016  # perl code in single quotes is meant to stay unexpanded
# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Aaron K. Clark
#
# Shared helpers for install.sh and uninstall.sh.

BEGIN_MARK="<!-- ChoomCheats BEGIN -->"
END_MARK="<!-- ChoomCheats END -->"

# Accept F6, f6 or IK_F6; reject anything that isn't a plain key id.
normalize_key() {
  local k="$1"
  case "$k" in IK_*) ;; *) k="IK_$(printf '%s' "$k" | tr '[:lower:]' '[:upper:]')" ;; esac
  if ! printf '%s' "$k" | grep -Eq '^IK_[A-Za-z0-9_]+$'; then
    echo "Invalid key: $1" >&2
    exit 2
  fi
  printf '%s' "$k"
}

# Resolve the game folder: the given path, or the first common install location.
find_game() {
  local given="$1" c
  local candidates=(
    "$given"
    "/Applications/Cyberpunk 2077"
    "$HOME/Library/Application Support/Steam/steamapps/common/Cyberpunk 2077"
    "$HOME/Applications/Cyberpunk 2077"
  )
  for d in /Volumes/*/Games/"Cyberpunk 2077"; do candidates+=("$d"); done
  for c in "${candidates[@]}"; do
    [ -n "$c" ] || continue
    if [ -d "$c/Cyberpunk2077.app" ] && [ -f "$c/r6/config/inputUserMappings.xml" ]; then
      (cd "$c" && pwd)
      return
    fi
    if [ -n "$given" ] && [ "$c" = "$given" ]; then
      echo "Not a Cyberpunk 2077 game folder: $given" >&2
      exit 2
    fi
  done
  echo "Couldn't find Cyberpunk 2077. Pass the folder with --game." >&2
  exit 2
}

confirm() {
  local yes="$1" prompt="$2" reply
  [ "$yes" = 1 ] && return 0
  read -r -p "$prompt [y/N] " reply
  [ "$reply" = y ] || [ "$reply" = Y ]
}

# Rewrite a game config file with perl, replacing it only if perl succeeds.
# The game ships these files with CRLF line endings; perl sees $ENV{EOL} as
# the file's own line ending so inserted lines match it.
#   edit_file FILE PERL_CODE
edit_file() {
  local target="$1" code="$2" tmp eol=$'\n'
  if LC_ALL=C grep -q $'\r$' "$target"; then eol=$'\r\n'; fi
  tmp="$(mktemp "$target.XXXXXX")"
  if ! EOL="$eol" BEGIN_MARK="$BEGIN_MARK" END_MARK="$END_MARK" perl -0pe "$code" "$target" > "$tmp"; then
    rm -f "$tmp"
    echo "Couldn't update $target; it was left unchanged." >&2
    return 1
  fi
  chmod "$(stat -f %Lp "$target")" "$tmp"
  mv "$tmp" "$target"
}

# Perl that removes any existing ChoomCheats block.
STRIP_CODE='s/[ \t]*\Q$ENV{BEGIN_MARK}\E.*?\Q$ENV{END_MARK}\E[ \t]*\r?\n//gs;'

# Print a file with any ChoomCheats block removed.
strip_block() {
  BEGIN_MARK="$BEGIN_MARK" END_MARK="$END_MARK" perl -0pe "$STRIP_CODE" "$1"
}

# Write the four mappings and their actions, replacing any earlier block.
write_bindings() {
  local mappings="$1" contexts="$2"
  local keys=("$3" "$4" "$5" "$6")
  local names=(ChoomToggleGod ChoomToggleMoney ChoomToggleInvisible ChoomToggleCarry)
  local map_lines="" ctx_lines="" i

  # Blocks are built with "|" as the line separator, swapped for EOL in perl.
  for i in 0 1 2 3; do
    map_lines+="\t<mapping name=\"${names[$i]}_Button\" type=\"Button\" >|\t\t<button id=\"${keys[$i]}\" />|\t</mapping>|"
    ctx_lines+="\t\t<action name=\"${names[$i]}\" map=\"${names[$i]}_Button\" />|"
  done
  export CHOOM_MAP="\t$BEGIN_MARK|$map_lines\t$END_MARK|"
  export CHOOM_CTX="\t\t$BEGIN_MARK|$ctx_lines\t\t$END_MARK|"

  # Mappings go just before the closing </bindings>.
  edit_file "$mappings" "$STRIP_CODE"'
    my $b = $ENV{CHOOM_MAP}; $b =~ s/\\t/\t/g; $b =~ s/\|/$ENV{EOL}/g;
    s{(</bindings>\s*)\z}{$b$1} or die "no closing </bindings> found\n";' || return 1

  # Actions join the QuickLoadAndSave context, which is active on foot and in
  # vehicles (the same places Quick Save works).
  edit_file "$contexts" "$STRIP_CODE"'
    my $b = $ENV{CHOOM_CTX}; $b =~ s/\\t/\t/g; $b =~ s/\|/$ENV{EOL}/g;
    s{(<context name="QuickLoadAndSave"[^>]*>[ \t]*\r?\n)}{$1$b} or die "no QuickLoadAndSave context found\n";'
}

# Remove both blocks.
remove_bindings() {
  local f
  for f in "$@"; do
    edit_file "$f" "$STRIP_CODE" || return 1
  done
}

compile_scripts() {
  local scc="$1" game="$2"
  if [ ! -x "$scc" ]; then
    echo "redscript isn't installed, so scripts weren't compiled." >&2
    return 1
  fi
  echo "Compiling scripts..."
  "$scc" -compile "$game/r6/scripts"
}
