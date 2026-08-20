#!/usr/bin/env bash
# =============================================================================
# Testskript für ollama-manage.sh
# Testet alle Menüpunkte, Fehlerfälle und UI-Modi vollständig.
# =============================================================================
set -uo pipefail

# --- Konfiguration -----------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANAGE_SCRIPT="$SCRIPT_DIR/../ollama-manage.sh"
FAKEBIN_DIR="$SCRIPT_DIR/fakebin"

PASS=0
FAIL=0
FAILED_TESTS=()

# --- Hilfsfunktionen ---------------------------------------------------------
print_header() {
    echo ""
    echo "============================================================"
    echo "  $1"
    echo "============================================================"
}

print_result() {
    local test_name="$1"
    local status="$2"
    if [ "$status" = "PASS" ]; then
        PASS=$((PASS + 1))
        echo "  [PASS] $test_name"
    else
        FAIL=$((FAIL + 1))
        FAILED_TESTS+=("$test_name")
        echo "  [FAIL] $test_name"
    fi
}

# Führt das Skript mit simulierten Eingaben aus und prüft Exit-Code
run_with_input() {
    local input="$1"
    local expected_exit="$2"
    local ui_mode="$3"
    local output
    local exit_code

    output=$(printf "%s" "$input" | OLLAMA_MANAGE_UI="$ui_mode" bash "$MANAGE_SCRIPT" 2>&1)
    exit_code=$?
    echo "$output"
    return $exit_code
}

# Prüft, ob eine Ausgabe einen bestimmten Text enthält
assert_contains() {
    local output="$1"
    local expected="$2"
    if echo "$output" | grep -qF "$expected"; then
        return 0
    else
        return 1
    fi
}

# --- Vorbereitung ------------------------------------------------------------
print_header "Vorbereitung"

# Prüfen, ob das Hauptskript existiert
if [ ! -f "$MANAGE_SCRIPT" ]; then
    echo "FEHLER: $MANAGE_SCRIPT nicht gefunden!"
    exit 1
fi
echo "  Hauptskript gefunden: $MANAGE_SCRIPT"

# Fake-whiptail erstellen (simuliert whiptail für Tests)
mkdir -p "$FAKEBIN_DIR"
cat > "$FAKEBIN_DIR/whiptail" << 'FAKEWH'
#!/usr/bin/env bash
# Fake-whiptail: Simuliert whiptail für Tests.
# Gibt je nach Aufruf unterschiedliche Werte zurück.
# --menu: gibt "1" zurück (erste Option)
# --msgbox/--infobox/--textbox: gibt 0 zurück
# --yesno: gibt 0 zurück (Ja)
# --inputbox: gibt "testmodell" zurück
# --gauge: gibt 0 zurück
case "$1" in
    --menu)
        echo "1"
        exit 0
        ;;
    --yesno)
        exit 0
        ;;
    --inputbox)
        echo "testmodell"
        exit 0
        ;;
    --gauge)
        exit 0
        ;;
    --msgbox|--infobox|--textbox)
        exit 0
        ;;
    *)
        exit 0
        ;;
esac
FAKEWH
chmod +x "$FAKEBIN_DIR/whiptail"
echo "  Fake-whiptail erstellt: $FAKEBIN_DIR/whiptail"

# --- Test 1: Syntaxprüfung ---------------------------------------------------
print_header "Test 1: Syntaxprüfung"
if bash -n "$MANAGE_SCRIPT" 2>/dev/null; then
    print_result "Syntaxprüfung (bash -n)" "PASS"
else
    print_result "Syntaxprüfung (bash -n)" "FAIL"
fi

# --- Test 2: Text-Modus - Menü wird angezeigt --------------------------------
print_header "Test 2: Text-Modus - Menü wird angezeigt"
output=$(printf "10\n" | OLLAMA_MANAGE_UI=text bash "$MANAGE_SCRIPT" 2>&1)
exit_code=$?

if [ $exit_code -eq 0 ]; then
    print_result "Exit-Code 0 bei Beenden" "PASS"
else
    print_result "Exit-Code 0 bei Beenden (war $exit_code)" "FAIL"
