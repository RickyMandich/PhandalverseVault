#!/bin/bash

# Variabile per il messaggio personalizzato
messaggio=""

# Guarda se ci sono opzioni
while getopts "m:h" opt; do
    case $opt in
        m)
            messaggio=" - $OPTARG"
            echo "Messaggio personalizzato: $messaggio"
            ;;
        h)
            echo "Uso: $0 [-m messaggio]"
            echo "  -m  (messaggio): aggiungi un messaggio personale al commit oltre a quello di default"
            exit 0
            ;;
        \?)
            echo "Opzione non valida: -$OPTARG" >&2
            echo "Uso: $0 [-m messaggio]"
            echo "  -m  (messaggio): aggiungi un messaggio personale al commit oltre a quello di default"
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
    # Se NEW_VERSION è impostata (da all.sh), usala
    APP_VERSION="$NEW_VERSION"
else
    # Altrimenti leggi dall'ultimo commit
    lastCommitMessage=$(git log -1 --pretty=%s 2>/dev/null)

    if [ -n "$lastCommitMessage" ]; then
        # Estrai la versione dal messaggio di commit (formato: [tipo X.Y.Z])
        APP_VERSION=$(echo "$lastCommitMessage" | grep -oP '\[.*?\]' | sed 's/\[//' | sed 's/\]//')

        if [ -z "$APP_VERSION" ]; then
            # Se non c'è versione nell'ultimo commit, inizia con v 0.0.0
            APP_VERSION="v 0.0.0"
        fi
    else
        # Se non ci sono commit, inizia con v 0.0.0
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

# Esegui il push sul repository remoto
git push

sleep 1
# clear