#!/usr/bin/env bash
set -euo pipefail

#######################################
# CONFIG
#######################################
EXCLUDE_DIRS=( ".git" ".normalize" ".obsidian" "bash" )
TIMESTAMP="$(date +%Y-%m-%d_%H-%M-%S)"
LOG_DIR=".normalize/$TIMESTAMP"
ACTION_LOG="$LOG_DIR/actions.log"
COLLISION_LOG="$LOG_DIR/collisions.log"
DRY_RUN=false
TARGET_DIR="."



#######################################
# ARG PARSING
#######################################
while [[ $# -gt 0 ]]; do
  case "$1" in
    -d|--dry-run) DRY_RUN=true ;;
    -h|--help)
      echo "Usage: ./normalize.sh [options] [directory]"
      echo "Options:"
      echo "  -d, --dry-run    Simulate only"
      echo "  -h, --help       Show help"
      exit 0
      ;;
    *) TARGET_DIR="$1" ;;
  esac
  shift
done

mkdir -p "$LOG_DIR"

#######################################
# HEADER
#######################################
echo "===== Normalize Script ====="
echo "Timestamp: $TIMESTAMP"
echo "Dry run: $DRY_RUN"
echo "Target directory: $TARGET_DIR"
echo "Excluded paths: ${EXCLUDE_DIRS[*]}"
echo "============================"
echo

#######################################
# UTILS
#######################################
normalize_name() {
  echo "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E '
        s/[àáâãäå]/a/g;
        s/[èéêë]/e/g;
        s/[ìíîï]/i/g;
        s/[òóôõö]/o/g;
        s/[ùúûü]/u/g;
        s/[^a-z0-9._-]+/-/g;
        s/-+/-/g;
        s/^-|-$//g
      '
}

log_action()    { echo "$1" | tee -a "$ACTION_LOG"; }
log_collision() { echo "$1" | tee -a "$COLLISION_LOG"; }

is_text_file() {
  file --mime-type "$1" | grep -q text/
}

#######################################
# FIND
#######################################
PRUNE_EXPR=""
for d in "${EXCLUDE_DIRS[@]}"; do
  PRUNE_EXPR+=" -path \"$TARGET_DIR/$d\" -o"
done
PRUNE_EXPR="${PRUNE_EXPR% -o}"

eval find "\"$TARGET_DIR\"" -depth \
  \( $PRUNE_EXPR \) -prune -false \
  -o -print |
while read -r path; do

  base="$(basename "$path")"
  dir="$(dirname "$path")"
  norm="$(normalize_name "$base")"

  [[ "$base" == "$norm" ]] && continue

  src="$path"
  dst="$dir/$norm"

  ###################################
  # COLLISION
  ###################################
  if [[ -e "$dst" ]]; then
    echo "⚠️  COLLISION"
    echo "From: $src"
    echo "To:   $dst"
    echo "Why:  normalization ('$base' → '$norm')"
    echo

    echo "--- ls -l ---"
    ls -l "$src" "$dst"
    echo

    echo "--- head (existing) ---"
    is_text_file "$dst" && head -n 5 "$dst" || echo "(binary)"
    echo

    echo "--- head (new) ---"
    is_text_file "$src" && head -n 5 "$src" || echo "(binary)"
    echo

    echo "Choose:"
    echo "  [1] keep existing"
    echo "  [2] replace"
    echo "  [m] merge (text only)"
    echo "  [s] skip"
    read -r -p "→ " choice

    log_collision "COLLISION: $src -> $dst (reason: normalization)"

    case "$choice" in
      1)
        log_action "SKIP (keep existing): $src"
        ;;
      2)
        if [[ "$DRY_RUN" == false ]]; then
          rm -f "$dst"
          mv "$src" "$dst"
        fi
        log_action "REPLACED: $src -> $dst"
        ;;
      m)
        if is_text_file "$src" && is_text_file "$dst"; then
          if [[ "$DRY_RUN" == false ]]; then
            echo -e "\n\n# --- MERGED FROM $src ---\n" >> "$dst"
            cat "$src" >> "$dst"
            rm -f "$src"
          fi
          log_action "MERGED: $src -> $dst"
        else
          log_action "MERGE FAILED (non-text): $src"
        fi
        ;;
      *)
        log_action "SKIPPED: $src"
        ;;
    esac

    echo
    continue
  fi

  ###################################
  # NORMAL RENAME
  ###################################
  echo "✅ Renaming: $src → $dst"
  log_action "RENAME: $src -> $dst"

  if [[ "$DRY_RUN" == false ]]; then
    mv "$src" "$dst"
  fi

done

echo
echo "Normalization complete."
echo "Action log:    $ACTION_LOG"
echo "Collision log: $COLLISION_LOG"