fi

if assert_contains "$output" "=== Model Manager fuer Ollama(Linux) v0.8 ==="; then
    print_result "Versionsanzeige v0.8" "PASS"
else
    print_result "Versionsanzeige v0.8" "FAIL"
fi

if assert_contains "$output" "1) Modelle auflisten"; then
    print_result "Menüpunkt 1 vorhanden" "PASS"
else
    print_result "Menüpunkt 1 vorhanden" "FAIL"
fi

if assert_contains "$output" "10) Beenden"; then
    print_result "Menüpunkt 10 vorhanden" "PASS"
else
    print_result "Menüpunkt 10 vorhanden" "FAIL"
fi

# --- Test 3: Text-Modus - Ungültige Eingabe ----------------------------------
print_header "Test 3: Text-Modus - Ungültige Eingabe"
output=$(printf "99\n10\n" | OLLAMA_MANAGE_UI=text bash "$MANAGE_SCRIPT" 2>&1)
exit_code=$?

if [ $exit_code -eq 0 ]; then
    print_result "Exit-Code 0 nach ungültiger Eingabe" "PASS"
else
    print_result "Exit-Code 0 nach ungültiger Eingabe (war $exit_code)" "FAIL"
fi

if assert_contains "$output" "Ungueltige Auswahl."; then
    print_result "Fehlermeldung 'Ungueltige Auswahl.'" "PASS"
else
    print_result "Fehlermeldung 'Ungueltige Auswahl.'" "FAIL"
fi

# --- Test 4: Text-Modus - Menüpunkt 7 (Dienst-Status) ------------------------
print_header "Test 4: Text-Modus - Menüpunkt 7 (Dienst-Status)"
output=$(printf "7\n10\n" | OLLAMA_MANAGE_UI=text bash "$MANAGE_SCRIPT" 2>&1)
exit_code=$?

if [ $exit_code -eq 0 ]; then
    print_result "Exit-Code 0 nach Menüpunkt 7" "PASS"
else
    print_result "Exit-Code 0 nach Menüpunkt 7 (war $exit_code)" "FAIL"
fi

# Prüfen, ob das Menü nach Menüpunkt 7 erneut angezeigt wird (Rückkehr zum Hauptmenü)
menu_count=$(echo "$output" | grep -c "=== Model Manager fuer Ollama(Linux) v0.8 ===")
if [ "$menu_count" -ge 2 ]; then
    print_result "Rückkehr zum Hauptmenü nach Menüpunkt 7" "PASS"
else
    print_result "Rückkehr zum Hauptmenü nach Menüpunkt 7 (nur $menu_count Menüanzeigen)" "FAIL"
fi

# --- Test 5: Text-Modus - Menüpunkt 8 (Dienst starten) -----------------------
print_header "Test 5: Text-Modus - Menüpunkt 8 (Dienst starten)"
output=$(printf "8\n10\n" | OLLAMA_MANAGE_UI=text bash "$MANAGE_SCRIPT" 2>&1)
exit_code=$?

if [ $exit_code -eq 0 ]; then
    print_result "Exit-Code 0 nach Menüpunkt 8" "PASS"
else
    print_result "Exit-Code 0 nach Menüpunkt 8 (war $exit_code)" "FAIL"
fi

menu_count=$(echo "$output" | grep -c "=== Model Manager fuer Ollama(Linux) v0.8 ===")
if [ "$menu_count" -ge 2 ]; then
    print_result "Rückkehr zum Hauptmenü nach Menüpunkt 8" "PASS"
else
    print_result "Rückkehr zum Hauptmenü nach Menüpunkt 8" "FAIL"
fi

# --- Test 6: Text-Modus - Menüpunkt 9 (Dienst stoppen) -----------------------
print_header "Test 6: Text-Modus - Menüpunkt 9 (Dienst stoppen)"
output=$(printf "9\n10\n" | OLLAMA_MANAGE_UI=text bash "$MANAGE_SCRIPT" 2>&1)
exit_code=$?

if [ $exit_code -eq 0 ]; then
    print_result "Exit-Code 0 nach Menüpunkt 9" "PASS"
