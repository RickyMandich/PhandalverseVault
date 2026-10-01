# Itera sui file e carica ciascuno di essi (usando while read per gestire spazi nei nomi)
# Ignora le cartelle .git, bash e .trash
find . -type f -not -path './.git/*' -not -path './.trash/*' -not -path './bash/*' | while IFS= read -r file; do
    # Salta righe vuote
    [ -z "$file" ] && continue

    # Costruisci il percorso FTP per il file (aggiunge "Vault/" all'inizio del percorso)
    relativePath=$(dirname "$file" | sed 's/^\.\///')
    fileName=$(basename "$file")

    # URL-encode del percorso FTP (converte spazi e caratteri speciali)
    encodedPath=$(echo "Vault/$relativePath/$fileName" | sed 's/ /%20/g' | sed "s/'/%27/g")
    ftpRequest="ftp://phandalverse:Minecraft35%3F@ftp.phandalverse.altervista.org:21/$encodedPath"

    # Esegui il comando curl per caricare il file
    curlCommand="curl -T \"$file\" \"$ftpRequest\" --ftp-pasv --ftp-create-dirs"
    echo -e "$curlCommand"
    eval "$curlCommand"
    echo "Vault/$relativePath/$fileName caricato con successo."
done