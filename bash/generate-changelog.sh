#!/bin/bash

# Script per generare changelog JSON per ogni versione
# Traccia le modifiche ai file .md tra versioni

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

# Funzione per ottenere il diff di un file
get_file_diff() {
    local file_path="$1"
    local commit_hash="$2"
    
    # Ottieni il diff del file per questo commit
    # Usa --unified=3 per avere 3 righe di contesto
    local diff_output=$(git show "$commit_hash" -- "$file_path" 2>/dev/null)
    
    # Escape per JSON (sostituisci newline con \n, escape quotes, etc)
    # Usa jq per fare l'escape corretto
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
        *) echo "Changed" ;;
    esac
}

# Funzione principale per generare il changelog
generate_changelog() {
    cd "$PROJECT_DIR" || exit 1
    
    # Ottieni informazioni sull'ultimo commit
    local commit_hash=$(git rev-parse HEAD)
    local commit_message=$(git log -1 --pretty=%s)
    local commit_date=$(git log -1 --pretty="%Y-%m-%d %H:%M:%S")
    
    # Estrai la versione dal messaggio di commit
    local version=$(echo "$commit_message" | grep -oP '\[.*?\]' | sed 's/\[//' | sed 's/\]//')
    
    if [ -z "$version" ]; then
        echo "Errore: Nessuna versione trovata nel messaggio di commit"
        return 1
    fi
    
    echo "Generazione changelog per versione: $version"
    echo "Commit: $commit_hash"
    echo "Data: $commit_date"
    
    # Nome del file changelog per questa versione
    # Sostituisci spazi con underscore per il nome del file
    local version_filename=$(echo "$version" | tr ' ' '_' | tr '.' '_')
    local changelog_file="$CHANGELOG_DIR/${version_filename}.json"
    
    # Array per i cambiamenti
    local changes_json="[]"
    local changes_count=0
    
    # Ottieni la lista dei file modificati nell'ultimo commit
    # Format: status<TAB>filename
    while IFS=$'\t' read -r status file; do
        # Salta righe vuote
        [ -z "$file" ] && continue
        
        # Processa solo file .md
        if [[ "$file" == *.md ]]; then
            # Ignora file in .trash e bash
            if [[ "$file" == .trash/* ]] || [[ "$file" == bash/* ]]; then
                continue
            fi
            
            echo "  Processando: $file ($status)"
            
            # Ottieni il nome visualizzato
            local display_name=$(get_display_name "$file")
            
            # Ottieni lo status leggibile
            local file_status=$(get_file_status "$status")
            
            # Ottieni il diff
            local diff_content=$(get_file_diff "$file" "$commit_hash")
            
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
    done < <(git diff-tree --no-commit-id --name-status -r "$commit_hash")
    
    echo "Trovati $changes_count file .md modificati"
    
    # Crea il JSON del changelog
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
}

# Funzione per aggiornare l'indice dei changelog
update_index() {
    local version="$1"
    local date="$2"
    local commit_hash="$3"
    local changes_count="$4"
    
    # Carica l'indice esistente o crea uno nuovo
    local index_json="{\"versions\": []}"
    if [ -f "$INDEX_FILE" ]; then
        index_json=$(cat "$INDEX_FILE")
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