else
    print_result "Exit-Code 0 nach Menüpunkt 9 (war $exit_code)" "FAIL"
fi

menu_count=$(echo "$output" | grep -c "=== Model Manager fuer Ollama(Linux) v0.8 ===")
if [ "$menu_count" -ge 2 ]; then
    print_result "Rückkehr zum Hauptmenü nach Menüpunkt 9" "PASS"
else
    print_result "Rückkehr zum Hauptmenü nach Menüpunkt 9" "FAIL"
fi

# --- Test 7: Text-Modus - Menüpunkt 6 (Ollama installieren) ------------------
print_header "Test 7: Text-Modus - Menüpunkt 6 (Ollama installieren)"
output=$(printf "6\n10\n" | OLLAMA_MANAGE_UI=text bash "$MANAGE_SCRIPT" 2>&1)
exit_code=$?

if [ $exit_code -eq 0 ]; then
    print_result "Exit-Code 0 nach Menüpunkt 6" "PASS"
else
    print_result "Exit-Code 0 nach Menüpunkt 6 (war $exit_code)" "FAIL"
fi

menu_count=$(echo "$output" | grep -c "=== Model Manager fuer Ollama(Linux) v0.8 ===")
if [ "$menu_count" -ge 2 ]; then
    print_result "Rückkehr zum Hauptmenü nach Menüpunkt 6" "PASS"
else
    print_result "Rückkehr zum Hauptmenü nach Menüpunkt 6" "FAIL"
fi

# --- Test 8: Text-Modus - Menüpunkt 1 (Modelle auflisten) --------------------
print_header "Test 8: Text-Modus - Menüpunkt 1 (Modelle auflisten)"
output=$(printf "1\n10\n" | OLLAMA_MANAGE_UI=text bash "$MANAGE_SCRIPT" 2>&1)
exit_code=$?

if [ $exit_code -eq 0 ]; then
    print_result "Exit-Code 0 nach Menüpunkt 1" "PASS"
else
    print_result "Exit-Code 0 nach Menüpunkt 1 (war $exit_code)" "FAIL"
fi

menu_count=$(echo "$output" | grep -c "=== Model Manager fuer Ollama(Linux) v0.8 ===")
if [ "$menu_count" -ge 2 ]; then
    print_result "Rückkehr zum Hauptmenü nach Menüpunkt 1" "PASS"
else
    print_result "Rückkehr zum Hauptmenü nach Menüpunkt 1" "FAIL"
fi

# --- Test 9: Text-Modus - Menüpunkt 2 (Modell installieren) ------------------
print_header "Test 9: Text-Modus - Menüpunkt 2 (Modell installieren)"
output=$(printf "2\n\n10\n" | OLLAMA_MANAGE_UI=text bash "$MANAGE_SCRIPT" 2>&1)
exit_code=$?

if [ $exit_code -eq 0 ]; then
    print_result "Exit-Code 0 nach Menüpunkt 2" "PASS"
else
    print_result "Exit-Code 0 nach Menüpunkt 2 (war $exit_code)" "FAIL"
fi

menu_count=$(echo "$output" | grep -c "=== Model Manager fuer Ollama(Linux) v0.8 ===")
if [ "$menu_count" -ge 2 ]; then
    print_result "Rückkehr zum Hauptmenü nach Menüpunkt 2" "PASS"
else
    print_result "Rückkehr zum Hauptmenü nach Menüpunkt 2" "FAIL"
fi

# --- Test 10: Text-Modus - Menüpunkt 3 (Modell löschen) ----------------------
print_header "Test 10: Text-Modus - Menüpunkt 3 (Modell löschen)"
output=$(printf "3\n\n10\n" | OLLAMA_MANAGE_UI=text bash "$MANAGE_SCRIPT" 2>&1)
exit_code=$?

if [ $exit_code -eq 0 ]; then
    print_result "Exit-Code 0 nach Menüpunkt 3" "PASS"
else
    print_result "Exit-Code 0 nach Menüpunkt 3 (war $exit_code)" "FAIL"
fi

