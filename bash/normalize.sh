#!/usr/bin/env bash
set -euo pipefail

# =========================
# CONFIG
# =========================
EXCLUDE_DIRS=(.git .normalize bash .obsidian)
DATE_FMT="+%Y-%m-%d_%H-%M-%S"
TIMESTAMP="$(date "$DATE_FMT")"
LOG_DIR=".normalize/$TIMESTAMP"
ACTION_LOG="$LOG_DIR/actions.log"
COLLISION_LOG="$LOG_DIR/collisions.log"

DRY_RUN=false
TARGET_DIR="."

# =========================
# HELP
# =========================
usage() {
  echo "Usage: ./normalize.sh [options] [directory]"
  echo ""
  echo "Options:"
  echo "  -d, --dry-run    Preview only (no prompts, no changes)"
  echo "  -h, --help       Show this help"
}

# =========================
# ARG PARSING
# =========================
while [[ $# -gt 0 ]]; do
  case "$1" in
    -d|--dry-run)
      DRY_RUN=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      TARGET_DIR="$1"
      shift
      ;;
  esac
done

# =========================
# PREP
# =========================
mkdir -p "$LOG_DIR"
: > "$ACTION_LOG"
: > "$COLLISION_LOG"

echo "===== Normalize Script ====="
echo "Timestamp: $TIMESTAMP"
echo "Dry run: $DRY_RUN"
echo "Target directory: $TARGET_DIR"
echo "============================"
echo ""

# =========================
# FUNCTIONS
# =========================
normalize_name() {
  echo "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | sed \
      -e 's/[àáâäãå]/a/g' \
      -e 's/[èéêë]/e/g' \
      -e 's/[ìíîï]/i/g' \
      -e 's/[òóôöõ]/o/g' \
      -e 's/[ùúûü]/u/g' \
      -e 's/ç/c/g' \
      -e 's/ñ/n/g' \
      -e 's/[^a-z0-9._-]/-/g' \
      -e 's/-\{2,\}/-/g' \
      -e 's/^-//' \
      -e 's/-$//'
}

is_excluded() {
  for d in "${EXCLUDE_DIRS[@]}"; do
    [[ "$1" == ./$d* ]] && return 0
  done
  return 1
}

# Safe mv for NTFS / WSL (case-insensitive)
safe_mv() {
  local src="$1"
  local dst="$2"

  # same inode (case-only rename on NTFS)
  if [[ "$(realpath "$src")" == "$(realpath "$dst")" ]]; then
    local tmp="${dst}.tmp-normalize"
    mv "$src" "$tmp"
    mv "$tmp" "$dst"
  else
    mv "$src" "$dst"
  fi
}

# =========================
# MAIN LOOP
# =========================
while IFS= read -r path; do
  [[ "$path" == "." ]] && continue
  is_excluded "$path" && continue

  dir="$(dirname "$path")"
  base="$(basename "$path")"

  if [[ "$base" == *.* && ! -d "$path" ]]; then
    name="${base%.*}"
    ext=".${base##*.}"
  else
    name="$base"
    ext=""
  fi

  normalized="$(normalize_name "$name")"
  new_path="$dir/$normalized$ext"

  [[ "$path" == "$new_path" ]] && continue

  # =========================
  # COLLISION
  # =========================
  if [[ -e "$new_path" ]]; then
    reason="normalization ('$base' → '$normalized$ext')"

    echo "⚠️  COLLISION"
    echo "From: $path"
    echo "To:   $new_path"
    echo "Why:  $reason"
    echo ""

    ls -l "$path" "$new_path"
    echo ""

    if [[ "$DRY_RUN" == true ]]; then
      echo "DRY-RUN: collision detected, skipped"
      echo "SKIP | $path → $new_path | $reason" >> "$COLLISION_LOG"
      echo ""
      continue
    fi

    if [[ ! -d "$path" && ! -d "$new_path" ]]; then
      echo "--- head (existing) ---"
      head -n 10 "$new_path" || true
      echo ""
      echo "--- head (new) ---"
      head -n 10 "$path" || true
      echo ""
    fi

    read -p "Choose: [1] keep existing  [2] replace  [s] skip → " choice < /dev/tty
    case "$choice" in
      1)
        echo "KEEP | $path → $new_path | $reason" >> "$COLLISION_LOG"
        ;;
      2)
        echo "REPLACE | $path → $new_path | $reason" >> "$ACTION_LOG"
        safe_mv "$path" "$new_path"
        ;;
      *)
        echo "SKIP | $path → $new_path | $reason" >> "$COLLISION_LOG"
        ;;
    esac

    echo ""
    continue
  fi

  # =========================
  # NORMAL RENAME
  # =========================
  echo "RENAME | $path → $new_path" | tee -a "$ACTION_LOG"
  [[ "$DRY_RUN" == false ]] && safe_mv "$path" "$new_path"

done < <(find "$TARGET_DIR" -depth)

# =========================
# DONE
# =========================
echo ""
echo "Normalization complete."
echo "Action log:    $ACTION_LOG"
echo "Collision log: $COLLISION_LOG"
