#!/bin/bash

# Script per generare changelog JSON per ogni versione
# Traccia le modifiche ai file .md PRIMA del commit, basandosi su git status

# Ottieni il percorso completo della directory in cui si trova lo script corrente
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

# Ottieni il percorso della directory del progetto (parent directory dello script)
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Directory per i changelog
CHANGELOG_DIR="$PROJECT_DIR/.normalize/changelogs"
INDEX_FILE="$CHANGELOG_DIR/index.json"
MAP_FILE="$PROJECT_DIR/.normalize/map.json"

# Crea la directory se non esiste
mkdir -p "$CHANGELOG_DIR"

# La versione viene passata come variabile d'ambiente da all.sh
if [ -z "$NEW_VERSION" ]; then
    echo "Errore: Variabile NEW_VERSION non impostata"
    echo "Questo script deve essere chiamato da all.sh"
    exit 1
fi

# Funzione per ottenere il nome visualizzato dal map.json
get_display_name() {
    local file_path="$1"
    
    # Rimuovi l'estensione .md
    local filename=$(basename "$file_path")
    local dirname=$(dirname "$file_path")
    
    # Costruisci il percorso jq per navigare il map.json
    local jq_path=".directories"
    
    if [ "$dirname" != "." ]; then
        # Split path by / and build jq navigation
        IFS='/' read -ra PATH_PARTS <<< "$dirname"
        for part in "${PATH_PARTS[@]}"; do
            jq_path="${jq_path}.\"${part}\".directories"
        done
    fi
    
    # Remove trailing .directories and add .files["filename"]
    jq_path="${jq_path%.directories}.files[\"${filename}\"]"
    
    # If we're at root level, path is just .files["filename"]
    if [ "$dirname" == "." ]; then
        jq_path=".files[\"${filename}\"]"
    fi
    
    # Query the map
    local display_name=$(jq -r "$jq_path // empty" "$MAP_FILE" 2>/dev/null)
    
    # Se non trovato, usa il nome del file senza estensione
    if [ -z "$display_name" ]; then
        display_name="${filename%.md}"
    fi
    
    echo "$display_name"
}

# Funzione per ottenere il diff di un file dalla working directory
get_file_diff() {
    local file_path="$1"
    local status_code="$2"

    local diff_output=""

    # Per file nuovi (untracked o added)
    if [[ "$status_code" == "A" ]] || [[ "$status_code" == "??" ]]; then
        # Mostra il contenuto completo come se fosse un diff
        if [ -f "$file_path" ]; then
            diff_output="diff --git a/$file_path b/$file_path
new file mode 100644
--- /dev/null
+++ b/$file_path
@@ -0,0 +1,$(wc -l < "$file_path") @@
$(sed 's/^/+/' "$file_path")"
        fi
    # Per file eliminati
    elif [[ "$status_code" == "D" ]]; then
        # Usa git diff per mostrare cosa è stato eliminato
        diff_output=$(git diff HEAD -- "$file_path" 2>/dev/null)
    # Per file modificati
    else
        # Usa git diff per mostrare le modifiche
        diff_output=$(git diff HEAD -- "$file_path" 2>/dev/null)
    fi

    # Escape per JSON usando jq
    echo "$diff_output" | jq -Rs .
}

# Funzione per determinare lo status del file
get_file_status() {
    local status_code="$1"

    case "$status_code" in
        A) echo "Added" ;;
        M) echo "Modified" ;;
        D) echo "Deleted" ;;
        R*) echo "Renamed" ;;
        C*) echo "Copied" ;;
        "??") echo "Added" ;;  # Untracked files
        *) echo "Modified" ;;  # Default per altri casi
    esac
}

