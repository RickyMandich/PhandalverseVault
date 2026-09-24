#!/bin/bash

# Script per aggiornare il commit hash nel changelog DOPO il commit
# Viene chiamato da all.sh dopo cmt.sh

# Ottieni il percorso completo della directory in cui si trova lo script corrente
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

# Ottieni il percorso della directory del progetto (parent directory dello script)
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Directory per i changelog
CHANGELOG_DIR="$PROJECT_DIR/.normalize/changelogs"
INDEX_FILE="$CHANGELOG_DIR/index.json"

# La versione viene passata come variabile d'ambiente da all.sh
if [ -z "$NEW_VERSION" ]; then
    echo "Errore: Variabile NEW_VERSION non impostata"
    exit 1
fi

cd "$PROJECT_DIR" || exit 1

# Ottieni l'hash e il messaggio del commit appena fatto
commit_hash=$(git rev-parse HEAD)
commit_message=$(git log -1 --pretty=%s)

echo "Aggiornamento commit hash nel changelog..."
echo "Hash: $commit_hash"

# Nome del file changelog
version_filename=$(echo "$NEW_VERSION" | tr ' ' '_' | tr '.' '_')
changelog_file="$CHANGELOG_DIR/${version_filename}.json"

# Verifica che il file esista
if [ ! -f "$changelog_file" ]; then
    echo "File changelog non trovato: $changelog_file"
    exit 1
fi

# Aggiorna il commit_hash e commit_message nel JSON
updated_json=$(jq \
    --arg hash "$commit_hash" \
    --arg message "$commit_message" \
    --tab \
    '.commit_hash = $hash | .commit_message = $message' \
    "$changelog_file")

# Salva il file aggiornato
echo "$updated_json" > "$changelog_file"

# Aggiorna anche l'indice con il commit hash
if [ -f "$INDEX_FILE" ]; then
    updated_index=$(jq \
        --arg version "$NEW_VERSION" \
        --arg hash "$commit_hash" \
        --tab \
        '(.versions[] | select(.version == $version) | .commit_hash) = $hash' \
        "$INDEX_FILE")
    
    echo "$updated_index" > "$INDEX_FILE"
fi

echo "Commit hash aggiornato con successo"

# Aggiungi i file aggiornati a git e fai un commit --amend senza modificare il messaggio
git add "$changelog_file" "$INDEX_FILE"
git commit --amend --no-edit --no-verify

echo "Changelog aggiornato e incluso nel commit"

