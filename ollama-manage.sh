#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Model Manager fuer Ollama(Linux)"
APP_VERSION="0.8"

# Kleiner Helfer, um Abhaengigkeiten per PATH zu pruefen.
have() {
    command -v "$1" >/dev/null 2>&1
}

# Prüft, ob ollama installiert ist
check_installed() {
    have ollama
}


# Holt den aktuellen Status für die Menübox
get_status_string() {
    if check_installed; then
        local version
        version=$(ollama -v 2>/dev/null | grep -oP 'version is \K[0-9.]+' | head -1)
        if [ -n "$version" ]; then
            echo "Installiert (Version $version)"
        else
            echo "Installiert"
        fi
    else
        echo "Nicht installiert"
    fi
}

# Zeigt eine Fehlermeldung im passenden UI-Modus an.
show_error() {
    local message="$1"
    if [ "${OLLAMA_MANAGE_UI:-auto}" != "text" ] && have whiptail && [ -t 1 ]; then
        whiptail --title "$APP_NAME" --msgbox "$message" 10 60
    else
        echo -e "Fehler: $message" >&2
    fi
}

# Prüft, ob ollama installiert ist. Gibt 0 zurück wenn ja, sonst 1.
require_ollama() {
    if ! check_installed; then
        show_error "ollama wurde nicht gefunden.\nBitte installieren Sie ollama (Menüpunkt 6)."
        return 1
    fi

    if ! ollama list >/dev/null 2>&1; then
        show_error "Der Ollama-Daemon ist nicht erreichbar.\nBitte starten Sie den Dienst (z.B. 'ollama serve' oder Menüpunkt 8)."
        return 1
    fi
    return 0
}

# 1. Ollama Installieren oder Aktualisieren
install_ollama() {
    local ui_mode="$1"

    if [ "$ui_mode" = "whiptail" ]; then
        if ! whiptail --title "Ollama Installation" --yesno "Möchten Sie Ollama jetzt installieren oder aktualisieren?" 10 60; then
            return 0
        fi
        clear
        echo -e "\033[0;34m[*] Starte Ollama Installation/Update...\033[0;37m"
        if curl -fsSL https://ollama.com/install.sh | sh; then
            local version
            version=$(ollama -v 2>/dev/null | grep -oP 'version is \K[0-9.]+' | head -1)
            whiptail --title "Erfolg" --msgbox "Ollama wurde erfolgreich installiert!\nVersion: ${version:-unbekannt}" 10 60
        else
            whiptail --title "Fehler" --msgbox "Fehler bei der Installation von Ollama." 10 60
        fi
    else
        echo "Starte Ollama Installation/Update..."
        if curl -fsSL https://ollama.com/install.sh | sh; then
            echo "Ollama wurde erfolgreich installiert!"
            ollama -v 2>/dev/null || true
        else
            echo "Fehler bei der Installation von Ollama." >&2
        fi
    fi
}

# 2. Status des systemd-Dienstes anzeigen
status_service() {
    local ui_mode="$1"

    # Prüfen, ob der systemd-Dienst überhaupt existiert
    if ! systemctl list-unit-files ollama.service >/dev/null 2>&1; then
        if [ "$ui_mode" = "whiptail" ]; then
            whiptail --title "Fehler" --msgbox "Der systemd-Dienst 'ollama' existiert nicht.\nOllama wurde evtl. nicht über das offizielle Installationsskript installiert." 10 60
        else
            echo "Fehler: Der systemd-Dienst 'ollama' existiert nicht." >&2
            echo "Ollama wurde evtl. nicht über das offizielle Installationsskript installiert." >&2
        fi
        return 0
    fi

    # Prüfen, ob der Dienst aktiv (gestartet) ist
    if ! systemctl is-active --quiet ollama; then
        if [ "$ui_mode" = "whiptail" ]; then
            whiptail --title "Hinweis" --msgbox "Der Ollama-Dienst ist nicht gestartet.\nBitte starten Sie den Dienst (Menüpunkt 8)." 10 60
        else
            echo "Hinweis: Der Ollama-Dienst ist nicht gestartet." >&2
            echo "Bitte starten Sie den Dienst (Menüpunkt 8)." >&2
        fi
        return 0
    fi

    if [ "$ui_mode" = "whiptail" ]; then
        local tmp_file
        tmp_file=$(mktemp)
        if sudo systemctl status ollama --no-pager > "$tmp_file" 2>&1; then
            whiptail --title "Systemd Dienst-Status" --textbox "$tmp_file" 22 80
        else
            whiptail --title "Fehler" --msgbox "Fehler beim Abrufen des Dienst-Status.\n\n$(cat "$tmp_file")" 15 70
        fi
        rm -f "$tmp_file"
    else
        echo "=== Systemd Dienst-Status ==="
        if ! sudo systemctl status ollama --no-pager; then
            echo "Fehler beim Abrufen des Dienst-Status." >&2
        fi
    fi
}

