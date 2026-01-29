# Implementazione Sistema di Changelog - Riepilogo

## Cosa è stato fatto

È stato implementato un sistema automatico di tracciamento delle modifiche ai file markdown del vault, che genera changelog in formato JSON per ogni versione del progetto.

## File Creati/Modificati

### 1. Nuovo Script: `bash/generate-changelog.sh`
Script bash che genera automaticamente i file JSON di changelog.

**Funzionalità**:
- Legge la versione dall'ultimo commit git
- Identifica tutti i file `.md` modificati nel commit
- Estrae i nomi visualizzati da `.normalize/map.json`
- Genera il diff completo per ogni file modificato
- Crea un file JSON per la versione corrente
- Aggiorna l'indice globale delle versioni

**Esecuzione**: Viene chiamato automaticamente da `all.sh` dopo il commit

### 2. Modificato: `bash/all.sh`
Integrato il nuovo script nel workflow di deploy.

**Nuova sequenza**:
1. Normalizzazione (`normalize.sh`)
2. Versioning (incremento versione)
3. Commit (`cmt.sh`)
4. **Generazione Changelog** (`generate-changelog.sh`) ← NUOVO
5. Deploy FTP (`onlyFtpOfLastCmt.sh`)

### 3. Modificato: `.gitignore`
Aggiornato per tracciare i file di changelog.

**Modifiche**:
```gitignore
# Normalize directory - ignore all except map.json and changelogs
.normalize/*
!.normalize/map.json
!.normalize/changelogs/
!.normalize/changelogs/*.json
```

Questo assicura che i changelog vengano:
- Tracciati da git
- Inclusi nei commit
- Caricati sul server via FTP

### 4. Nuova Documentazione: `bash/CHANGELOG_SYSTEM.md`
Documentazione completa per i backend developer che implementeranno la visualizzazione dei changelog nella web app.

**Contenuto**:
- Panoramica del sistema
- Workflow completo
- Struttura dei file generati
- Formato dettagliato dei dati JSON
- Esempi di integrazione Laravel
- Esempi di visualizzazione HTML
- Note tecniche e troubleshooting

### 5. Aggiornato: `README.md`
Aggiunto riferimento al sistema di changelog nel README principale.

## Struttura dei Dati Generati

### Directory
```
.normalize/changelogs/
├── index.json              # Indice di tutte le versioni
├── v_0_0_1.json           # Changelog versione v 0.0.1
├── v_1_0_0.json           # Changelog versione v 1.0.0
└── ...
```

### File Indice (`index.json`)
Contiene l'elenco di tutte le versioni ordinate dalla più recente alla più vecchia.

**Esempio**:
```json
{
	"versions": [
		{
			"version": "v 1.2.3",
			"date": "2026-01-29 15:30:45",
			"commit_hash": "abc123def456789",
			"changes_count": 5
		},
		{
			"version": "v 1.2.2",
			"date": "2026-01-28 14:20:30",
			"commit_hash": "def789ghi012345",
			"changes_count": 3
		}
	]
}
```

**Utilizzo**: Per mostrare la lista delle versioni disponibili nella pagina changelog.

### File Versione (`v_X_Y_Z.json`)
Contiene i dettagli completi delle modifiche per una specifica versione.

**Esempio**:
```json
{
	"version": "v 1.2.3",
	"date": "2026-01-29 15:30:45",
	"commit_hash": "abc123def456789",
	"commit_message": "aggiornamento 2026 01 29 15:30 [v 1.2.3] - Aggiunta nuova location",
	"changes": [
		{
			"file": "locations/phandalin.md",
			"display_name": "Phandalin",
			"status": "Modified",
			"diff": "diff --git a/locations/phandalin.md b/locations/phandalin.md\nindex abc123..def456 100644\n--- a/locations/phandalin.md\n+++ b/locations/phandalin.md\n@@ -10,7 +10,7 @@\n Contenuto...\n-Vecchia riga\n+Nuova riga\n"
		},
		{
			"file": "artefatti/party/nuovo-artefatto.md",
			"display_name": "Nuovo Artefatto",
			"status": "Added",
			"diff": "diff --git a/artefatti/party/nuovo-artefatto.md b/artefatti/party/nuovo-artefatto.md\nnew file mode 100644\nindex 0000000..abc1234\n--- /dev/null\n+++ b/artefatti/party/nuovo-artefatto.md\n@@ -0,0 +1,10 @@\n+# Nuovo Artefatto\n+\n+Descrizione...\n"
		}
	]
}
```

**Campi Principali**:
- `version`: Versione nel formato "v X.Y.Z"
- `date`: Data e ora del commit (YYYY-MM-DD HH:MM:SS)
- `commit_hash`: Hash completo del commit git
- `commit_message`: Messaggio completo del commit
- `changes`: Array di modifiche

**Campi di ogni modifica**:
- `file`: Percorso relativo del file
- `display_name`: Nome visualizzato (da map.json)
- `status`: Tipo di modifica (Added/Modified/Deleted/Renamed/Copied/Changed)
- `diff`: Diff completo in formato git unified diff

**Utilizzo**: Per mostrare i dettagli di una versione specifica.

