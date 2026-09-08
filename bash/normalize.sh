# Configuration
VAULT_ROOT=$(pwd)
NORMALIZE_DIR="$VAULT_ROOT/.normalize"
FINAL_MAP_FILE="$NORMALIZE_DIR/map.json"
OLD_MAP_FILE="$NORMALIZE_DIR/map.json"
NEW_FILES_LIST="$NORMALIZE_DIR/new_files.txt"
IGNORE_FILE="$VAULT_ROOT/.normalizeignore"

# Excluded Names (Files or Dirs) - Basenames or glob patterns
# Se esiste .normalizeignore nella root del vault, le esclusioni vengono
# lette da lì (una per riga, righe vuote e che iniziano con # ignorate).
# Se il file non esiste, si usano questi default e non viene creato nulla.
DEFAULT_EXCLUDE_NAMES=("bash" ".git" ".obsidian" ".trash" ".normalize")

EXCLUDE_NAMES=()
if [ -f "$IGNORE_FILE" ]; then
    while IFS= read -r line || [ -n "$line" ]; do
        # Rimuovi spazi iniziali/finali
        line=$(echo "$line" | xargs)
        # Salta righe vuote e commenti
        [[ -z "$line" ]] && continue
        [[ "$line" == \#* ]] && continue
        EXCLUDE_NAMES+=("$line")
    done < "$IGNORE_FILE"
else
    EXCLUDE_NAMES=("${DEFAULT_EXCLUDE_NAMES[@]}")
fi

# Parse command line arguments
INTERACTIVE_MODE=true
if [ "$1" == "--no-edit" ]; then
    INTERACTIVE_MODE=false
fi

# Logging Setup
DATE_STR=$(date +%Y-%m-%d_%H-%M-%S)
LOG_DIR="$NORMALIZE_DIR/logs/$DATE_STR"
LOG_FILE="$LOG_DIR/execution.log"

mkdir -p "$LOG_DIR"

# Redirect stderr to log
exec 2>>"$LOG_FILE"

log_message() {
    local msg="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') $msg" | tee -a "$LOG_FILE"
}

if [ "$INTERACTIVE_MODE" = false ]; then
    log_message "Running in non-interactive mode (--no-edit)"
fi

if [ -f "$IGNORE_FILE" ]; then
    log_message "Esclusioni caricate da .normalizeignore (${#EXCLUDE_NAMES[@]} pattern)"
else
    log_message "Nessun .normalizeignore trovato, uso esclusioni di default (${#EXCLUDE_NAMES[@]} pattern)"
fi

# Dependency Check
if ! command -v jq &> /dev/null; then
    log_message "ERROR: 'jq' is not installed."
    echo "Please install jq: sudo apt-get install jq"
    exit 1
fi

log_message "Starting map.json update process (Read-Only Filesystem Mode)..."

# Check if git work tree is clean (only .md and .pdf files matter)
if command -v git &> /dev/null; then
    MD_CHANGES=$(git status --porcelain | grep -E '\.(md|pdf)$' || true)

    #if [ -z "$MD_CHANGES" ]; then
    #    log_message "No .md/.pdf file changes detected in git work tree. Skipping map update."
    #    echo "No .md/.pdf file changes detected. Skipping map update."
    #    exit 0
    #else
        log_message "Detected .md/.pdf file changes in work tree:"
        echo "$MD_CHANGES" | while read line; do
            log_message "  $line"
        done
    #fi
fi

# Load existing map.json if it exists
OLD_MAP="{}"
if [ -f "$OLD_MAP_FILE" ]; then
    OLD_MAP=$(cat "$OLD_MAP_FILE")
    log_message "Loaded existing map.json"
else
    log_message "No existing map.json found, creating new one"
fi

# Initialize new files tracking
declare -A NEW_FILES_MAP
declare -A NEW_DIRS_MAP
declare -A CUSTOM_NAMES_MAP

# Helper: Check if item is excluded (supporta pattern glob, es. "*.tmp")
is_excluded() {
    local name="$1"
    for ex in "${EXCLUDE_NAMES[@]}"; do
        if [[ "$name" == $ex ]]; then
            return 0
        fi
    done
    return 1
}

# Helper: Convert kebab-case to Title Case
kebab_to_title() {
    local input="$1"
    local result=$(echo "$input" | tr '-' ' ' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) tolower(substr($i,2));}1')
    echo "$result"
}

# Helper: Get original name from old map
get_original_name_from_map() {
    local rel_path="$1"
    local filename="$2"

    local jq_path=".directories"

    if [ "$rel_path" != "." ]; then
        IFS='/' read -ra PATH_PARTS <<< "$rel_path"
        for part in "${PATH_PARTS[@]}"; do
            jq_path="${jq_path}.\"${part}\".directories"
        done
    fi

    jq_path="${jq_path%.directories}.files[\"${filename}\"]"

    if [ "$rel_path" == "." ]; then
        jq_path=".files[\"${filename}\"]"
    fi

    local original_name=$(echo "$OLD_MAP" | jq -r "$jq_path // empty" 2>/dev/null)

    echo "$original_name"
}

# Helper: Get original directory name from old map
get_original_dir_from_map() {
    local rel_path="$1"
    local dirname="$2"

    local jq_path=".directories"

    if [ "$rel_path" != "." ]; then
        IFS='/' read -ra PATH_PARTS <<< "$rel_path"
        for part in "${PATH_PARTS[@]}"; do
            jq_path="${jq_path}.\"${part}\".directories"
        done
    fi

    jq_path="${jq_path}.\"${dirname}\".original"

    if [ "$rel_path" == "." ]; then
        jq_path=".directories.\"${dirname}\".original"
    fi

    local original_name=$(echo "$OLD_MAP" | jq -r "$jq_path // empty" 2>/dev/null)

    echo "$original_name"
}

# Recursive Function
process_directory() {
    local current_dir="$1"
    local rel_path="$2"

    local files_json="{}"
    local dirs_json="{}"

    local items=()
    while IFS= read -r -d '' item; do
        items+=("$item")
    done < <(find "$current_dir" -mindepth 1 -maxdepth 1 -print0)

    local item_path
    for item_path in "${items[@]}"; do
        local item_name=$(basename "$item_path")

        if is_excluded "$item_name"; then
            continue
        fi

        if [ -d "$item_path" ]; then
            local new_rel_path="$rel_path/$item_name"
            if [ "$rel_path" == "." ]; then
                new_rel_path="$item_name"
            fi

            process_directory "$item_path" "$new_rel_path"

            local child_map_file="$item_path/.node.json"
            if [ -f "$child_map_file" ]; then
                local original_dir_name=$(get_original_dir_from_map "$rel_path" "$item_name")

                if [ -n "${CUSTOM_NAMES_MAP[$new_rel_path]}" ]; then
                    original_dir_name="${CUSTOM_NAMES_MAP[$new_rel_path]}"
                    log_message "Using custom name for directory '$item_name': '$original_dir_name'"
                elif [ -z "$original_dir_name" ]; then
                    original_dir_name=$(kebab_to_title "$item_name")
                    log_message "New directory found: '$item_name' -> '$original_dir_name'"
                    NEW_DIRS_MAP["$new_rel_path"]="$original_dir_name"
                fi

                local child_content=$(cat "$child_map_file")
                child_content=$(echo "$child_content" | jq --arg orig "$original_dir_name" '.original = $orig')
                dirs_json=$(echo "$dirs_json" | jq --arg k "$item_name" --argjson v "$child_content" '.[$k] = $v')
                rm "$child_map_file"
            else
                log_message "Skipping empty directory (no .md content): '$item_name'"
            fi

        elif [ -f "$item_path" ]; then
            local extension="${item_name##*.}"

            if [ "$extension" != "md" ] && [ "$extension" != "pdf" ]; then
                continue
            fi

            local name_no_ext="${item_name%.*}"

            local file_rel_path="$rel_path/$item_name"
            if [ "$rel_path" == "." ]; then
                file_rel_path="$item_name"
            fi

            local original_name=$(get_original_name_from_map "$rel_path" "$item_name")

            if [ -n "${CUSTOM_NAMES_MAP[$file_rel_path]}" ]; then
                original_name="${CUSTOM_NAMES_MAP[$file_rel_path]}"
                log_message "Using custom name for '$item_name': '$original_name'"
            elif [ -z "$original_name" ]; then
                original_name=$(kebab_to_title "$name_no_ext")
                log_message "New file found: '$item_name' -> '$original_name'"
                NEW_FILES_MAP["$file_rel_path"]="$original_name"
            fi

            files_json=$(echo "$files_json" | jq --arg k "$item_name" --arg v "$original_name" '.[$k] = $v')
        fi
    done

    # Se la cartella non contiene file .md/.pdf né sottocartelle non vuote,
    # non viene indicizzata: git non traccia le cartelle vuote, quindi
    # includerla in map.json creerebbe una discrepanza col deploy.
    if [ "$files_json" == "{}" ] && [ "$dirs_json" == "{}" ]; then
        log_message "Directory vuota, non indicizzata: '$rel_path'"
        return
    fi

    local my_original_name=$(basename "$current_dir")

    if [ "$current_dir" == "." ] || [ "$current_dir" == "$VAULT_ROOT" ]; then
        my_original_name="ROOT"
    else
        local parent_rel_path=$(dirname "$rel_path")
        if [ "$parent_rel_path" == "." ]; then
            parent_rel_path="."
        fi
        local dir_basename=$(basename "$rel_path")
        local original_from_map=$(get_original_dir_from_map "$parent_rel_path" "$dir_basename")
        if [ -n "$original_from_map" ]; then
            my_original_name="$original_from_map"
        else
            my_original_name=$(kebab_to_title "$my_original_name")
        fi
    fi

    local node_json
    node_json=$(jq -n \
                  --arg orig "$my_original_name" \
                  --argjson files "$files_json" \
                  --argjson dirs "$dirs_json" \
                  --tab \
                  '{original: $orig, files: $files, directories: $dirs}')

    echo "$node_json" > "$current_dir/.node.json"
}

# FIRST PASS: Scan filesystem and collect new files
log_message "First pass: Scanning filesystem..."
process_directory "." "."

NEW_FILES_COUNT=${#NEW_FILES_MAP[@]}
NEW_DIRS_COUNT=${#NEW_DIRS_MAP[@]}
TOTAL_NEW=$((NEW_FILES_COUNT + NEW_DIRS_COUNT))

if [ $TOTAL_NEW -gt 0 ]; then
    log_message "Found $NEW_FILES_COUNT new file(s) and $NEW_DIRS_COUNT new directory(ies)"

    if [ "$INTERACTIVE_MODE" = true ]; then
        cat > "$NEW_FILES_LIST" << 'EOF'
# New files and directories found
# Edit the display names on the right side of the pipe (|)
# Format: path|Display Name
# Save and close to apply changes, or delete lines to use auto-generated names
#
EOF

        if [ $NEW_FILES_COUNT -gt 0 ]; then
            echo "# Files:" >> "$NEW_FILES_LIST"
            for filepath in "${!NEW_FILES_MAP[@]}"; do
                echo "$filepath|${NEW_FILES_MAP[$filepath]}" >> "$NEW_FILES_LIST"
            done
            echo "" >> "$NEW_FILES_LIST"
        fi

        if [ $NEW_DIRS_COUNT -gt 0 ]; then
            echo "# Directories:" >> "$NEW_FILES_LIST"
            for dirpath in "${!NEW_DIRS_MAP[@]}"; do
                echo "$dirpath|${NEW_DIRS_MAP[$dirpath]}" >> "$NEW_FILES_LIST"
            done
        fi

        log_message "Opening editor for customization..."
        echo ""
        echo "=========================================="
        echo "Found $TOTAL_NEW new item(s)"
        echo "Opening vim to customize display names..."
        echo "=========================================="
        echo ""

        vim "$NEW_FILES_LIST"

        while IFS='|' read -r path display_name; do
            [[ "$path" =~ ^#.*$ ]] && continue
            [[ -z "$path" ]] && continue

            path=$(echo "$path" | xargs)
            display_name=$(echo "$display_name" | xargs)

            CUSTOM_NAMES_MAP[$path]="$display_name"
            log_message "Custom name set: '$path' -> '$display_name'"
        done < "$NEW_FILES_LIST"

        rm "$NEW_FILES_LIST"

        log_message "Applying customized names..."

        find . -name ".node.json" -type f -delete

        declare -A NEW_FILES_MAP
        declare -A NEW_DIRS_MAP

        log_message "Second pass: Rebuilding map with custom names..."
        process_directory "." "."
    else
        log_message "Non-interactive mode: using auto-generated names"
    fi
fi

# Move Result and format with tab indentation
if [ -f ".node.json" ]; then
    jq --tab '.' ".node.json" > "$FINAL_MAP_FILE"
    rm ".node.json"

    log_message "Map updated at $FINAL_MAP_FILE"
else
    log_message "Error: No map generated."
fi

log_message "Map update complete. No files were renamed."