# 3. Dienst starten
start_service() {
    local ui_mode="$1"

    if [ "$ui_mode" = "whiptail" ]; then
        clear
        if sudo systemctl start ollama; then
            whiptail --title "Dienst gestartet" --msgbox "Der Ollama-Hintergrunddienst wurde gestartet." 10 60
        else
            whiptail --title "Fehler" --msgbox "Fehler beim Starten des Ollama-Dienstes." 10 60
        fi
    else
        echo "Starte Ollama-Dienst..."
        if sudo systemctl start ollama; then
            echo "Der Ollama-Hintergrunddienst wurde gestartet."
        else
            echo "Fehler beim Starten des Ollama-Dienstes." >&2
        fi
    fi
}

# 4. Dienst stoppen
stop_service() {
    local ui_mode="$1"

    if [ "$ui_mode" = "whiptail" ]; then
        clear
        if sudo systemctl stop ollama; then
            whiptail --title "Dienst gestoppt" --msgbox "Der Ollama-Hintergrunddienst wurde angehalten." 10 60
        else
            whiptail --title "Fehler" --msgbox "Fehler beim Stoppen des Ollama-Dienstes." 10 60
        fi
    else
        echo "Stoppe Ollama-Dienst..."
        if sudo systemctl stop ollama; then
            echo "Der Ollama-Hintergrunddienst wurde angehalten."
        else
            echo "Fehler beim Stoppen des Ollama-Dienstes." >&2
        fi
    fi
}

# Zeigt die Modelle formatiert in einer Whiptail-Nachrichtenbox an.
show_list_whiptail() {
    require_ollama || return 1
    local list
    list=$(ollama list)
    whiptail --title "Installierte Modelle" --msgbox "$list" 20 78
}

# Text-Fallback für die Modellliste.
show_list_text() {
    require_ollama || return 1
    echo "=== Installierte Modelle ==="
    ollama list
    echo
}

# Gibt nur Modellnamen aus.
list_models() {
    ollama list 2>/dev/null | awk 'NR>1 && $1 != "" { print $1 }'
}

# Waehlt ein Modell ueber fzf, whiptail-Menü oder eine einfache Texteingabe.
pick_model() {
    local prompt="${1:-Modell waehlen}"
    local ui_mode="${2:-auto}"
    local model

    # 1. Whiptail Modus (Priorität wenn verlangt)
    if [ "$ui_mode" = "whiptail" ] && [ -t 1 ]; then
        local options=()
        while IFS= read -r line; do
            [ -n "$line" ] || continue
            options+=("$line" "")
        done < <(list_models)

        if [ "${#options[@]}" -eq 0 ]; then
            whiptail --title "$APP_NAME" --msgbox "Keine Modelle lokal installiert." 10 50
            return 1
        fi

        model="$(whiptail --title "$APP_NAME" --menu "$prompt" 20 78 10 "${options[@]}" 3>&1 1>&2 2>&3)" || return 1

    # 2. FZF Modus (Fallback für Text-Modus)
    elif have fzf && [ -t 1 ] && [ "$ui_mode" != "text" ]; then
        model="$(list_models | fzf --prompt="${prompt}: " --height=10 --border)" || return 1

    # 3. Reines Text-Fallback
    else
        local model_map=()
        while IFS= read -r line; do
            [ -n "$line" ] || continue
            model_map+=("$line")
        done < <(list_models)

        if [ "${#model_map[@]}" -eq 0 ]; then
            echo "Keine Modelle lokal installiert." >&2
            return 1
        fi

        echo "Verfuegbare Modelle:" >&2
        for i in "${!model_map[@]}"; do
            printf '%d) %s\n' "$((i+1))" "${model_map[$i]}" >&2
        done
        printf "%s (Nummer eingeben): " "$prompt" >&2
        read -r choice

        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#model_map[@]}" ]; then
            model="${model_map[$((choice-1))]}"
        else
            model="$choice"
        fi
    fi
    [ -n "${model:-}" ] || return 1
    printf '%s\n' "$model"
}

