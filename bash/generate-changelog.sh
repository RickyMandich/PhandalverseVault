#!/bin/bash

# Script per generare changelog JSON per una versione specifica
# Se viene passato un commit id come parametro, usa quello.
# Altrimenti fallback a HEAD.

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

CHANGELOG_DIR="$PROJECT_DIR/.normalize/changelogs"
INDEX_FILE="$CHANGELOG_DIR/index.json"
MAP_FILE="$PROJECT_DIR/.normalize/map.json"

mkdir -p "$CHANGELOG_DIR"

# ==============================
# COMMIT SELECTION
# ==============================

COMMIT_REF="${1:-HEAD}"

if ! git rev-parse --verify "$COMMIT_REF" >/dev/null 2>&1; then
    echo "Errore: commit '$COMMIT_REF' non valido"
    exit 1
fi

COMMIT_HASH=$(git rev-parse "$COMMIT_REF")
COMMIT_DATE=$(git show -s --format="%ci" "$COMMIT_REF")
COMMIT_MESSAGE=$(git show -s --format="%s" "$COMMIT_REF")

# ==============================
# ESTRAZIONE VERSIONE DAL COMMIT MESSAGE
# ==============================

# Cerca qualcosa tra parentesi quadre: [v 0.0.217]
VERSION=$(echo "$COMMIT_MESSAGE" | grep -o '\[.*\]' | head -n1 | tr -d '[]')

if [ -z "$VERSION" ]; then
    echo "Errore: nessuna versione trovata nel messaggio di commit."
    echo "Formato atteso: [v 0.0.XXX]"
    exit 1
fi

echo "Versione rilevata: $VERSION"

echo "Generazione changelog per commit: $COMMIT_HASH"
echo "Versione: $NEW_VERSION"

# ==============================
# FUNZIONI
# ==============================

get_display_name() {
    local file_path="$1"

    local filename=$(basename "$file_path")
    local dirname=$(dirname "$file_path")

    local jq_path=".directories"

    if [ "$dirname" != "." ]; then
        IFS='/' read -ra PATH_PARTS <<< "$dirname"
        for part in "${PATH_PARTS[@]}"; do
            jq_path="${jq_path}.\"${part}\".directories"
        done
    fi

    jq_path="${jq_path%.directories}.files[\"${filename}\"]"

    if [ "$dirname" == "." ]; then
        jq_path=".files[\"${filename}\"]"
    fi

    local display_name=$(jq -r "$jq_path // empty" "$MAP_FILE" 2>/dev/null)

    if [ -z "$display_name" ]; then
        display_name="${filename%.md}"
    fi

    echo "$display_name"
}

get_file_status() {
    local status_code="$1"

    case "$status_code" in
        A) echo "Added" ;;
        M) echo "Modified" ;;
        D) echo "Deleted" ;;
        R*) echo "Renamed" ;;
        *) echo "Modified" ;;
    esac
}

# ==============================
# GENERAZIONE CHANGELOG
# ==============================

generate_changelog() {

    cd "$PROJECT_DIR" || exit 1

    local version="$VERSION"

    local version_filename=$(echo "$version" | tr ' ' '_' | tr '.' '_')
    local changelog_file="$CHANGELOG_DIR/${version_filename}.json"
    
    TMP_CHANGES_FILE=$(mktemp)
    echo "[]" > "$TMP_CHANGES_FILE"

    local changes_json="[]"
    local changes_count=0

    # Ottieni file modificati in quel commit
    while IFS= read -r line; do

        [ -z "$line" ] && continue

        local status=$(echo "$line" | awk '{print $1}')
        local file=$(echo "$line" | cut -f2)

        # Solo file .md
        if [[ "$file" != *.md ]]; then
            continue
        fi

        # Ignora cartelle escluse
        if [[ "$file" == .trash/* ]] || [[ "$file" == bash/* ]] || [[ "$file" == .normalize/* ]]; then
            continue
        fi

        echo "  Processando: $file ($status)"

        local display_name=$(get_display_name "$file")
        local file_status=$(get_file_status "$status")

        # Ottieni il diff del file in quel commit
        local diff_output=$(git show "$COMMIT_REF" -- "$file")

        local diff_content=$(echo "$diff_output" | jq -Rs .)

        local file_json=$(jq -n \
            --arg file "$file" \
            --arg display "$display_name" \
            --arg status "$file_status" \
            --argjson diff "$diff_content" \
            '{file: $file, display_name: $display, status: $status, diff: $diff}')

	jq --argjson item "$file_json" '. += [$item]' "$TMP_CHANGES_FILE" > "${TMP_CHANGES_FILE}.tmp" \
    	&& mv "${TMP_CHANGES_FILE}.tmp" "$TMP_CHANGES_FILE"

        changes_count=$((changes_count + 1))

    done < <(git show --name-status --pretty="" "$COMMIT_REF")

    echo "Trovati $changes_count file .md modificati"

    local changelog_json=$(jq -n \
    	--arg version "$version" \
    	--arg date "$COMMIT_DATE" \
    	--arg hash "$commit_hash" \
    	--arg message "$COMMIT_MESSAGE" \
	--slurpfile changes "$TMP_CHANGES_FILE" \
    	--tab \
    	'{version: $version, date: $date, commit_hash: $hash, commit_message: $message, changes: $changes[0]}')

    echo "$changelog_json" > "$changelog_file"

    echo "Changelog salvato in: $changelog_file"

    update_index "$version" "$COMMIT_DATE" "$COMMIT_HASH" "$changes_count"

    git add "$changelog_file" "$INDEX_FILE"
    echo "File changelog aggiunti alla staging area"
    rm "$TMP_CHANGES_FILE"
}

update_index() {

    local version="$1"
    local date="$2"
    local commit_hash="$3"
    local changes_count="$4"

    local index_json="{\"versions\": []}"

    if [ -f "$INDEX_FILE" ] && [ -s "$INDEX_FILE" ]; then
        if jq empty "$INDEX_FILE" 2>/dev/null; then
            index_json=$(cat "$INDEX_FILE")
        else
            echo "index.json non valido, ricreato"
        fi
    fi

    local version_entry=$(jq -n \
        --arg version "$version" \
        --arg date "$date" \
        --arg hash "$commit_hash" \
        --argjson count "$changes_count" \
        '{version: $version, date: $date, commit_hash: $hash, changes_count: $count}')

    index_json=$(echo "$index_json" | jq \
        --argjson entry "$version_entry" \
        --arg version "$version" \
        --tab \
        '.versions = (([.versions[] | select(.version != $version)] + [$entry]) | sort_by(.date) | reverse)')

    echo "$index_json" > "$INDEX_FILE"

    echo "Indice aggiornato"
}

generate_changelog
