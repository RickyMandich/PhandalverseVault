# Sistema di Changelog - Quick Start

## 🎯 Cosa Fa

Traccia automaticamente tutte le modifiche ai file `.md` per ogni versione e genera file JSON pronti per la web app.

## 📁 File Generati

```
.normalize/changelogs/
├── index.json              # Lista di tutte le versioni
├── v_0_0_1.json           # Dettagli versione 0.0.1
├── v_0_0_2.json           # Dettagli versione 0.0.2
└── ...
```

## 🚀 Come Funziona

**Niente da fare!** Il sistema è completamente automatico.

Quando esegui:
```bash
bash bash/all.sh
```

Il sistema:
1. ✅ Normalizza i file
2. ✅ Incrementa la versione
3. ✅ Fa il commit
4. ✅ **Genera automaticamente il changelog** ← NUOVO
5. ✅ Carica tutto su Altervista (inclusi i changelog)

## 📊 Formato Dati

### Index.json
```json
{
  "versions": [
    {
      "version": "v 1.2.3",
      "date": "2026-01-29 15:30:45",
      "commit_hash": "abc123...",
      "changes_count": 5
    }
  ]
}
```

### v_1_2_3.json
```json
{
  "version": "v 1.2.3",
  "date": "2026-01-29 15:30:45",
  "commit_hash": "abc123...",
  "commit_message": "aggiornamento 2026 01 29 15:30 [v 1.2.3]",
  "changes": [
    {
      "file": "locations/phandalin.md",
      "display_name": "Phandalin",
      "status": "Modified",
      "diff": "diff --git a/locations/phandalin.md..."
    }
  ]
}
```

## 📚 Documentazione

### Per Te (Utente)
- **Quick Start**: Questo file
- **README.md**: Aggiornato con info sul changelog

### Per Backend Developer
- **`bash/CHANGELOG_SYSTEM.md`**: Documentazione tecnica completa
- **`bash/CHANGELOG_EXAMPLES.md`**: Esempi concreti di JSON e codice Laravel
- **`CHANGELOG_IMPLEMENTATION.md`**: Riepilogo implementazione

## 🔧 File Modificati

- ✅ `bash/all.sh` - Integrato il nuovo script
- ✅ `.gitignore` - Configurato per tracciare i changelog
- ✅ `README.md` - Aggiunto riferimento al sistema

## 📝 File Creati

- ✅ `bash/generate-changelog.sh` - Script di generazione
- ✅ `bash/CHANGELOG_SYSTEM.md` - Documentazione tecnica
- ✅ `bash/CHANGELOG_EXAMPLES.md` - Esempi pratici
- ✅ `CHANGELOG_IMPLEMENTATION.md` - Riepilogo implementazione
- ✅ `CHANGELOG_QUICK_START.md` - Questo file

## ✅ Verifica

- ✅ Sintassi script verificata
- ✅ Integrazione in `all.sh` completata
- ✅ `.gitignore` configurato
- ✅ Documentazione completa

## 🎬 Prossimi Passi

1. **Testa il sistema**: Al prossimo deploy, verifica che i file JSON vengano generati in `.normalize/changelogs/`
2. **Passa ai backend developer**: Condividi `bash/CHANGELOG_SYSTEM.md` e `bash/CHANGELOG_EXAMPLES.md`
3. **Implementa nella web app**: I backend developer possono creare la pagina changelog usando i file JSON

## 💡 Note

- Solo file `.md` vengono tracciati
- File in `.trash/` e `bash/` vengono ignorati
- I changelog vengono caricati automaticamente su Altervista
- Il sistema è completamente retrocompatibile

## 🆘 Problemi?

Se qualcosa non funziona, controlla:
1. Il commit contiene modifiche a file `.md`?
2. Il messaggio di commit contiene `[v X.Y.Z]`?
3. Lo script `generate-changelog.sh` ha i permessi di esecuzione?

Per dettagli: vedi `bash/CHANGELOG_SYSTEM.md` sezione "Troubleshooting"

---

**Tutto pronto!** 🎉

Il sistema è implementato e funzionerà automaticamente al prossimo deploy.

