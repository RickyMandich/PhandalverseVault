language: italiano

# Phandalverse Vault

## Gestione
Il vault (i file degli appunti) è generato e modificato grazie a **Obsidian** ed organizzato in cartelle in maniera logica.

## Condivisione
Questi appunti sono disponibili online nel sito **phandalverse.altervista.org** creato con Laravel per essere visibili a tutti solo nelle parti accessibili ai giocatori.

## Workflow Automatizzato

### Script `bash/all.sh`
Lo script principale che gestisce l'intero processo di deploy:

1. **Normalizzazione**: Aggiorna `map.json` con i nuovi file `.md` (modalità non interattiva)
2. **Versioning**: Incrementa automaticamente la versione del progetto
3. **Commit**: Esegue commit su git con la nuova versione
4. **Deploy**: Carica i file modificati via FTP su Altervista

### Utilizzo
```bash
# Deploy standard (incrementa VERSION_TERTIARY)
bash bash/all.sh

# Deploy con patch (incrementa VERSION_SECONDARY)
bash bash/all.sh -p

# Deploy con versione major (incrementa VERSION_PRIMARY)
bash bash/all.sh -v

# Deploy con messaggio personalizzato
bash bash/all.sh -m "Aggiunta nuova location"
```

### Normalizzazione File
Il sistema mantiene un mapping tra i nomi dei file normalizzati (kebab-case) e i nomi originali per la visualizzazione.

- **File normalizzati**: `la-ruota.md`, `nuova-citta.md`
- **Nomi visualizzati**: "La Ruota", "Nuova Città"

Il mapping è gestito automaticamente in `.normalize/map.json`.

Per maggiori dettagli, vedi `bash/normalizeREADME.md`.