menu_count=$(echo "$output" | grep -c "=== Model Manager fuer Ollama(Linux) v0.8 ===")
if [ "$menu_count" -ge 2 ]; then
    print_result "Rückkehr zum Hauptmenü nach Menüpunkt 3" "PASS"
else
    print_result "Rückkehr zum Hauptmenü nach Menüpunkt 3" "FAIL"
fi

# --- Test 11: Text-Modus - Menüpunkt 4 (Modell starten) ----------------------
print_header "Test 11: Text-Modus - Menüpunkt 4 (Modell starten)"
output=$(printf "4\n\n10\n" | OLLAMA_MANAGE_UI=text bash "$MANAGE_SCRIPT" 2>&1)
exit_code=$?

if [ $exit_code -eq 0 ]; then
    print_result "Exit-Code 0 nach Menüpunkt 4" "PASS"
else
    print_result "Exit-Code 0 nach Menüpunkt 4 (war $exit_code)" "FAIL"
fi

menu_count=$(echo "$output" | grep -c "=== Model Manager fuer Ollama(Linux) v0.8 ===")
if [ "$menu_count" -ge 2 ]; then
    print_result "Rückkehr zum Hauptmenü nach Menüpunkt 4" "PASS"
else
    print_result "Rückkehr zum Hauptmenü nach Menüpunkt 4" "FAIL"
fi

# --- Test 12: Text-Modus - Menüpunkt 5 (Modell stoppen) ----------------------
print_header "Test 12: Text-Modus - Menüpunkt 5 (Modell stoppen)"
output=$(printf "5\n\n10\n" | OLLAMA_MANAGE_UI=text bash "$MANAGE_SCRIPT" 2>&1)
exit_code=$?

if [ $exit_code -eq 0 ]; then
    print_result "Exit-Code 0 nach Menüpunkt 5" "PASS"
else
    print_result "Exit-Code 0 nach Menüpunkt 5 (war $exit_code)" "FAIL"
fi

menu_count=$(echo "$output" | grep -c "=== Model Manager fuer Ollama(Linux) v0.8 ===")
if [ "$menu_count" -ge 2 ]; then
    print_result "Rückkehr zum Hauptmenü nach Menüpunkt 5" "PASS"
else
    print_result "Rückkehr zum Hauptmenü nach Menüpunkt 5" "FAIL"
fi

# --- Test 13: Text-Modus - 'q' zum Beenden -----------------------------------
print_header "Test 13: Text-Modus - 'q' zum Beenden"
output=$(printf "q\n" | OLLAMA_MANAGE_UI=text bash "$MANAGE_SCRIPT" 2>&1)
exit_code=$?

if [ $exit_code -eq 0 ]; then
    print_result "Exit-Code 0 bei 'q'" "PASS"
else
    print_result "Exit-Code 0 bei 'q' (war $exit_code)" "FAIL"
fi

# --- Test 14: Text-Modus - 'Q' zum Beenden -----------------------------------
print_header "Test 14: Text-Modus - 'Q' zum Beenden"
output=$(printf "Q\n" | OLLAMA_MANAGE_UI=text bash "$MANAGE_SCRIPT" 2>&1)
exit_code=$?

if [ $exit_code -eq 0 ]; then
    print_result "Exit-Code 0 bei 'Q'" "PASS"
else
    print_result "Exit-Code 0 bei 'Q' (war $exit_code)" "FAIL"
fi

# --- Test 15: Whiptail-Modus - Menü wird angezeigt ---------------------------
print_header "Test 15: Whiptail-Modus - Menü wird angezeigt"
output=$(PATH="$FAKEBIN_DIR:$PATH" printf "10\n" | OLLAMA_MANAGE_UI=whiptail bash "$MANAGE_SCRIPT" 2>&1)
exit_code=$?

if [ $exit_code -eq 0 ]; then
    print_result "Exit-Code 0 bei Beenden (Whiptail)" "PASS"
else
    print_result "Exit-Code 0 bei Beenden (Whiptail) (war $exit_code)" "FAIL"
fi

