# Normalize Script

## Why This Script Exists

The Phandalverse Vault contains notes created and maintained in **Obsidian**, which allows human-friendly filenames with:
- Spaces and special characters (e.g., `La Ruota.md`, `Tel'Aran'Rhiod.md`)
- Mixed case (e.g., `Personaggi/Giocanti/Thraal.md`)
- Non-ASCII characters (e.g., `Líthos.md`, `città`)

However, these filenames cause problems when serving the vault through the **Laravel web application**:
- **URL Issues**: Spaces and special characters require complex encoding
- **File System Compatibility**: Different operating systems handle case sensitivity differently
- **Web Server Security**: Special characters can cause routing and security issues
- **Consistency**: Mixed naming conventions make the codebase harder to maintain

The normalization script solves this by maintaining a **mapping file** (`map.json`) that preserves the original display names while the filesystem uses **safe, web-friendly filenames**.

## What It Does

### Map Update Process

The script performs a **recursive, depth-first traversal** of the vault to update the `map.json` file:

1. **Scans Only `.md` Files**: Only Markdown files are tracked in the map
   - Other file types (`.png`, `.jpg`, `.ds`, etc.) are ignored
   - Directories are tracked to maintain the hierarchical structure

2. **Preserves Existing Mappings**:
   - If a file already exists in `map.json`, its original display name is preserved
   - Example: `la-ruota.md` keeps its mapping to `"La Ruota"` across multiple runs

3. **Handles New Files**:
   - New files not in the existing map are converted from kebab-case to Title Case
   - Example: `nuova-location.md` → `"Nuova Location"`
   - Conversion: Replace hyphens with spaces, capitalize first letter of each word

4. **No Filesystem Changes**:
   - **Files are NOT renamed** - the script only updates `map.json`
   - The filesystem remains unchanged
   - Safe to run multiple times without side effects

### Generated Artifacts

#### 1. `.normalize/map.json`
A **hierarchical tree structure** that maps normalized filenames to original display names:

```json
{
  "original": "ROOT",
  "files": {
    "readme.md": "README",
    "la-ruota.md": "La Ruota"
  },
  "directories": {
    "personaggi": {
      "original": "Personaggi",
      "files": {
        "thraal.md": "Thraal"
      },
      "directories": {
        "non-giocanti": {
          "original": "Non Giocanti",
          "files": {
            "gundren-rockseeker.md": "Gundren Rockseeker"
          }
        }
      }
    }
  }
}
```

**Important**:
- For **files**, the map stores the **original name WITHOUT extension** (e.g., `"La Ruota"` not `"La Ruota.md"`)
- For **directories**, the map stores the full structure with an `"original"` key for the display name

#### 2. `.normalize/YYYY-MM-DD_HH-MM-SS/execution.log`
A timestamped log of every operation:
- New files discovered
- New directories discovered
- Existing mappings preserved
- Errors and warnings

## How to Use

### Prerequisites
- **jq**: JSON processor (`sudo apt-get install jq`)
- **vim**: Text editor (usually pre-installed on Unix systems)
- **WSL/Bash**: Unix environment (Windows users need WSL)

### Running the Script

#### Interactive Mode (Default)
```bash
cd PhandalverseVault
bash bash/normalize.sh
```

When new files or directories are found, vim will automatically open with a list like:
```
# New files and directories found
# Edit the display names on the right side of the pipe (|)
# Format: path|Display Name

# Files:
artefatti/nuova-spada.md|Nuova Spada
personaggi/nuovo-png.md|Nuovo Png

# Directories:
luoghi/nuova-citta|Nuova Citta
```

**Edit the display names**, save (`:wq`), and the script will apply your changes.

#### Non-Interactive Mode (For Automation)
```bash
cd PhandalverseVault
bash bash/normalize.sh --no-edit
```

Uses auto-generated Title Case names without opening vim. Perfect for use in `all.sh` or other automated scripts.

