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

The normalization script solves these problems by converting all filenames to a **safe, web-friendly format** while **preserving the original names** for display purposes.

## What It Does

### Normalization Process

The script performs a **recursive, depth-first traversal** of the vault, processing:

1. **Files**: All file types (`.md`, `.png`, `.jpg`, `.ds`, etc.)
   - Converts to lowercase
   - Replaces spaces with hyphens
   - Removes or transliterates non-ASCII characters
   - Example: `La Ruota.md` → `la-ruota.md`

2. **Directories**: All subdirectories
   - Applies the same normalization rules
   - Example: `Personaggi/Non Giocanti` → `personaggi/non-giocanti`

3. **Collision Handling**:
   - **Case-only changes**: Automatically fixed via temporary file
   - **True collisions**: Interactive prompt (Overwrite/Keep Both/Skip/Delete)
   - **Keep Both**: Appends `-1` to the filename

### Generated Artifacts

#### 1. `.normalize/map.json`
A **hierarchical tree structure** that maps normalized names back to original display names:

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
          "files": {}
        }
      }
    }
  }
}
```

**Important**: For files, the map stores the **original name WITHOUT extension** (e.g., `"La Ruota"` not `"La Ruota.md"`).

#### 2. `.normalize/YYYY-MM-DD_HH-MM-SS/execution.log`
A timestamped log of every operation:
- Files/directories renamed
- Collisions encountered and resolved
- Case fixes
- Errors and warnings

## How to Use

### Prerequisites
- **jq**: JSON processor (`sudo apt-get install jq`)
- **WSL/Bash**: Unix environment (Windows users need WSL)

### Running the Script

```bash
cd PhandalverseVault
bash bash/normalize.sh
```

### Important Notes

1. **Backup First**: Always backup your vault before running
2. **Run from Vault Root**: The script must be executed from the `PhandalverseVault` directory
3. **Interactive Mode**: Be prepared to answer prompts for collision handling
4. **One-Time Process**: Designed to be run once to normalize the entire vault
5. **Excluded Directories**: The script skips `.git`, `.obsidian`, `bash`, `.trash`, and `.normalize`

## Integration with Laravel

The Laravel application uses `App\Helpers\VaultHelper` to read the `map.json` and display original names:

```php
// Get original display name from normalized path
$title = VaultHelper::getOriginalName('personaggi/non-giocanti/thraal.md');
// Returns: "Thraal"
```

## What Gets Modified

### Modified:
- ✅ All file and directory names (normalized to kebab-case)
- ✅ File structure (directories renamed)

### NOT Modified:
- ❌ File contents (Obsidian links remain unchanged)
- ❌ Hidden files/directories (`.git`, `.obsidian`)
- ❌ Excluded directories (`bash`, `.trash`, `.normalize`)

## Troubleshooting

### "cannot move to subdirectory of itself"
- The script has built-in protection against this
- If it occurs, ensure you're using the latest version

### "jq: command not found"
```bash
sudo apt-get update && sudo apt-get install jq
```

### Collision Prompts Don't Appear
- Ensure you're running in an interactive terminal
- Use `bash -i bash/normalize.sh` if needed

## Technical Details

- **Language**: Pure Bash (no Python dependencies)
- **Dependencies**: `jq`, `iconv`, standard Unix utilities
- **Character Set**: Normalizes to `a-z0-9._-` (lowercase alphanumeric, dots, underscores, hyphens)
- **Encoding**: Input UTF-8, output ASCII (transliterated)

---

**Last Updated**: 2026-01-08  
**Version**: 1.0  
**Author**: RickyMandich