# Installiert ein Modell. Im Whiptail-Modus MIT animierter Fortschrittsanzeige!
pull_model() {
    local ui_mode="$1"
    local model=""

    require_ollama || return 1

    if [ "$ui_mode" = "whiptail" ]; then
        model=$(whiptail --title "Modell installieren" --inputbox "Bitte den genauen Modellnamen eingeben (z. B. llama3.2:1b):" 10 60 3>&1 1>&2 2>&3) || return 0
    else
        printf "Modellname: "
        read -r model
    fi

    if [ -z "$model" ]; then
        return
    fi

    if [[ ! "$model" =~ ^[a-zA-Z0-9_@:.-]+$ ]]; then
        if [ "$ui_mode" = "whiptail" ]; then
            whiptail --title "Fehler" --msgbox "Ungültiger Modellname!\nNur Buchstaben, Zahlen und . - _ : @ sind erlaubt." 10 60
        else
            echo "Fehler: Ungültiger Modellname."
        fi
        return 1
    fi

    # Prüfen, ob Modell bereits installiert
    if ollama list 2>/dev/null | awk -v m="$model" '$1 == m {found=1} END {exit !found}'; then
        if [ "$ui_mode" = "whiptail" ]; then
            whiptail --title "Hinweis" --msgbox "$model ist bereits installiert." 10 50
        else
            echo "Hinweis: $model ist bereits installiert."
        fi
        return 0
    fi

    if [ "$ui_mode" = "whiptail" ]; then
        # Extrahiert den Prozentwert aus dem Ollama-Download-Stream und füttert whiptail --gauge
        (
            ollama pull "$model" 2>&1 | stdbuf -oL tr '\r' '\n' | awk '
            /downloading/ {
                for(i=1; i<=NF; i++) {
                    if($i ~ /%/) {
                        gsub(/%/, "", $i)
                        print int($i)
                        fflush()
                    }
                }
            }'
        ) | whiptail --title "Download: $model" --gauge "Bereite Download vor..." 10 60 0

        whiptail --title "Erfolg" --msgbox "Modell $model wurde erfolgreich installiert." 10 50
    else
        echo "Installiere: $model"
        ollama pull -- "$model"
    fi
}

# Löscht ein Modell über ein exklusives Whiptail-Auswahlmenü mit Sicherheitsabfrage.
remove_model() {
    local ui_mode="$1"
    local model=""

    require_ollama || return 1

    if [ "$ui_mode" = "whiptail" ] && [ -t 1 ]; then
        local options=()

        # Erstellt die Menüstruktur direkt aus der installierten Modellliste
        while IFS= read -r line; do
            [ -n "$line" ] || continue
            options+=("$line" "") # Modellname und leere Beschreibung für Whiptail
        done < <(list_models)

        # Fehler abfangen, falls gar keine Modelle installiert sind
        if [ "${#options[@]}" -eq 0 ]; then
            whiptail --title "$APP_NAME" --msgbox "Keine Modelle lokal installiert." 10 55
            return 1
        fi

        # Das dedizierte Whiptail-Auswahlmenü für den Löschvorgang
        model="$(whiptail --title "Modell löschen" \
                          --menu "Wähle das Modell aus, das unwiderruflich gelöscht werden soll:" \
                          20 78 10 "${options[@]}" 3>&1 1>&2 2>&3)" || return 0

        if [ -n "$model" ]; then
            # Grafische Sicherheitsabfrage (Standardmäßig steht der Fokus auf "Nein")
            if whiptail --title "⚠️ WARNUNG ⚠️" \
                        --defaultno \
                        --yesno "Möchten Sie das Modell '$model' wirklich unwiderruflich von der Festplatte löschen?" \
                        10 65; then

                # Modell löschen
                ollama rm "$model"

                # Erfolgsmeldung anzeigen
                whiptail --title "Erfolg" --msgbox "Das Modell '$model' wurde erfolgreich gelöscht." 10 55
            else
                # Wenn der Nutzer "Nein" wählt oder abbricht
                whiptail --title "Abgebrochen" --msgbox "Löschvorgang für '$model' wurde abgebrochen." 10 55
            fi
        fi
    else
        # Text-Fallback, falls whiptail nicht aktiv ist
        printf "Name des zu löschenden Modells eingeben: "
        read -r model
        if [ -n "$model" ]; then
            echo "Loesche: $model"
            ollama rm "$model"
        fi
    fi
}