### Important Notes

1. **Safe to Run Repeatedly**: The script only updates `map.json`, no files are renamed
2. **Run from Vault Root**: The script must be executed from the `PhandalverseVault` directory
3. **No Backup Needed**: Since no files are modified, the script is non-destructive
4. **Excluded Directories**: The script skips `.git`, `.obsidian`, `bash`, `.trash`, and `.normalize`
5. **Only `.md` Files**: Only Markdown files are tracked in the map
6. **Interactive Editing**: Customize display names for new files/directories via vim
7. **Automation-Friendly**: Use `--no-edit` flag to skip interactive editing
8. **Smart Skip**: Automatically skips execution if no `.md` files have changed in git work tree

## Integration with Laravel

The Laravel application uses `App\Helpers\VaultHelper` to read the `map.json` and display original names:

```php
// Get original display name from normalized path
$title = VaultHelper::getOriginalName('personaggi/non-giocanti/thraal.md');
// Returns: "Thraal"
```

## What Gets Modified

### Modified:
- ✅ `.normalize/map.json` (updated to reflect current filesystem state)
- ✅ `.normalize/YYYY-MM-DD_HH-MM-SS/execution.log` (new log created each run)

### NOT Modified:
- ❌ **No files are renamed** - filesystem remains unchanged
- ❌ File contents (Obsidian links remain unchanged)
- ❌ Hidden files/directories (`.git`, `.obsidian`)
- ❌ Excluded directories (`bash`, `.trash`, `.normalize`)

## Use Cases

### When to Run This Script

1. **After Adding New Files**: When you create new `.md` files in Obsidian and want them to appear in the web application
2. **After Renaming Files**: If you manually rename files on the filesystem, run this to update the map
3. **Regular Maintenance**: Run periodically to ensure `map.json` stays in sync with the filesystem

### Example Workflow

#### Manual Workflow (Interactive)
```bash
# 1. Create new file in Obsidian: "Nuova Città.md"
# 2. Manually rename it to "nuova-citta.md" (or use a separate normalization tool)
# 3. Run this script to update map.json
bash bash/normalize.sh

# 4. Vim opens showing:
#    luoghi/nuova-citta.md|Nuova Citta
# 5. Edit to:
#    luoghi/nuova-citta.md|Nuova Città
# 6. Save and close (:wq)
# 7. The map.json now contains:
#    "nuova-citta.md": "Nuova Città"
```

#### Automated Workflow (Non-Interactive)
```bash
# In your all.sh script:
bash bash/normalize.sh --no-edit
git add .normalize/map.json
git commit -m "Update map.json"
# ... rest of deployment
```

## Troubleshooting

### "jq: command not found"
```bash
sudo apt-get update && sudo apt-get install jq
```

### Map Not Updating
- Ensure you're running from the vault root directory
- Check that `.normalize/map.json` exists and is valid JSON
- Review the execution log in `.normalize/YYYY-MM-DD_HH-MM-SS/execution.log`

### New Files Not Appearing
- Ensure the file has a `.md` extension
- Check that the file is not in an excluded directory
- Verify the file is not named `README.md` or `TODO.md` (excluded by default)

## Technical Details

- **Language**: Pure Bash (no Python dependencies)
- **Dependencies**: `jq`, `git`, standard Unix utilities
- **Operation**: Read-only filesystem scan, only `map.json` is modified
- **Title Case Conversion**: Kebab-case → Title Case (e.g., `hello-world` → `Hello World`)
- **Preservation Logic**: Existing mappings in `map.json` are never overwritten
- **Git Integration**: Checks for `.md` file changes before running; skips if work tree is clean
- **Logging**: Execution logs stored in `.normalize/YYYY-MM-DD_HH-MM-SS/execution.log` (not tracked in git)

---

**Last Updated**: 2026-01-20
**Version**: 2.0
**Author**: RickyMandich