## Come Funziona

### Workflow Automatico

1. **Utente modifica file** in Obsidian
2. **Utente esegue** `bash bash/all.sh` (con opzioni `-v`, `-p`, o `-m` se necessario)
3. **normalize.sh** aggiorna `map.json`
4. **all.sh** incrementa la versione
5. **cmt.sh** esegue commit con messaggio contenente la versione
6. **generate-changelog.sh** (NUOVO):
   - Legge la versione dal commit appena fatto
   - Usa `git diff-tree` per trovare i file `.md` modificati
   - Per ogni file:
     - Estrae il nome visualizzato da `map.json`
     - Determina il tipo di modifica (Added/Modified/Deleted)
     - Genera il diff completo con `git show`
   - Crea il file JSON `v_X_Y_Z.json`
   - Aggiorna `index.json` con la nuova versione
7. **onlyFtpOfLastCmt.sh** carica tutto su Altervista (inclusi i changelog)

### Esempio Pratico

**Scenario**: Aggiungi un nuovo artefatto e modifichi una location esistente.

**Comandi**:
```bash
# Dopo aver modificato i file in Obsidian
bash bash/all.sh -m "Aggiunto nuovo artefatto e aggiornata Phandalin"
```

**Risultato**:
1. Versione incrementata: `v 1.2.3` → `v 1.2.4`
2. Commit creato: `"aggiornamento 2026 01 29 15:30 [v 1.2.4] - Aggiunto nuovo artefatto e aggiornata Phandalin"`
3. File generato: `.normalize/changelogs/v_1_2_4.json` con:
   - 2 modifiche tracciate
   - Diff completo per entrambi i file
4. `index.json` aggiornato con la nuova versione in cima alla lista
5. Tutto caricato su Altervista

## Integrazione Backend

### Endpoint Suggeriti per Laravel

#### 1. Lista Versioni
```php
// routes/api.php o routes/web.php
Route::get('/changelog', [ChangelogController::class, 'index']);

// ChangelogController.php
public function index()
{
    $indexPath = storage_path('app/vault/.normalize/changelogs/index.json');
    $index = json_decode(file_get_contents($indexPath), true);
    return view('changelog.index', ['versions' => $index['versions']]);
}
```

#### 2. Dettagli Versione
```php
Route::get('/changelog/{version}', [ChangelogController::class, 'show']);

public function show($version)
{
    $version = preg_replace('/[^a-zA-Z0-9_]/', '', $version);
    $path = storage_path("app/vault/.normalize/changelogs/{$version}.json");
    
    if (!file_exists($path)) {
        abort(404);
    }
    
    $changelog = json_decode(file_get_contents($path), true);
    return view('changelog.show', ['changelog' => $changelog]);
}
```

## Documentazione Completa

Per tutti i dettagli tecnici, esempi di codice e troubleshooting, consulta:

📄 **`bash/CHANGELOG_SYSTEM.md`**

Questo documento contiene:
- Formato completo dei dati JSON
- Esempi di integrazione Laravel
- Esempi di visualizzazione HTML/Blade
- Spiegazione del formato diff
- Note tecniche
- Troubleshooting

## Note Importanti

### File Tracciati
- ✅ Solo file `.md` vengono tracciati
- ❌ File in `.trash/` vengono ignorati
- ❌ File in `bash/` vengono ignorati

### Sincronizzazione
I changelog vengono automaticamente:
1. Tracciati da git (grazie al `.gitignore` aggiornato)
2. Inclusi nei commit
3. Caricati su Altervista via FTP

### Retrocompatibilità
Il sistema è completamente retrocompatibile:
- Non modifica il workflow esistente
- Aggiunge solo un passaggio di generazione changelog
- Non richiede modifiche ai file esistenti
- Funziona con il sistema di versioning già in uso

## Prossimi Passi

1. ✅ Sistema implementato e pronto all'uso
2. ⏳ Testare con il prossimo deploy (eseguendo `bash bash/all.sh`)
3. ⏳ Implementare la visualizzazione nella web app Laravel
4. ⏳ (Opzionale) Generare changelog per versioni precedenti usando `git log`

## Verifica Implementazione

### File Creati
- ✅ `bash/generate-changelog.sh` - Script di generazione changelog
- ✅ `bash/CHANGELOG_SYSTEM.md` - Documentazione tecnica completa
- ✅ `CHANGELOG_IMPLEMENTATION.md` - Questo documento di riepilogo

### File Modificati
- ✅ `bash/all.sh` - Integrato il nuovo script nel workflow
- ✅ `.gitignore` - Configurato per tracciare i changelog
- ✅ `README.md` - Aggiunto riferimento al sistema di changelog

### Sintassi Verificata
- ✅ `bash/generate-changelog.sh` - Nessun errore di sintassi
- ✅ `bash/all.sh` - Nessun errore di sintassi

### Pronto per il Test
Il sistema è completamente implementato e pronto per essere testato al prossimo deploy.

---

**Documentazione per Backend Developer**: `bash/CHANGELOG_SYSTEM.md`
**Workflow Visivo**: Vedi diagramma Mermaid nel task manager

