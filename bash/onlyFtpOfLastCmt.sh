# Funzione per caricare i file su FTP a partire dal commit
function uploadFilesFromCommit() {
    # Itera sui file modificati e carica ciascuno di essi (usando while read per gestire spazi nei nomi)
    # Ignora le cartelle bash e .trash
    git diff-tree --no-commit-id --name-only -r HEAD | while IFS= read -r file; do
        # Salta righe vuote
        [ -z "$file" ] && continue

        # Ignora i file nelle cartelle bash e .trash
        if [[ "$file" == .trash/* ]] || [[ "$file" == bash/* ]]; then
            echo "Ignorato: $file"
            continue
        fi

        # Costruisci il percorso FTP per il file (aggiunge "Vault/" all'inizio del percorso)
        local relativePath=$(dirname "$file")
        local fileName=$(basename "$file")

        # URL-encode del percorso FTP (converte spazi e caratteri speciali)
        local encodedPath=$(echo "Vault/$relativePath/$fileName" | sed 's/ /%20/g' | sed "s/'/%27/g")
        local ftpRequest="ftp://Phandalverse:Minecraft35%3F@ftp.Phandalverse.altervista.org:21/$encodedPath"

        # Esegui il comando curl per caricare il file
        local curlCommand="curl -T \"$file\" \"$ftpRequest\" --ftp-pasv --ftp-create-dirs"
        echo -e "$curlCommand"

        # Esegui curl e cattura l'output e il codice di uscita
        local curlOutput
        curlOutput=$(eval "$curlCommand" 2>&1)
        local curlExitCode=$?

        # Controlla se curl ha restituito un errore
        if [ $curlExitCode -ne 0 ]; then
            # Se l'errore è "Failed to open/read local data", rimuovi il file dal server
            if [[ "$curlOutput" == *"Failed to open/read local data"* ]]; then
                echo "Errore durante il caricamento di $file. Rimozione dal server in corso..."

                # Comando per eliminare il file dal server FTP (nella cartella Vault)
                # URL-encode del percorso per il comando DELE
                local encodedDeletePath=$(echo "Vault/$relativePath/$fileName" | sed 's/ /%20/g' | sed "s/'/%27/g")
                local deleteCommand="curl -Q \"DELE $encodedDeletePath\" \"ftp://Phandalverse:Minecraft35%3F@ftp.Phandalverse.altervista.org:21/\" --ftp-pasv"
                echo -e "$deleteCommand"
                eval "$deleteCommand"

                echo "File Vault/$relativePath/$fileName rimosso dal server."
            else
                # Per altri tipi di errori, mostra l'output di curl
                echo "Errore durante il caricamento di $file:"
                echo "$curlOutput"
            fi
        else
            echo "Vault/$relativePath/$fileName caricato con successo."
        fi
    done
}

# Carica i file presenti nell'ultimo commit
uploadFilesFromCommit

sleep 1
clear