# Funzione principale per generare il changelog
generate_changelog() {
    cd "$PROJECT_DIR" || exit 1

    # Usa la versione passata da all.sh
    local version="$NEW_VERSION"

    # Data e ora correnti (il commit non è ancora stato fatto)
    local commit_date=$(date "+%Y-%m-%d %H:%M:%S")

    # Usa l'hash corrente di HEAD come placeholder
    # Verrà sovrascritto dal prossimo commit, ma almeno non è "pending"
    local commit_hash=$(git rev-parse HEAD 2>/dev/null || echo "initial")

    echo "Generazione changelog per versione: $version"
    echo "Data: $commit_date"
    echo "Analizzando modifiche da git status..."

    # Nome del file changelog per questa versione
    # Sostituisci spazi con underscore per il nome del file
    local version_filename=$(echo "$version" | tr ' ' '_' | tr '.' '_')
    local changelog_file="$CHANGELOG_DIR/${version_filename}.json"

    # Array per i cambiamenti
    local changes_json="[]"
    local changes_count=0

    # Ottieni la lista dei file modificati da git status
    # Format: XY filename (X=staged, Y=unstaged)
    # Usiamo --porcelain per output parsabile
    while IFS= read -r line; do
        # Salta righe vuote
        [ -z "$line" ] && continue

        # Estrai status (primi 2 caratteri) e filename (dal carattere 4 in poi)
        local status="${line:0:2}"
        local file="${line:3}"

        # Rimuovi eventuali spazi iniziali dal filename
        file=$(echo "$file" | sed 's/^[[:space:]]*//')

        # Salta se il file è vuoto
        [ -z "$file" ] && continue

        # Processa solo file .md
        if [[ "$file" == *.md ]]; then
            # Ignora file in .trash, bash e .normalize
            if [[ "$file" == .trash/* ]] || [[ "$file" == bash/* ]] || [[ "$file" == .normalize/* ]]; then
                continue
            fi

            echo "  Processando: $file ($status)"

            # Ottieni il nome visualizzato
            local display_name=$(get_display_name "$file")

            # Normalizza lo status (prendi il primo carattere se staged, altrimenti il secondo)
            local status_char="${status:0:1}"
            if [[ "$status_char" == " " ]]; then
                status_char="${status:1:1}"
            fi

            # Ottieni lo status leggibile
            local file_status=$(get_file_status "$status_char")

            # Ottieni il diff
            local diff_content=$(get_file_diff "$file" "$status_char")

            # Crea l'oggetto JSON per questo file
            local file_json=$(jq -n \
                --arg file "$file" \
                --arg display "$display_name" \
                --arg status "$file_status" \
                --argjson diff "$diff_content" \
                '{file: $file, display_name: $display, status: $status, diff: $diff}')

            # Aggiungi all'array dei cambiamenti
            changes_json=$(echo "$changes_json" | jq --argjson item "$file_json" '. += [$item]')
            changes_count=$((changes_count + 1))
        fi
    done < <(git status --porcelain)

    echo "Trovati $changes_count file .md modificati"

    # Se non ci sono modifiche, non creare il changelog
    if [ $changes_count -eq 0 ]; then
        echo "Nessun file .md modificato, changelog non generato"
        return 0
    fi

    # Crea il messaggio di commit che verrà usato (per riferimento)
    local commit_message="aggiornamento $commit_date [$version]"

    # Crea il JSON del changelog (commit_hash sarà aggiornato dopo il commit)
    local changelog_json=$(jq -n \
        --arg version "$version" \
        --arg date "$commit_date" \
        --arg hash "$commit_hash" \
        --arg message "$commit_message" \
        --argjson changes "$changes_json" \
        --tab \
        '{version: $version, date: $date, commit_hash: $hash, commit_message: $message, changes: $changes}')

    # Salva il file changelog
    echo "$changelog_json" > "$changelog_file"
    echo "Changelog salvato in: $changelog_file"

    # Aggiorna l'indice
    update_index "$version" "$commit_date" "$commit_hash" "$changes_count"

    # Aggiungi i file changelog a git
    git add "$changelog_file" "$INDEX_FILE"
    echo "File changelog aggiunti a git staging area"
}

# Funzione per aggiornare l'indice dei changelog
update_index() {
    local version="$1"
    local date="$2"
    local commit_hash="$3"
    local changes_count="$4"

    # Carica l'indice esistente o crea uno nuovo
    local index_json="{\"versions\": []}"
    if [ -f "$INDEX_FILE" ] && [ -s "$INDEX_FILE" ]; then
        # Verifica che il file contenga JSON valido
        local temp_json=$(cat "$INDEX_FILE")
        if echo "$temp_json" | jq empty 2>/dev/null; then
            index_json="$temp_json"
        else
            echo "Attenzione: index.json esistente non è valido, creandone uno nuovo"
        fi
    fi

    # Crea l'oggetto per questa versione
    local version_entry=$(jq -n \
        --arg version "$version" \
        --arg date "$date" \
        --arg hash "$commit_hash" \
        --argjson count "$changes_count" \
        '{version: $version, date: $date, commit_hash: $hash, changes_count: $count}')

    # Rimuovi eventuali entry esistenti per questa versione e aggiungi la nuova
    # Mantieni l'ordine cronologico inverso (più recenti prima)
    index_json=$(echo "$index_json" | jq \
        --argjson entry "$version_entry" \
        --arg version "$version" \
        --tab \
        '.versions = ([.versions[] | select(.version != $version)] + [$entry]) | sort_by(.date) | reverse')

    # Salva l'indice aggiornato
    echo "$index_json" > "$INDEX_FILE"
    echo "Indice aggiornato in: $INDEX_FILE"
}

# Esegui la generazione del changelog
generate_changelog