# Startet ein Modell und nutzt dafür eine exklusive Whiptail-Modellliste.
run_model() {
    local ui_mode="$1"
    local model=""

    require_ollama || return 1

    if [ "$ui_mode" = "whiptail" ] && [ -t 1 ]; then
        local options=()

        # Erstellt die Menüstruktur direkt aus der installierten Modellliste
        while IFS= read -r line; do
            [ -n "$line" ] || continue
            options+=("$line" "") # Modellname und leere Beschreibung für Whiptail
        done < <(list_models)

        # Fehler abfangen, falls gar keine Modelle installiert sind
        if [ "${#options[@]}" -eq 0 ]; then
            whiptail --title "$APP_NAME" --msgbox "Keine Modelle lokal installiert.\nBitte zuerst ein Modell herunterladen." 10 55
            return 1
        fi

        # Das dedizierte Whiptail-Auswahlmenü für den Startvorgang
        model="$(whiptail --title "Modell starten" \
                          --menu "Wähle das Modell für die Chat-Sitzung aus:" \
                          20 78 10 "${options[@]}" 3>&1 1>&2 2>&3)" || return 0

        if [ -n "$model" ]; then
            # Infobox anzeigen, während das Modell in den VRAM/RAM geladen wird
            whiptail --title "Ollama" --infobox "Modell '$model' wird geladen...\nDas Chat-Terminal öffnet sich in Kürze." 10 60
            sleep 1.5

            # Öffnet das interaktive Chat-Terminal
            ollama run -- "$model"

            # Quittiert das saubere Beenden des Chats
            whiptail --title "Beendet" --msgbox "Die Chat-Sitzung mit '$model' wurde geschlossen." 10 55
        fi
    else
        # Text-Fallback, falls whiptail nicht aktiv ist
        printf "Modellname eingeben: "
        read -r model
        if [ -n "$model" ]; then
            echo "Starte: $model"
            ollama run -- "$model"
        fi
    fi
}


# Stoppt ein laufendes Modell und nutzt dafür die Echtzeitdaten aus 'ollama ps'.
stop_model() {
    local ui_mode="$1"
    local model=""

    require_ollama || return 1

    if [ "$ui_mode" = "whiptail" ] && [ -t 1 ]; then
        local options=()

        # Liest Name, Größe und VRAM-Aufteilung direkt aus 'ollama ps'
        # Überspringt die Kopfzeile und leere Zeilen
        while IFS= read -r line; do
            [ -n "$line" ] || continue

            # Extrahiert den Modellnamen (Spalte 1)
            local name
            name=$(echo "$line" | awk '{print $1}')

            # Extrahiert die Größe und GPU-Verteilung (Spalten 3 und 4)
            local details
            details=$(echo "$line" | awk '{print "Größe: " $3 ", GPU: " $4}')

            options+=("$name" "$details")
        done < <(ollama ps 2>/dev/null | awk 'NR>1')

        # Falls aktuell überhaupt kein Modell im Speicher geladen ist
        if [ "${#options[@]}" -eq 0 ]; then
            whiptail --title "Speicher leeren" \
                     --msgbox "Aktuell sind keine Modelle laut 'ollama ps' geladen.\nEs gibt nichts zu stoppen." \
                     10 60
            return 0
        fi

        # Das maßgeschneiderte Whiptail-Auswahlmenü mit Live-Speicherdaten
        model="$(whiptail --title "Modell stoppen (RAM/VRAM leeren)" \
                          --menu "Wähle das Modell aus, das entladen werden soll:" \
                          20 78 10 "${options[@]}" 3>&1 1>&2 2>&3)" || return 0

        if [ -n "$model" ]; then
            whiptail --title "Ollama" --infobox "Entlade '$model' aus dem Speicher..." 10 50

            # API-Call zum Stoppen absetzen und HTTP-Statuscode prüfen
            local response
            response=$(curl -s -w "%{http_code}" -X POST http://localhost:11434/api/generate \
                -H "Content-Type: application/json" \
                -d "{\"model\": \"$model\", \"keep_alive\": 0}" -o /dev/null)

            if [ "$response" = "200" ]; then
                whiptail --title "Erfolg" --msgbox "Das Modell '$model' wurde erfolgreich aus dem RAM/VRAM entladen." 10 65
            else
                whiptail --title "Fehler" --msgbox "API-Fehler beim Stoppen des Modells.\nHTTP-Statuscode: $response" 10 60
            fi
        fi
    else
        # Text-Fallback, falls whiptail nicht aktiv ist
        echo "=== Laufende Modelle (ollama ps) ==="
        ollama ps
        echo
        printf "Name des zu stoppenden Modells eingeben: "
        read -r model
        if [ -n "$model" ]; then
            echo "Stoppe: $model"
            curl -s -X POST http://localhost:11434/api/generate \
                -H "Content-Type: application/json" \
                -d "{\"model\": \"$model\", \"keep_alive\": 0}" >/dev/null
        fi
    fi
}



