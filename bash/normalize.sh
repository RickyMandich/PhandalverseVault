#!/bin/bash

# Configuration
VAULT_ROOT=$(pwd)
NORMALIZE_DIR="$VAULT_ROOT/.normalize"
FINAL_MAP_FILE="$NORMALIZE_DIR/map.json"
OLD_MAP_FILE="$NORMALIZE_DIR/map.json"
NEW_FILES_LIST="$NORMALIZE_DIR/new_files.txt"
# Excluded Names (Files or Dirs) - Basenames only
EXCLUDE_NAMES=("bash" ".git" ".obsidian" ".trash" ".normalize")

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

# Dependency Check
if ! command -v jq &> /dev/null; then
    log_message "ERROR: 'jq' is not installed."
    echo "Please install jq: sudo apt-get install jq"
    exit 1
fi

log_message "Starting map.json update process (Read-Only Filesystem Mode)..."

# Check if git work tree is clean (only .md files matter)
if command -v git &> /dev/null; then
    # Check for untracked, modified, or deleted .md files
    MD_CHANGES=$(git status --porcelain | grep '\.md$' || true)

    if [ -z "$MD_CHANGES" ]; then
        log_message "No .md file changes detected in git work tree. Skipping map update."
        echo "No .md file changes detected. Skipping map update."
        exit 0
    else
        log_message "Detected .md file changes in work tree:"
        echo "$MD_CHANGES" | while read line; do
            log_message "  $line"
        done
    fi
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

# Helper: Check if item is excluded
is_excluded() {
    local name="$1"
    for ex in "${EXCLUDE_NAMES[@]}"; do
        if [ "$name" == "$ex" ]; then
            return 0
        fi
    done
    return 1
}

# Helper: Convert kebab-case to Title Case
# Example: "la-ruota" -> "La Ruota"
kebab_to_title() {
    local input="$1"
    # Replace hyphens with spaces, then capitalize first letter of each word
    local result=$(echo "$input" | tr '-' ' ' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) tolower(substr($i,2));}1')
    echo "$result"
}

# Helper: Get original name from old map
# Parameters: $1 = relative path from vault root, $2 = current filename
get_original_name_from_map() {
    local rel_path="$1"
    local filename="$2"

    # Build jq path to navigate the old map
    # Example: "artefatti/party/file.md" -> .directories.artefatti.directories.party.files["file.md"]
    local jq_path=".directories"

    if [ "$rel_path" != "." ]; then
        # Split path by / and build jq navigation
        IFS='/' read -ra PATH_PARTS <<< "$rel_path"
        for part in "${PATH_PARTS[@]}"; do
            jq_path="${jq_path}.\"${part}\".directories"
        done
    fi

    # Remove trailing .directories and add .files["filename"]
    jq_path="${jq_path%.directories}.files[\"${filename}\"]"

    # If we're at root level, path is just .files["filename"]
    if [ "$rel_path" == "." ]; then
        jq_path=".files[\"${filename}\"]"
    fi

    # Query the old map
    local original_name=$(echo "$OLD_MAP" | jq -r "$jq_path // empty" 2>/dev/null)

    echo "$original_name"
}

# Helper: Get original directory name from old map
get_original_dir_from_map() {
    local rel_path="$1"
    local dirname="$2"

    # Build jq path
    local jq_path=".directories"

    if [ "$rel_path" != "." ]; then
        IFS='/' read -ra PATH_PARTS <<< "$rel_path"
        for part in "${PATH_PARTS[@]}"; do
            jq_path="${jq_path}.\"${part}\".directories"
        done
    fi

    jq_path="${jq_path}.\"${dirname}\".original"

    # If we're at root level
    if [ "$rel_path" == "." ]; then
        jq_path=".directories.\"${dirname}\".original"
    fi

    local original_name=$(echo "$OLD_MAP" | jq -r "$jq_path // empty" 2>/dev/null)

    echo "$original_name"
}

