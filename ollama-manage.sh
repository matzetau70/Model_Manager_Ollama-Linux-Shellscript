#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Model Manager fuer Ollama(Linux)"

# Kleiner Helfer, um Abhaengigkeiten per PATH zu pruefen.
have() {
    command -v "$1" >/dev/null 2>&1
}

# Bricht sauber ab, wenn ollama nicht installiert oder nicht erreichbar ist.
require_ollama() {
    if ! have ollama; then
        if [ "${OLLAMA_MANAGE_UI:-auto}" != "text" ] && have whiptail && [ -t 1 ]; then
            whiptail --title "$APP_NAME" --msgbox "Fehler: ollama wurde nicht gefunden.\nBitte installieren Sie ollama." 10 60
        else
            echo "Fehler: ollama wurde nicht gefunden."
        fi
        exit 1
    fi

    if ! ollama list >/dev/null 2>&1; then
        if [ "${OLLAMA_MANAGE_UI:-auto}" != "text" ] && have whiptail && [ -t 1 ]; then
            whiptail --title "$APP_NAME" --msgbox "Fehler: Der Ollama-Daemon ist nicht erreichbar.\nBitte starten Sie den Dienst (z.B. 'ollama serve')." 10 60
        else
            echo "Fehler: Der Ollama-Daemon ist nicht erreichbar."
        fi
        exit 1
    fi
}

# Zeigt die Modelle formatiert in einer Whiptail-Nachrichtenbox an.
show_list_whiptail() {
    local list
    list=$(ollama list)
    whiptail --title "Installierte Modelle" --msgbox "$list" 20 78
}

# Text-Fallback für die Modellliste.
show_list_text() {
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
        echo "=== $APP_NAME ==="
        echo "1) Modelle auflisten"
        echo "2) Modell installieren"
        echo "3) Modell loeschen"
        echo "4) Modell starten"
        echo "5) Modell stoppen"
        echo "6) Beenden"
        printf "Auswahl: "
        read -r choice
        case "$choice" in
            1) show_list_text ;;
            2) pull_model "text" ;;
            3) remove_model "text" ;;
            4) run_model "text" ;;
            5) stop_model "text" ;;
            6|q|Q) exit 0 ;;
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
        "6" "Beenden"
    )
    while true; do
        local choice
        choice="$(whiptail --title "$APP_NAME" --menu "Hauptmenü" 20 78 10 "${menu_items[@]}" 3>&1 1>&2 2>&3)" || exit 0

        case "$choice" in
            1) show_list_whiptail ;;
            2) pull_model "whiptail" ;;
            3) remove_model "whiptail" ;;
            4) run_model "whiptail" ;; # Springt für den Chat kurz ins Terminal
            5) stop_model "whiptail" ;;
            6) exit 0 ;;
        esac
    done
}

main() {
    require_ollama
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
