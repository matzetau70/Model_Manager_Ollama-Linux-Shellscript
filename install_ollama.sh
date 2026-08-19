install_ollama() {
    # Lokale Farbvariablen für Terminal-Ausgaben
    local BLUE='\033[0;34m'
    local GREEN='\033[0;32m'
    local RED='\033[0;31m'
    local NC='\033[0m'

    # 1. Prüfen und Installieren von Whiptail, falls nicht vorhanden
    if ! command -v whiptail &> /dev/null; then
        echo -e "${BLUE}[*] Whiptail wird benötigt, aber nicht gefunden. Installiere...${NC}"
        if command -v apt-get &> /dev/null; then
            sudo apt-get update && sudo apt-get install -y whiptail
        elif command -v dnf &> /dev/null; then
            sudo dnf install -y newt
        else
            echo -e "${RED}[-] Paketmanager nicht unterstützt. Bitte whiptail manuell installieren.${NC}"
            return 1
        fi
    fi

    # 2. Infobox über den Start anzeigen
    whiptail --title "Ollama Installation" --infobox "Starte Ollama Installation/Update...\nBitte warten..." 8 45
    sleep 2

    # 3. Installation ausführen
    echo -e "${BLUE}[*] Starte Ollama Installation/Update...${NC}"
    if curl -fsSL https://ollama.com | sh; then
        # Erfolgsmeldung via Whiptail
        whiptail --title "Erfolg" --msgbox "Ollama wurde erfolgreich installiert!" 8 45

        # Pfad-Validierung
        if command -v ollama &> /dev/null; then
            ollama -v
        else
            echo -e "${BLUE}[*] Hinweis: Starte das Terminal neu oder führe 'source ~/.bashrc' aus.${NC}"
        fi
    else
        # Fehlermeldung via Whiptail
        whiptail --title "Fehler" --msgbox "Fehler bei der Installation von Ollama." 8 45
        return 1
    fi
}
install_ollama()