# Recursive Function
# Parameters: $1 = current directory path, $2 = relative path from vault root
process_directory() {
    local current_dir="$1"
    local rel_path="$2"

    # Store local map data
    local files_json="{}"
    local dirs_json="{}"

    # Get immediate children
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
            # DIRECTORY: Recurse first
            local new_rel_path="$rel_path/$item_name"
            if [ "$rel_path" == "." ]; then
                new_rel_path="$item_name"
            fi

            process_directory "$item_path" "$new_rel_path"

            # Get original name from old map, custom map, or use kebab-to-title
            local original_dir_name=$(get_original_dir_from_map "$rel_path" "$item_name")

            # Check if we have a custom name from interactive editing
            if [ -n "${CUSTOM_NAMES_MAP[$new_rel_path]}" ]; then
                original_dir_name="${CUSTOM_NAMES_MAP[$new_rel_path]}"
                log_message "Using custom name for directory '$item_name': '$original_dir_name'"
            elif [ -z "$original_dir_name" ]; then
                # New directory - use auto-generated name for now
                original_dir_name=$(kebab_to_title "$item_name")
                log_message "New directory found: '$item_name' -> '$original_dir_name'"
                NEW_DIRS_MAP["$new_rel_path"]="$original_dir_name"
            fi

            # Read child map
            local child_map_file="$item_path/.node.json"
            if [ -f "$child_map_file" ]; then
                local child_content=$(cat "$child_map_file")
                # Update the original name in child content
                child_content=$(echo "$child_content" | jq --arg orig "$original_dir_name" '.original = $orig')
                dirs_json=$(echo "$dirs_json" | jq --arg k "$item_name" --argjson v "$child_content" '.[$k] = $v')
                rm "$child_map_file"
            fi

        elif [ -f "$item_path" ]; then
            # FILE: Only process .md files
            local extension="${item_name##*.}"

            if [ "$extension" != "md" ]; then
                continue
            fi

            local name_no_ext="${item_name%.*}"

            # Get original name from old map, custom map, or use kebab-to-title
            local file_rel_path="$rel_path/$item_name"
            if [ "$rel_path" == "." ]; then
                file_rel_path="$item_name"
            fi

            local original_name=$(get_original_name_from_map "$rel_path" "$item_name")

            # Check if we have a custom name from interactive editing
            if [ -n "${CUSTOM_NAMES_MAP[$file_rel_path]}" ]; then
                original_name="${CUSTOM_NAMES_MAP[$file_rel_path]}"
                log_message "Using custom name for '$item_name': '$original_name'"
            elif [ -z "$original_name" ]; then
                # New file - use auto-generated name for now
                original_name=$(kebab_to_title "$name_no_ext")
                log_message "New file found: '$item_name' -> '$original_name'"
                NEW_FILES_MAP["$file_rel_path"]="$original_name"
            fi

            # Add to files map
            files_json=$(echo "$files_json" | jq --arg k "$item_name" --arg v "$original_name" '.[$k] = $v')
        fi
    done

    # Determine original name for this directory
    local my_original_name=$(basename "$current_dir")

    if [ "$current_dir" == "." ] || [ "$current_dir" == "$VAULT_ROOT" ]; then
        my_original_name="ROOT"
    else
        # Get from parent's perspective
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

    # Build Final JSON Node with tab indentation
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

# Check if there are new files/directories and handle interactive editing
NEW_FILES_COUNT=${#NEW_FILES_MAP[@]}
NEW_DIRS_COUNT=${#NEW_DIRS_MAP[@]}
TOTAL_NEW=$((NEW_FILES_COUNT + NEW_DIRS_COUNT))

if [ $TOTAL_NEW -gt 0 ]; then
    log_message "Found $NEW_FILES_COUNT new file(s) and $NEW_DIRS_COUNT new directory(ies)"

    if [ "$INTERACTIVE_MODE" = true ]; then
        # Create temporary file for editing
        cat > "$NEW_FILES_LIST" << 'EOF'
# New files and directories found
# Edit the display names on the right side of the pipe (|)
# Format: path|Display Name
# Save and close to apply changes, or delete lines to use auto-generated names
#
EOF

        # Add new files
        if [ $NEW_FILES_COUNT -gt 0 ]; then
            echo "# Files:" >> "$NEW_FILES_LIST"
            for filepath in "${!NEW_FILES_MAP[@]}"; do
                echo "$filepath|${NEW_FILES_MAP[$filepath]}" >> "$NEW_FILES_LIST"
            done
            echo "" >> "$NEW_FILES_LIST"
        fi

        # Add new directories
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

        # Open vim for editing
        vim "$NEW_FILES_LIST"

        # Read back the edited values into CUSTOM_NAMES_MAP
        while IFS='|' read -r path display_name; do
            # Skip comments and empty lines
            [[ "$path" =~ ^#.*$ ]] && continue
            [[ -z "$path" ]] && continue

            # Trim whitespace
            path=$(echo "$path" | xargs)
            display_name=$(echo "$display_name" | xargs)

            # Store in custom names map
            CUSTOM_NAMES_MAP[$path]="$display_name"
            log_message "Custom name set: '$path' -> '$display_name'"
        done < "$NEW_FILES_LIST"

        # Clean up
        rm "$NEW_FILES_LIST"

        log_message "Applying customized names..."

        # SECOND PASS: Rebuild with custom names
        # Clear the temporary .node.json files first
        find . -name ".node.json" -type f -delete

        # Clear the tracking maps
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
    # Format the final JSON with tab indentation before saving
    jq --tab '.' ".node.json" > "$FINAL_MAP_FILE"
    rm ".node.json"

    log_message "Map updated at $FINAL_MAP_FILE"
else
    log_message "Error: No map generated."
fi

log_message "Map update complete. No files were renamed."

