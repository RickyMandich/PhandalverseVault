#!/usr/bin/env bash
set -euo pipefail

# =========================
# CONFIG
# =========================
EXCLUDE_DIRS=(.git .normalize .obsidian bash)
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
  echo "  -d, --dry-run    Simulate only, do not rename files"
  echo "  -h, --help       Show this help message"
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
touch "$ACTION_LOG" "$COLLISION_LOG"

mv_cmd="mv"
$DRY_RUN && mv_cmd="echo mv"

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
  local name="$1"

  echo "$name" \
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
  local path="$1"
  for d in "${EXCLUDE_DIRS[@]}"; do
    [[ "$path" == ./$d* ]] && return 0
  done
  return 1
}

# =========================
# MAIN LOOP
# =========================
find "$TARGET_DIR" -depth | while read -r path; do
  [[ "$path" == "." ]] && continue
  is_excluded "$path" && continue

  dir="$(dirname "$path")"
  base="$(basename "$path")"

  # split extension
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

    echo "⚠️  COLLISION DETECTED"
    echo "Original:     $path"
    echo "Normalized:   $new_path"
    echo "Reason:       $reason"
    echo ""

    echo "--- ls -l ---"
    ls -l "$path" "$new_path"
    echo ""

    if [[ ! -d "$path" && ! -d "$new_path" ]]; then
      echo "--- head (existing) ---"
      head -n 10 "$new_path" || true
      echo ""
      echo "--- head (new) ---"
      head -n 10 "$path" || true
      echo ""
    fi

    read -p "Choose: [1] keep existing  [2] replace with new  [s] skip → " choice
    case "$choice" in
      1)
        echo "KEEP existing | $path → $new_path | $reason" | tee -a "$COLLISION_LOG"
        ;;
      2)
        echo "REPLACE | $path → $new_path | $reason" | tee -a "$ACTION_LOG"
        $mv_cmd "$path" "$new_path"
        ;;
      *)
        echo "SKIP | $path → $new_path | $reason" | tee -a "$COLLISION_LOG"
        ;;
    esac

    echo ""
    continue
  fi

  # =========================
  # NORMAL RENAME
  # =========================
  echo "✅ Renaming: $path → $new_path" | tee -a "$ACTION_LOG"
  $mv_cmd "$path" "$new_path"

done

echo ""
echo "Normalization complete."
echo "Action log: $ACTION_LOG"
echo "Collision log: $COLLISION_LOG"