# --- Test 16: Whiptail-Modus - Menüpunkt 7 (Dienst-Status) -------------------
print_header "Test 16: Whiptail-Modus - Menüpunkt 7 (Dienst-Status)"
output=$(PATH="$FAKEBIN_DIR:$PATH" printf "7\n10\n" | OLLAMA_MANAGE_UI=whiptail bash "$MANAGE_SCRIPT" 2>&1)
exit_code=$?

if [ $exit_code -eq 0 ]; then
    print_result "Exit-Code 0 nach Menüpunkt 7 (Whiptail)" "PASS"
else
    print_result "Exit-Code 0 nach Menüpunkt 7 (Whiptail) (war $exit_code)" "FAIL"
fi

# --- Test 17: Whiptail-Modus - Menüpunkt 8 (Dienst starten) ------------------
print_header "Test 17: Whiptail-Modus - Menüpunkt 8 (Dienst starten)"
output=$(PATH="$FAKEBIN_DIR:$PATH" printf "8\n10\n" | OLLAMA_MANAGE_UI=whiptail bash "$MANAGE_SCRIPT" 2>&1)
exit_code=$?

if [ $exit_code -eq 0 ]; then
    print_result "Exit-Code 0 nach Menüpunkt 8 (Whiptail)" "PASS"
else
    print_result "Exit-Code 0 nach Menüpunkt 8 (Whiptail) (war $exit_code)" "FAIL"
fi

# --- Test 18: Whiptail-Modus - Menüpunkt 9 (Dienst stoppen) ------------------
print_header "Test 18: Whiptail-Modus - Menüpunkt 9 (Dienst stoppen)"
output=$(PATH="$FAKEBIN_DIR:$PATH" printf "9\n10\n" | OLLAMA_MANAGE_UI=whiptail bash "$MANAGE_SCRIPT" 2>&1)
exit_code=$?

if [ $exit_code -eq 0 ]; then
    print_result "Exit-Code 0 nach Menüpunkt 9 (Whiptail)" "PASS"
else
    print_result "Exit-Code 0 nach Menüpunkt 9 (Whiptail) (war $exit_code)" "FAIL"
fi

# --- Test 19: Whiptail-Modus - Menüpunkt 6 (Ollama installieren) -------------
print_header "Test 19: Whiptail-Modus - Menüpunkt 6 (Ollama installieren)"
output=$(PATH="$FAKEBIN_DIR:$PATH" printf "6\n10\n" | OLLAMA_MANAGE_UI=whiptail bash "$MANAGE_SCRIPT" 2>&1)
exit_code=$?

if [ $exit_code -eq 0 ]; then
    print_result "Exit-Code 0 nach Menüpunkt 6 (Whiptail)" "PASS"
else
    print_result "Exit-Code 0 nach Menüpunkt 6 (Whiptail) (war $exit_code)" "FAIL"
fi

# --- Test 20: Whiptail-Modus - Menüpunkt 1 (Modelle auflisten) ---------------
print_header "Test 20: Whiptail-Modus - Menüpunkt 1 (Modelle auflisten)"
output=$(PATH="$FAKEBIN_DIR:$PATH" printf "1\n10\n" | OLLAMA_MANAGE_UI=whiptail bash "$MANAGE_SCRIPT" 2>&1)
exit_code=$?

if [ $exit_code -eq 0 ]; then
    print_result "Exit-Code 0 nach Menüpunkt 1 (Whiptail)" "PASS"
else
    print_result "Exit-Code 0 nach Menüpunkt 1 (Whiptail) (war $exit_code)" "FAIL"
fi

# --- Test 21: Whiptail-Modus - Menüpunkt 2 (Modell installieren) -------------
print_header "Test 21: Whiptail-Modus - Menüpunkt 2 (Modell installieren)"
output=$(PATH="$FAKEBIN_DIR:$PATH" printf "2\n\n10\n" | OLLAMA_MANAGE_UI=whiptail bash "$MANAGE_SCRIPT" 2>&1)
exit_code=$?

if [ $exit_code -eq 0 ]; then
    print_result "Exit-Code 0 nach Menüpunkt 2 (Whiptail)" "PASS"
else
    print_result "Exit-Code 0 nach Menüpunkt 2 (Whiptail) (war $exit_code)" "FAIL"
