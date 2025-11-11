#!/bin/bash

# Colori per output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

BRANCH=$(git branch --show-current)

echo -e "${YELLOW}Ì≥ù Commit in corso...${NC}"

# Add e status
git add .
git status

# Nome commit con timestamp
nomeCommit=`date "+%Y %m %d %H:%M"`
nomeCommit="aggiornamento "$nomeCommit
git commit -m "$nomeCommit"

clear

echo -e "${GREEN}‚úì${NC} Commit completato su branch $BRANCH"
echo -e "${YELLOW}Ì∫Ä Push al repo privato (origin)...${NC}"
git push origin $BRANCH

# Sincronizzazione branch pubblico con filtraggio intelligente
echo -e "${YELLOW}Ìæ≤ Preparazione branch pubblico...${NC}"
echo -e "${BLUE}Ì¥ç Analisi file per filtraggio...${NC}"

# Crea branch temporaneo
git branch -D public-filtered 2>/dev/null
git checkout -b public-filtered

# Lista per tenere traccia dei file da rimuovere
FILES_TO_REMOVE=()

# Trova tutti i file .md e controlla se contengono #dm
echo -e "${BLUE}   Controllo file .md per tag #dm...${NC}"
while IFS= read -r -d '' file; do
    if grep -q "#dm" "$file"; then
        FILES_TO_REMOVE+=("$file")
        echo -e "${RED}   ‚úó${NC} Nascondo: $file (contiene #dm)"
    fi
done < <(find . -name "*.md" -not -path "./.git/*" -print0)

# Trova tutte le cartelle con "DM" nel nome (case-insensitive)
echo -e "${BLUE}   Controllo cartelle con 'DM' nel nome...${NC}"
while IFS= read -r -d '' dir; do
    # Trova tutti i file (immagini e altri) in queste cartelle
    while IFS= read -r -d '' file; do
        FILES_TO_REMOVE+=("$file")
        echo -e "${RED}   ‚úó${NC} Nascondo: $file (in cartella DM)"
    done < <(find "$dir" -type f -not -path "./.git/*" -print0)
done < <(find . -type d -iname "*dm*" -not -path "./.git/*" -print0)

# Rimuovi i file dall'indice git
if [ ${#FILES_TO_REMOVE[@]} -gt 0 ]; then
    echo -e "${YELLOW}   Rimozione di ${#FILES_TO_REMOVE[@]} file segreti...${NC}"
    for file in "${FILES_TO_REMOVE[@]}"; do
        git rm --cached "$file" 2>/dev/null || true
    done
    
    # Commit le modifiche
    git add -A
    git commit -m "Filtered for players - $nomeCommit" --no-verify 2>/dev/null || true
else
    echo -e "${GREEN}   ‚úì${NC} Nessun file segreto da nascondere"
fi

# Push al repo pubblico
echo -e "${YELLOW}Ìºç Push al repo pubblico (public)...${NC}"
git push -f public public-filtered:$BRANCH

# Torna al branch originale
git checkout $BRANCH

# Pulisci branch temporaneo
git branch -D public-filtered

sleep 2
clear

echo -e "${GREEN}‚úÖ Tutto fatto!${NC}"
echo -e "  ${GREEN}‚úì${NC} Repo privato (origin): aggiornato"
echo -e "  ${GREEN}‚úì${NC} Repo pubblico (public): aggiornato e filtrato"
echo -e "  ${BLUE}‚Ñπ${NC}  File nascosti: ${#FILES_TO_REMOVE[@]}"
sleep 3
clear