# Textbasiertes Fallback-Menue.
text_menu() {
    while true; do
        echo "=== $APP_NAME v$APP_VERSION ==="
        echo "Status: $(get_status_string)"
        echo
        echo "1) Modelle auflisten"
        echo "2) Modell installieren"
        echo "3) Modell loeschen"
        echo "4) Modell starten"
        echo "5) Modell stoppen"
        echo "6) Ollama installieren/aktualisieren"
        echo "7) Dienst-Status anzeigen"
        echo "8) Dienst starten"
        echo "9) Dienst stoppen"
        echo "10) Beenden"
        printf "Auswahl: "
        read -r choice
        case "$choice" in
            1) require_ollama && show_list_text || true ;;
            2) require_ollama && pull_model "text" || true ;;
            3) require_ollama && remove_model "text" || true ;;
            4) require_ollama && run_model "text" || true ;;
            5) require_ollama && stop_model "text" || true ;;
            6) install_ollama "text" || true ;;
            7) status_service "text" || true ;;
            8) start_service "text" || true ;;
            9) stop_service "text" || true ;;
            10|q|Q) exit 0 ;;
            *) echo "Ungueltige Auswahl." ;;
        esac
        echo
    done
}

# Vollständig geschlossenes Whiptail-Hauptmenü.
whiptail_menu() {
    local menu_items=(
        "1" "Modelle auflisten"
        "2" "Modell installieren"
        "3" "Modell loeschen"
        "4" "Modell starten"
        "5" "Modell stoppen"
        "6" "Ollama installieren/aktualisieren"
        "7" "Dienst-Status anzeigen"
        "8" "Dienst starten"
        "9" "Dienst stoppen"
        "10" "Beenden"
    )
    while true; do
        local choice
        choice="$(whiptail --title "$APP_NAME v$APP_VERSION" --menu "Hauptmenü\nStatus: Ollama $(get_status_string)" 22 78 12 "${menu_items[@]}" 3>&1 1>&2 2>&3)" || exit 0

        case "$choice" in
            1) require_ollama && show_list_whiptail || true ;;
            2) require_ollama && pull_model "whiptail" || true ;;
            3) require_ollama && remove_model "whiptail" || true ;;
            4) require_ollama && run_model "whiptail" || true ;; # Springt für den Chat kurz ins Terminal
            5) require_ollama && stop_model "whiptail" || true ;;
            6) install_ollama "whiptail" || true ;;
            7) status_service "whiptail" || true ;;
            8) start_service "whiptail" || true ;;
            9) stop_service "whiptail" || true ;;
            10) exit 0 ;;
        esac
    done
}

main() {
    case "${OLLAMA_MANAGE_UI:-auto}" in
        text)     text_menu ;;
        whiptail)
            if have whiptail && [ -t 1 ]; then
                whiptail_menu
            else
                text_menu
            fi
            ;;
        auto|*)
            if have whiptail && [ -t 1 ]; then
                whiptail_menu
            else
                text_menu
            fi
            ;;
    esac
}

main "$@"