fi

# --- Test 22: Whiptail-Modus - Menüpunkt 3 (Modell löschen) ------------------
print_header "Test 22: Whiptail-Modus - Menüpunkt 3 (Modell löschen)"
output=$(PATH="$FAKEBIN_DIR:$PATH" printf "3\n\n10\n" | OLLAMA_MANAGE_UI=whiptail bash "$MANAGE_SCRIPT" 2>&1)
exit_code=$?

if [ $exit_code -eq 0 ]; then
    print_result "Exit-Code 0 nach Menüpunkt 3 (Whiptail)" "PASS"
else
    print_result "Exit-Code 0 nach Menüpunkt 3 (Whiptail) (war $exit_code)" "FAIL"
fi

# --- Test 23: Whiptail-Modus - Menüpunkt 4 (Modell starten) ------------------
print_header "Test 23: Whiptail-Modus - Menüpunkt 4 (Modell starten)"
output=$(PATH="$FAKEBIN_DIR:$PATH" printf "4\n\n10\n" | OLLAMA_MANAGE_UI=whiptail bash "$MANAGE_SCRIPT" 2>&1)
exit_code=$?

if [ $exit_code -eq 0 ]; then
    print_result "Exit-Code 0 nach Menüpunkt 4 (Whiptail)" "PASS"
else
    print_result "Exit-Code 0 nach Menüpunkt 4 (Whiptail) (war $exit_code)" "FAIL"
fi

# --- Test 24: Whiptail-Modus - Menüpunkt 5 (Modell stoppen) ------------------
print_header "Test 24: Whiptail-Modus - Menüpunkt 5 (Modell stoppen)"
output=$(PATH="$FAKEBIN_DIR:$PATH" printf "5\n\n10\n" | OLLAMA_MANAGE_UI=whiptail bash "$MANAGE_SCRIPT" 2>&1)
exit_code=$?

if [ $exit_code -eq 0 ]; then
    print_result "Exit-Code 0 nach Menüpunkt 5 (Whiptail)" "PASS"
else
    print_result "Exit-Code 0 nach Menüpunkt 5 (Whiptail) (war $exit_code)" "FAIL"
fi

# --- Test 25: Auto-Modus (Fallback auf Text, wenn kein TTY) ------------------
print_header "Test 25: Auto-Modus (Fallback auf Text, wenn kein TTY)"
output=$(printf "10\n" | OLLAMA_MANAGE_UI=auto bash "$MANAGE_SCRIPT" 2>&1)
exit_code=$?

if [ $exit_code -eq 0 ]; then
    print_result "Exit-Code 0 bei Auto-Modus" "PASS"
else
    print_result "Exit-Code 0 bei Auto-Modus (war $exit_code)" "FAIL"
fi

if assert_contains "$output" "=== Model Manager fuer Ollama(Linux) v0.8 ==="; then
    print_result "Auto-Modus zeigt Text-Menü (kein TTY)" "PASS"
else
    print_result "Auto-Modus zeigt Text-Menü (kein TTY)" "FAIL"
fi

# --- Test 26: Fehlerfall - Ollama nicht installiert --------------------------
print_header "Test 26: Fehlerfall - Ollama nicht installiert"
# Simuliert, dass ollama nicht installiert ist, indem PATH ohne ollama gesetzt wird
output=$(printf "1\n10\n" | PATH="/usr/bin:/bin" OLLAMA_MANAGE_UI=text bash "$MANAGE_SCRIPT" 2>&1)
exit_code=$?

if [ $exit_code -eq 0 ]; then
    print_result "Exit-Code 0 wenn ollama fehlt" "PASS"
else
    print_result "Exit-Code 0 wenn ollama fehlt (war $exit_code)" "FAIL"
fi

if assert_contains "$output" "ollama wurde nicht gefunden"; then
    print_result "Fehlermeldung 'ollama wurde nicht gefunden'" "PASS"
else
    print_result "Fehlermeldung 'ollama wurde nicht gefunden'" "FAIL"
fi

