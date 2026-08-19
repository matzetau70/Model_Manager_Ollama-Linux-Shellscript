#!/bin/bash

# Funktion zur Überprüfung, ob Ollama installiert ist
check_installed() {
    if command -v ollama &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# Holt den aktuellen Status übersichtlich für die Menübox
get_status_string() {
    if check_installed; then
        echo "Installiert ($(ollama -v 2>/dev/null))"
    else
        echo "Nicht installiert"
    fi
}

# 1. Ollama Installieren oder Aktualisieren
install_ollama() {
    if whiptail --title "Ollama Installation" --yesno "Möchten Sie Ollama jetzt installieren oder aktualisieren?" 10 60; then
        clear
        echo -e "\033[0;34m[*] Starte Ollama Installation/Update...\033[0;37m"
        curl -fsSL https://ollama.com | sh

        if [ $? -eq 0 ]; then
            VERSION=$(ollama -v 2>/dev/null)
            whiptail --title "Erfolg" --msgbox "Ollama wurde erfolgreich installiert!\nVersion: $VERSION" 10 60
        else
            whiptail --title "Fehler" --msgbox "Fehler bei der Installation von Ollama." 10 60
        fi
    fi
}

# 2. Status des systemd-Dienstes anzeigen
status_service() {
    # Schreibt den Status temporär in eine Datei, um ihn lesbar im Fenster anzuzeigen
    TMP_FILE=$(mktemp)
    sudo systemctl status ollama --no-pager > "$TMP_FILE" 2>&1
    whiptail --title "Systemd Dienst-Status" --textbox "$TMP_FILE" 22 80
    rm -f "$TMP_FILE"
}

# 3. Dienst starten
start_service() {
    clear
    sudo systemctl start ollama
    whiptail --title "Dienst gestartet" --msgbox "Der Ollama-Hintergrunddienst wurde gestartet." 10 60
}

# 4. Dienst stoppen
stop_service() {
    clear
    sudo systemctl stop ollama
    whiptail --title "Dienst gestoppt" --msgbox "Der Ollama-Hintergrunddienst wurde angehalten." 10 60
}

# 5. Lokale Modelle auflisten
list_models() {
    if ! check_installed; then
        whiptail --title "Fehler" --msgbox "Ollama ist nicht installiert." 10 60
        return
    fi
    TMP_FILE=$(mktemp)
    ollama list > "$TMP_FILE" 2>&1
    whiptail --title "Installierte KI-Modelle" --textbox "$TMP_FILE" 20 75
    rm -f "$TMP_FILE"
}

# 6. Ein neues Modell herunterladen (Pull)
pull_model() {
    if ! check_installed; then
        whiptail --title "Fehler" --msgbox "Ollama ist nicht installiert." 10 60
        return
    fi

    MODEL_NAME=$(whiptail --title "Modell herunterladen" --inputbox "Geben Sie den Namen des Modells ein (z. B. llama3, mistral, phi3):" 10 60 3>&1 1>&2 2>&3)

    if [ $? -ne 0 ] || [ -z "$MODEL_NAME" ]; then
        return
    fi

    # Da ein Download einen Fortschrittsbalken im Terminal zeigt, wechseln wir kurz in den Standard-Output
    clear
    echo -e "\033[0;34m[*] Lade Modell '$MODEL_NAME' herunter...\033[0;37m"
    ollama pull "$MODEL_NAME"

    if [ $? -eq 0 ]; then
        whiptail --title "Erfolg" --msgbox "Modell '$MODEL_NAME' erfolgreich heruntergeladen!" 10 60
    else
        whiptail --title "Fehler" --msgbox "Fehler beim Herunterladen von '$MODEL_NAME'." 10 60
    fi
}

# 7. Ein Modell löschen (Remove)
remove_model() {
    if ! check_installed; then
        whiptail --title "Fehler" --msgbox "Ollama ist nicht installiert." 10 60
        return
    fi

    MODEL_NAME=$(whiptail --title "Modell löschen" --inputbox "Geben Sie den exakten Namen des zu löschenden Modells ein:" 10 60 3>&1 1>&2 2>&3)

    if [ $? -ne 0 ] || [ -z "$MODEL_NAME" ]; then
        return
    fi

    if whiptail --title "Bestätigung" --yesno "Sind Sie sicher, dass Sie das Modell '$MODEL_NAME' unwiderruflich löschen wollen?" 10 60; then
        clear
        ollama rm "$MODEL_NAME" 2>/dev/null
        whiptail --title "Gelöscht" --msgbox "Das Modell '$MODEL_NAME' wurde entfernt." 10 60
    fi
}

# Hauptschleife mit Whiptail-Menü
while true; do
    STATUS=$(get_status_string)

    CHOICE=$(whiptail --title "Ollama Management Panel" \
        --menu "Ollama Status: $STATUS\n\nWählen Sie eine Verwaltungsoption aus:" 22 75 9 \
        "1" "Ollama Installieren / Aktualisieren" \
        "2" "Status des Hintergrunddienstes prüfen" \
        "3" "Ollama-Dienst STARTEN" \
        "4" "Ollama-Dienst STOPPEN" \
        "5" "Installierte Modelle anzeigen" \
        "6" "Neues Modell herunterladen (Pull)" \
        "7" "Modell löschen (Remove)" \
        "8" "Beenden" \
        3>&1 1>&2 2>&3)

    # Wenn der Benutzer "Cancel" oder ESC drückt, wird das Skript ordentlich beendet
    if [ $? -ne 0 ]; then
        CHOICE="8"
    fi

    case $CHOICE in
        1) install_ollama ;;
        2) status_service ;;
        3) start_service ;;
        4) stop_service ;;
        5) list_models ;;
        6) pull_model ;;
        7) remove_model ;;
        8)
            clear
            echo "Auf Wiedersehen!"
            exit 0
            ;;
    esac
done
```

### Was wurde geändert?
* **Dynamische Statuszeile:** Der aktuelle Status ("Installiert + Version" oder "Nicht installiert") wird nun direkt im Kopfbereich der grafischen Menübox eingebunden.
* **Keine störenden Terminal-Wartezeiten:** Nervige Aufforderungen wie `"Drücken Sie Enter, um fortzufahren"` fallen weg. Ein Klick auf `[OK]` im Dialog reicht.
* **Scrollbare Textboxen:** Bei `ollama list` und `systemctl status` öffnet sich ein voll scrollbares Textfenster. Das verhindert, dass lange Terminalausgaben unleserlich abgeschnitten werden.
* **Sicherheitsabfrage:** Vor dem Löschen eines Modells fragt eine interaktive Ja/Nein-Box nach der Bestätigung.

Möchten Sie, dass wir für das Herunterladen von Modellen noch eine **Fortschrittsanzeige via Whiptail-Gauge** einbauen oder eine **Direkt-Start-Option** für Modelle hinzufügen?
