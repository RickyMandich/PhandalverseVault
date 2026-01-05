#!/usr/bin/env bash
set -Eeuo pipefail

########################
# CONFIG & ARGUMENTS
########################

TARGET="."
DRY_RUN=false

for arg in "$@"; do
  case "$arg" in
    -d|--dry-run) DRY_RUN=true ;;
    *) TARGET="$arg" ;;
  esac
done

TIMESTAMP="$(date "+%Y-%m-%d_%H-%M-%S")"
LOG_DIR=".normalize/$TIMESTAMP"
ACTION_LOG="$LOG_DIR/actions.log"
COLLISION_LOG="$LOG_DIR/collisions.log"

EXCLUDED_DIRS=(
  ".git"
  ".normalize"
  "bash"
  ".obsidian"
)


mkdir -p "$LOG_DIR"

echo "===== Normalize Script ====="
echo "Timestamp: $TIMESTAMP"
echo "Dry run: $DRY_RUN"
echo "Target directory: $TARGET"
echo "============================"
echo

########################
# HELPERS
########################

normalize_name() {
  local name="$1"

  # accenti → base
  name="$(printf '%s' "$name" | iconv -f UTF-8 -t ASCII//TRANSLIT)"

  # lowercase
  name="$(printf '%s' "$name" | tr '[:upper:]' '[:lower:]')"

  # safe chars
  name="$(printf '%s' "$name" \
    | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//')"

  printf '%s' "$name"
}

safe_mv() {
  local src="$1"
  local dst="$2"

  if [[ "$(realpath "$src")" == "$(realpath "$dst")" ]]; then
    local tmp="${dst}.tmp-normalize"
    mv "$src" "$tmp"
    mv "$tmp" "$dst"
  else
    mv "$src" "$dst"
  fi
}

prompt_choice() {
  local prompt="$1"
  local choice

  while true; do
    read -rp "$prompt " choice
    case "$choice" in
      1|2|s|m) echo "$choice"; return ;;
      *) echo "Invalid choice. Use 1, 2, s or m." ;;
    esac
  done
}

log_collision() {
  {
    echo "COLLISION"
    echo "From: $1"
    echo "To:   $2"
    echo "Why:  $3"
    echo
  } >> "$COLLISION_LOG"
}

########################
# MAIN LOOP
########################

export -f normalize_name safe_mv prompt_choice log_collision

find "$TARGET" \
  $(for d in "${EXCLUDED_DIRS[@]}"; do
      printf -- '-path %q -prune -o ' "$TARGET/$d"
    done) \
  -depth -print
while IFS= read -r path; do
  base="$(basename "$path")"
  dir="$(dirname "$path")"

  normalized="$(normalize_name "$base")"
  [[ "$base" == "$normalized" ]] && continue

  new_path="$dir/$normalized"
  reason="normalization ('$base' → '$normalized')"

  # no collision
  if [[ ! -e "$new_path" ]]; then
    echo "RENAME | $path → $new_path" >> "$ACTION_LOG"
    echo "✅ Renaming: $path → $new_path"
    [[ "$DRY_RUN" == false ]] && safe_mv "$path" "$new_path"
    continue
  fi

  ########################
  # COLLISION HANDLING
  ########################

  log_collision "$path" "$new_path" "$reason"

  echo
  echo "⚠️  COLLISION DETECTED"
  echo "Original:     $path"
  echo "Normalized:   $new_path"
  echo "Reason:       $reason"
  echo

  echo "--- ls -l ---"
  ls -l "$path" "$new_path"
  echo

  if [[ -f "$path" && -f "$new_path" ]]; then
    echo "--- head (existing) ---"
    head -n 5 "$new_path" || true
    echo
    echo "--- head (new) ---"
    head -n 5 "$path" || true
    echo
  fi

  if [[ "$DRY_RUN" == true ]]; then
    echo "DRY-RUN | collision detected, no action taken"
    continue
  fi

  echo "Choose:"
  echo "[1] keep existing"
  echo "[2] replace with normalized"
  echo "[s] skip"
  if [[ -d "$path" && -d "$new_path" ]]; then
    echo "[m] merge directories"
  fi

  choice="$(prompt_choice "→")"

  case "$choice" in
    1)
      echo "KEEP | $path" >> "$ACTION_LOG"
      rm -rf "$path"
      ;;
    2)
      echo "REPLACE | $path → $new_path" >> "$ACTION_LOG"
      rm -rf "$new_path"
      safe_mv "$path" "$new_path"
      ;;
    m)
      echo "MERGE | $path → $new_path" >> "$ACTION_LOG"
      cp -a "$path/." "$new_path/"
      rm -rf "$path"
      ;;
    s)
      echo "SKIP | $path → $new_path | $reason" >> "$ACTION_LOG"
      ;;
  esac

done

echo
echo "Normalization complete."
echo "Action log: $ACTION_LOG"
echo "Collision log: $COLLISION_LOG"