# --- Test 27: Fehlerfall - Daemon nicht erreichbar ---------------------------
print_header "Test 27: Fehlerfall - Daemon nicht erreichbar"
# Simuliert, dass ollama installiert ist, aber der Daemon nicht läuft
# Wir erstellen ein Fake-ollama, das bei 'list' fehlschlägt
mkdir -p "$FAKEBIN_DIR"
cat > "$FAKEBIN_DIR/ollama" << 'FAKEOLLAMA'
#!/usr/bin/env bash
# Fake-ollama: Simuliert ollama, das installiert ist, aber Daemon nicht erreichbar
if [ "$1" = "-v" ]; then
    echo "ollama version is 0.32.14"
    exit 0
fi
if [ "$1" = "list" ]; then
    echo "Fehler: Daemon nicht erreichbar" >&2
    exit 1
fi
exit 0
FAKEOLLAMA
chmod +x "$FAKEBIN_DIR/ollama"

output=$(printf "1\n10\n" | PATH="$FAKEBIN_DIR:/usr/bin:/bin" OLLAMA_MANAGE_UI=text bash "$MANAGE_SCRIPT" 2>&1)
exit_code=$?

if [ $exit_code -eq 0 ]; then
    print_result "Exit-Code 0 wenn Daemon nicht erreichbar" "PASS"
else
    print_result "Exit-Code 0 wenn Daemon nicht erreichbar (war $exit_code)" "FAIL"
fi

if assert_contains "$output" "Der Ollama-Daemon ist nicht erreichbar"; then
    print_result "Fehlermeldung 'Daemon nicht erreichbar'" "PASS"
else
    print_result "Fehlermeldung 'Daemon nicht erreichbar'" "FAIL"
fi

# --- Test 28: Fehlerfall - Dienst nicht gestartet ----------------------------
print_header "Test 28: Fehlerfall - Dienst nicht gestartet"
# Simuliert, dass ollama installiert ist und Daemon läuft, aber systemd-Dienst nicht aktiv
cat > "$FAKEBIN_DIR/ollama" << 'FAKEOLLAMA2'
#!/usr/bin/env bash
# Fake-ollama: Simuliert ollama, das installiert ist und Daemon läuft
if [ "$1" = "-v" ]; then
    echo "ollama version is 0.32.14"
    exit 0
fi
if [ "$1" = "list" ]; then
    echo "NAME    ID    SIZE    MODIFIED"
    exit 0
fi
exit 0
FAKEOLLAMA2
chmod +x "$FAKEBIN_DIR/ollama"

# Fake-systemctl: Dienst existiert, aber nicht aktiv
cat > "$FAKEBIN_DIR/systemctl" << 'FAKESYSTEMCTL'
#!/usr/bin/env bash
# Fake-systemctl: Simuliert systemctl
if [ "$1" = "list-unit-files" ]; then
    exit 0  # Dienst existiert
fi
if [ "$1" = "is-active" ]; then
    exit 3  # Dienst nicht aktiv
fi
if [ "$1" = "status" ]; then
    echo "ollama.service - Ollama Service"
    echo "   Active: inactive (dead)"
    exit 3
fi
if [ "$1" = "start" ]; then
    exit 0
fi
if [ "$1" = "stop" ]; then
    exit 0
fi
exit 0
FAKESYSTEMCTL
chmod +x "$FAKEBIN_DIR/systemctl"

output=$(printf "7\n10\n" | PATH="$FAKEBIN_DIR:/usr/bin:/bin" OLLAMA_MANAGE_UI=text bash "$MANAGE_SCRIPT" 2>&1)
exit_code=$?

if [ $exit_code -eq 0 ]; then
    print_result "Exit-Code 0 wenn Dienst nicht gestartet" "PASS"
else
    print_result "Exit-Code 0 wenn Dienst nicht gestartet (war $exit_code)" "FAIL"
fi

if assert_contains "$output" "Der Ollama-Dienst ist nicht gestartet"; then
    print_result "Hinweis 'Dienst nicht gestartet'" "PASS"
else
    print_result "Hinweis 'Dienst nicht gestartet'" "FAIL"
fi

