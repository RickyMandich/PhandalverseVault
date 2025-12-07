#!/bin/bash

# Ottieni il percorso completo della directory in cui si trova lo script corrente
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

# Ottieni il percorso della directory del progetto (parent directory dello script)
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Variabili per le opzioni
VERSION_MAJOR=false
VERSION_PATCH=false
COMMIT_MESSAGE=""

# Parsing delle opzioni
while getopts "vpm:h" opt; do
    case $opt in
        v)
            VERSION_MAJOR=true
            ;;
        p)
            VERSION_PATCH=true
            ;;
        m)
            COMMIT_MESSAGE="$OPTARG"
            echo "Messaggio personalizzato: $COMMIT_MESSAGE"
            ;;
        h)
            echo "Uso: $0 [-v] [-p] [-m messaggio]"
            echo "  -v  (versione): Incrementa VERSION_PRIMARY e resetta VERSION_SECONDARY a 0"
            echo "  -p  (patch): Incrementa VERSION_SECONDARY e resetta VERSION_TERTIARY a 0"
            echo "  -m  (messaggio): Aggiungi un messaggio personale al commit"
            echo "  (default): Incrementa solo VERSION_TERTIARY"
            echo ""
            echo "La versione viene letta dall'ultimo messaggio di commit (formato: [tipo X.Y.Z])"
            echo "Le opzioni -v e -p non possono essere usate insieme"
            exit 0
            ;;
        \?)
            echo "Opzione non valida: -$OPTARG" >&2
            echo "Uso: $0 [-v] [-p] [-m messaggio]"
            echo "  -v  (versione): Incrementa VERSION_PRIMARY e resetta VERSION_SECONDARY a 0"
            echo "  -p  (patch): Incrementa VERSION_SECONDARY e resetta VERSION_TERTIARY a 0"
            echo "  -m  (messaggio): Aggiungi un messaggio personale al commit"
            echo "Le opzioni -v e -p non possono essere usate insieme"
            exit 1
            ;;
    esac
done

# Controlla che non siano state specificate entrambe le opzioni
if [ "$VERSION_MAJOR" = true ] && [ "$VERSION_PATCH" = true ]; then
    echo "Errore: Le opzioni -v e -p non possono essere usate insieme"
    exit 1
fi

# Funzione per incrementare le versioni leggendo dall'ultimo commit
increment_version() {
    cd "$PROJECT_DIR" || exit 1

    # Leggi l'ultimo messaggio di commit
    local lastCommitMessage=$(git log -1 --pretty=%s 2>/dev/null)

    # Estrai la versione corrente dall'ultimo commit (formato: [tipo X.Y.Z])
    local currentVersion=$(echo "$lastCommitMessage" | grep -oP '\[.*?\]' | sed 's/\[//' | sed 's/\]//')

    if [ -z "$currentVersion" ]; then
        # Se non c'è versione nell'ultimo commit, inizia con v 0.0.0
        currentVersion="v 0.0.0"
    fi

    # Estrai tipo e numeri di versione
    local versionType=$(echo "$currentVersion" | cut -d' ' -f1)
    local versionNumbers=$(echo "$currentVersion" | cut -d' ' -f2)

    local current_primary=$(echo "$versionNumbers" | cut -d'.' -f1)
    local current_secondary=$(echo "$versionNumbers" | cut -d'.' -f2)
    local current_tertiary=$(echo "$versionNumbers" | cut -d'.' -f3)

    # Valori di default se non trovati
    current_primary=${current_primary:-0}
    current_secondary=${current_secondary:-0}
    current_tertiary=${current_tertiary:-0}

    if [ "$VERSION_MAJOR" = true ]; then
        # Incrementa VERSION_PRIMARY e resetta VERSION_SECONDARY e TERTIARY a 0
        new_primary=$((current_primary + 1))
        new_secondary=0
        new_tertiary=0

        echo "VERSION_PRIMARY incrementato da $current_primary a $new_primary"
        echo "VERSION_SECONDARY resettato a 0"
        echo "VERSION_TERTIARY resettato a 0"

    elif [ "$VERSION_PATCH" = true ]; then
        # Incrementa VERSION_SECONDARY e resetta TERTIARY a 0
        new_primary=$current_primary
        new_secondary=$((current_secondary + 1))
        new_tertiary=0

        echo "VERSION_SECONDARY incrementato da $current_secondary a $new_secondary"
        echo "VERSION_TERTIARY resettato a 0"

    else
        # Comportamento predefinito: incrementa solo VERSION_TERTIARY
        new_primary=$current_primary
        new_secondary=$current_secondary
        new_tertiary=$((current_tertiary + 1))

        echo "VERSION_TERTIARY incrementato da $current_tertiary a $new_tertiary"
    fi

    # Esporta la nuova versione per cmt.sh
    export NEW_VERSION="$versionType $new_primary.$new_secondary.$new_tertiary"
    echo "Nuova versione: $NEW_VERSION"
}

# Incrementa la versione prima di fare commit e deploy
increment_version

# Esegui gli script usando il percorso completo
# Passa il messaggio personalizzato a cmt.sh se presente
if [ -n "$COMMIT_MESSAGE" ]; then
    "$SCRIPT_DIR/cmt.sh" -m "$COMMIT_MESSAGE"
else
    "$SCRIPT_DIR/cmt.sh"
fi
"$SCRIPT_DIR/onlyFtpOfLastCmt.sh"