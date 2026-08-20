#!/usr/bin/env bash
set -euo pipefail


# Hier läuft dein Skript weiter...
echo "Prüfe Ollama-Status..."

# Prüft, ob ollama installiert ist
if ! command -v ollama >/dev/null 2>&1; then
  if command -v whiptail >/dev/null 2>&1; then
    whiptail --title "Fehler: Ollama fehlt" --msgbox "Ollama wurde nicht gefunden.\n\nBitte installiere Ollama, bevor du dieses Skript ausführst." 10 50
  else
    echo "Fehler: ollama wurde nicht gefunden."
  fi
  exit 1
fi

# Prüft, ob der Daemon erreichbar ist
if ! ollama list >/dev/null 2>&1; then
  if command -v whiptail >/dev/null 2>&1; then
    whiptail --title "Fehler: Daemon offline" --msgbox "Ollama ist installiert, aber der Daemon ist nicht erreichbar.\n\nBitte starte den Dienst (z. B. mit 'ollama serve')." 10 50
  else
    echo "Fehler: Ollama-Daemon nicht erreichbar."
  fi
  exit 1
fi

# Prüft, ob whiptail für die UI installiert ist
if ! command -v whiptail >/dev/null 2>&1; then
  echo "Hinweis: 'whiptail' ist nicht installiert. Installiere es für eine grafische Auswahl."
  echo "Führe Standard-Download aus..."
  ollama pull smollm:135m
  ollama pull smollm2:135m
  ollama pull smollm2:360m
  ollama pull qwen2.5:0.5b
  exit 0
fi

# Grafisches Auswahlmenü mit Whiptail erstellen
CHOICES=$(whiptail --title "Ollama Modell-Manager" \
  --checklist "  Modelle zu Testen herunterladen ...\n  Wähle die Modelle aus." 15 60 5 \
  "smollm:135m" "Sehr leichtes, schnelles Modell" ON \
  "smollm2:135m" "Optimierte 135m-Version" ON \
  "smollm2:360m" "Erw. SmollM2-Variante" ON \
  "qwen2.5:0.5b" "Starkes 0.5B Sprachmodell" ON \
  "llama3.2:1b" "Größeres 1B Meta-Modell" OFF \
  3>&1 1>&2 2>&3)

# Falls der Benutzer "Abbrechen" wählt
if [ -z "$CHOICES" ]; then
  echo "Download abgebrochen."
  exit 0
fi

# Ausgewählte Modelle verarbeiten und laden
echo "Starte Download der ausgewählten Modelle..."
for MODEL in $CHOICES; do
  # Entfernt die Anführungszeichen aus der Whiptail-Ausgabe
  MODEL=$(echo "$MODEL" | sed 's/"//g')
  echo "----------------------------------------"
  echo "Lade Modell: $MODEL"
  echo "----------------------------------------"
  ollama pull "$MODEL"
done

echo "Fertig! Alle ausgewählten Modelle sind einsatzbereit."