menu_count=$(echo "$output" | grep -c "=== Model Manager fuer Ollama(Linux) v0.8 ===")
if [ "$menu_count" -ge 2 ]; then
    print_result "Rückkehr zum Hauptmenü wenn Dienst nicht gestartet" "PASS"
else
    print_result "Rückkehr zum Hauptmenü wenn Dienst nicht gestartet" "FAIL"
fi

# --- Test 29: Fehlerfall - Dienst existiert nicht ----------------------------
print_header "Test 29: Fehlerfall - Dienst existiert nicht"
# Fake-systemctl: Dienst existiert nicht
cat > "$FAKEBIN_DIR/systemctl" << 'FAKESYSTEMCTL2'
#!/usr/bin/env bash
# Fake-systemctl: Simuliert systemctl, Dienst existiert nicht
if [ "$1" = "list-unit-files" ]; then
    exit 1  # Dienst existiert nicht
fi
if [ "$1" = "is-active" ]; then
    exit 3
fi
if [ "$1" = "status" ]; then
    echo "Unit ollama.service could not be found."
    exit 4
fi
exit 0
FAKESYSTEMCTL2
chmod +x "$FAKEBIN_DIR/systemctl"

output=$(printf "7\n10\n" | PATH="$FAKEBIN_DIR:/usr/bin:/bin" OLLAMA_MANAGE_UI=text bash "$MANAGE_SCRIPT" 2>&1)
exit_code=$?

if [ $exit_code -eq 0 ]; then
    print_result "Exit-Code 0 wenn Dienst nicht existiert" "PASS"
else
    print_result "Exit-Code 0 wenn Dienst nicht existiert (war $exit_code)" "FAIL"
fi

if assert_contains "$output" "Der systemd-Dienst 'ollama' existiert nicht"; then
    print_result "Fehlermeldung 'Dienst existiert nicht'" "PASS"
else
    print_result "Fehlermeldung 'Dienst existiert nicht'" "FAIL"
fi

# --- Test 30: Fehlerfall - Dienst aktiv, Status abrufbar ---------------------
print_header "Test 30: Fehlerfall - Dienst aktiv, Status abrufbar"
# Fake-systemctl: Dienst existiert und ist aktiv
cat > "$FAKEBIN_DIR/systemctl" << 'FAKESYSTEMCTL3'
#!/usr/bin/env bash
# Fake-systemctl: Simuliert systemctl, Dienst aktiv
if [ "$1" = "list-unit-files" ]; then
    exit 0  # Dienst existiert
fi
if [ "$1" = "is-active" ]; then
    exit 0  # Dienst aktiv
fi
if [ "$1" = "status" ]; then
    echo "ollama.service - Ollama Service"
    echo "   Active: active (running)"
    exit 0
fi
exit 0
FAKESYSTEMCTL3
chmod +x "$FAKEBIN_DIR/systemctl"

output=$(printf "7\n10\n" | PATH="$FAKEBIN_DIR:/usr/bin:/bin" OLLAMA_MANAGE_UI=text bash "$MANAGE_SCRIPT" 2>&1)
exit_code=$?

if [ $exit_code -eq 0 ]; then
    print_result "Exit-Code 0 wenn Dienst aktiv" "PASS"
else
    print_result "Exit-Code 0 wenn Dienst aktiv (war $exit_code)" "FAIL"
fi

if assert_contains "$output" "=== Systemd Dienst-Status ==="; then
    print_result "Status wird angezeigt" "PASS"
else
    print_result "Status wird angezeigt" "FAIL"
fi

# --- Zusammenfassung ---------------------------------------------------------
print_header "ZUSAMMENFASSUNG"
echo "  Bestanden: $PASS"
echo "  Fehlgeschlagen: $FAIL"

if [ "$FAIL" -gt 0 ]; then
    echo ""
    echo "  Fehlgeschlagene Tests:"
    for t in "${FAILED_TESTS[@]}"; do
        echo "    - $t"
    done
    echo ""
    echo "  ERGEBNIS: FEHLGESCHLAGEN"
    exit 1
else
    echo ""
    echo "  ERGEBNIS: ALLE TESTS BESTANDEN"
    exit 0
fi