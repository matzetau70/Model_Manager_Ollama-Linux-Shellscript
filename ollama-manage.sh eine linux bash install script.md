#!/bin/bash

# Farben für eine bessere Lesbarkeit im Terminal
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0;37m' # Keine Farbe (Standard)

# Funktion zur Überprüfung, ob Ollama installiert ist
check_installed() {
    if command -v ollama &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# 1. Ollama Installieren oder Aktualisieren
install_ollama() {
    echo -e "${BLUE}[*] Starte Ollama Installation/Update...${NC}"
    # Nutzt das offizielle Installationsskript von Ollama
    curl -fsSL https://ollama.com/install.sh | sh

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}[+] Ollama wurde erfolgreich installiert!${NC}"
        ollama -v
    else
        echo -e "${RED} [-] Fehler bei der Installation von Ollama.${NC}"
    fi
}

# 2. Status des systemd-Dienstes anzeigen
status_service() {
    echo -e "${BLUE}[*] Status des Ollama-Dienstes:${NC}"
    sudo systemctl status ollama --no-pager
}

# 3. Dienst starten
start_service() {
    echo -e "${BLUE}[*] Starte Ollama-Dienst...${NC}"
    sudo systemctl start ollama
    echo -e "${GREEN}[+] Dienst gestartet.${NC}"
}

# 4. Dienst stoppen
stop_service() {
    echo -e "${BLUE}[*] Stoppe Ollama-Dienst...${NC}"
    sudo systemctl stop ollama
    echo -e "${YELLOW}[!] Dienst gestoppt.${NC}"
}

# 5. Lokale Modelle auflisten
list_models() {
    if ! check_installed; then
        echo -e "${RED}[-] Ollama ist nicht installiert.${NC}"
        return
    fi
    echo -e "${BLUE}[*] Installierte KI-Modelle:${NC}"
    ollama list
}

# 6. Ein neues Modell herunterladen (Pull)
pull_model() {
    if ! check_installed; then
        echo -e "${RED}[-] Ollama ist nicht installiert.${NC}"
        return
    fi
    echo -e "${YELLOW}Geben Sie den Namen des Modells ein (z. B. llama3, mistral, phi3):${NC}"
    read -r model_name
    if [ -z "$model_name" ]; then
        echo -e "${RED}[-] Ungültiger Name.${NC}"
        return
    fi
    echo -e "${BLUE}[*] Lade Modell '$model_name' herunter...${NC}"
    ollama pull "$model_name"
}

# 7. Ein Modell löschen (Remove)
remove_model() {
    if ! check_installed; then
        echo -e "${RED}[-] Ollama ist nicht installiert.${NC}"
        return
    fi
    echo -e "${YELLOW}Geben Sie den Namen des zu löschenden Modells ein:${NC}"
    read -r model_name
    if [ -z "$model_name" ]; then
        echo -e "${RED}[-] Ungültiger Name.${NC}"
        return
    fi
    echo -e "${BLUE}[*] Lösche Modell '$model_name'...${NC}"
    ollama rm "$model_name"
    echo -e "${GREEN}[+] Modell gelöscht.${NC}"
}

# Interaktives Hauptmenü
show_menu() {
    clear
    echo -e "${BLUE}=======================================${NC}"
    echo -e "${GREEN}      Ollama Management Skript         ${NC}"
    echo -e "${BLUE}=======================================${NC}"

    if check_installed; then
        echo -e "Status: ${GREEN}Installiert (${NC}$(ollama -v 2>/dev/null)${GREEN})${NC}"
    else
        echo -e "Status: ${RED}Nicht installiert${NC}"
    fi
    echo -e "${BLUE}---------------------------------------${NC}"
    echo -e "1) Ollama Installieren / Aktualisieren"
    echo -e "2) Status des Hintergrunddienstes prüfen"
    echo -e "3) Ollama-Dienst STARTEN"
    echo -e "4) Ollama-Dienst STOPPEN"
    echo -e "5) Installierte Modelle anzeigen"
    echo -e "6) Neues Modell herunterladen (Pull)"
    echo -e "7) Modell löschen (Remove)"
    echo -e "8) Beenden"
    echo -e "${BLUE}---------------------------------------${NC}"
    echo -ne "Wählen Sie eine Option [1-8]: "
}

# Hauptschleife
while true; do
    show_menu
    read -r choice
    case $choice in
        1) install_ollama ;;
        2) status_service ;;
        3) start_service ;;
        4) stop_service ;;
        5) list_models ;;
        6) pull_model ;;
        7) remove_model ;;
        8) echo -e "${GREEN}Auf Wiedersehen!${NC}"; exit 0 ;;
        *) echo -e "${RED}Ungültige Option. Bitte drücken Sie Enter...${NC}" ;;
    esac
    echo -e "\n${YELLOW}Drücken Sie [Enter], um zum Menü zurückzukehren...${NC}"
    read -r
done
