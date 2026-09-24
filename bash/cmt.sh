#!/bin/bash

# Variabili

messaggio=""
do_push=false

# Gestione opzione lunga --push

args=()
for arg in "$@"; do
if [ "$arg" == "--push" ]; then
do_push=true
else
args+=("$arg")
fi
done
set -- "${args[@]}"

# Guarda se ci sono opzioni corte

while getopts "m:hp" opt; do
case $opt in
m)
messaggio=" - $OPTARG"
echo "Messaggio personalizzato: $messaggio"
;;
p)
do_push=true
;;
h)
echo "Uso: $0 [-m messaggio] [-p|--push]"
echo "  -m  (messaggio): aggiungi un messaggio personale al commit oltre a quello di default"
echo "  -p, --push     : esegue anche il push dopo il commit"
exit 0
;;
?)
echo "Opzione non valida: -$OPTARG" >&2
echo "Uso: $0 [-m messaggio] [-p|--push]"
exit 1
;;
esac
done

# Aggiungi tutti i file al commit

git add .

# Mostra lo stato dei file

git status

# Leggi la versione dall'ultimo messaggio di commit o dalla variabile d'ambiente NEW_VERSION

if [ -n "$NEW_VERSION" ]; then
APP_VERSION="$NEW_VERSION"
else
lastCommitMessage=$(git log -1 --pretty=%s 2>/dev/null)

if [ -n "$lastCommitMessage" ]; then
    APP_VERSION=$(echo "$lastCommitMessage" | grep -oP '\[.*?\]' | sed 's/\[//' | sed 's/\]//')

    if [ -z "$APP_VERSION" ]; then
        APP_VERSION="v 0.0.0"
    fi
else
    APP_VERSION="v 0.0.0"
fi

fi

# Debug: mostra la versione trovata

echo "Versione trovata: '$APP_VERSION'"

# Crea il nome del commit con data, ora e versione

nomeCommit=$(date "+%Y %m %d %H:%M")
nomeCommit="aggiornamento $nomeCommit [$APP_VERSION]$messaggio"
echo "Messaggio commit: $nomeCommit"
git commit -am "$nomeCommit"

# Push opzionale

if [ "$do_push" = true ]; then
echo "Eseguo il push..."
git push
fi

sleep 1

# clear

