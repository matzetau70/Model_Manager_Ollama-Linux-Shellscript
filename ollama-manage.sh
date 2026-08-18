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
    echo "Fehler: ollama wurde nicht gefunden."
    echo "Bitte ollama installieren und erneut versuchen."
    exit 1
  fi
  # Prueft, ob der Ollama-Daemon erreichbar ist.
  if ! ollama list >/dev/null 2>&1; then
    echo "Fehler: ollama ist installiert, aber der Daemon ist nicht erreichbar."
    echo "Bitte den Ollama-Dienst starten (z. B. 'ollama serve') und erneut versuchen."
    exit 1
  fi
}

show_list() {
  echo "Installierte Modelle:"
  echo
  ollama list
}

# Gibt nur Modellnamen aus, damit sie in Menues oder Auswahlen weiterverwendet werden koennen.
list_models() {
  ollama list 2>/dev/null | awk 'NR>1 && $1 != "" { print $1 }'
}

# Waehlt ein Modell ueber fzf, whiptail oder eine einfache Texteingabe.
pick_model() {
  local prompt="${1:-Modell waehlen}"
  local model

  if have fzf; then
    model="$(list_models | fzf --prompt="${prompt}: " --height=10 --border)" || return 1
  elif have whiptail && [ -t 1 ]; then
    local options=()
    while IFS= read -r line; do
      [ -n "$line" ] || continue
      options+=("$line" "$line")
    done < <(list_models)

    [ "${#options[@]}" -gt 0 ] || return 1

    model="$(
      whiptail --title "$APP_NAME" --menu "$prompt" 20 78 10 \
        "${options[@]}" \
        3>&1 1>&2 2>&3
    )" || return 1
  else
    local model_map=()
    while IFS= read -r line; do
      [ -n "$line" ] || continue
      model_map+=("$line")
    done < <(list_models)

    [ "${#model_map[@]}" -gt 0 ] || return 1

    echo "Verfuegbare Modelle:" >&2
    for i in "${!model_map[@]}"; do
      printf '%d) %s\n' "$((i+1))" "${model_map[$i]}" >&2
    done
    printf "%s (Nummer eingeben): " "$prompt" >&2
    read -r choice

    # Falls eine Nummer eingegeben wurde, in den Modellnamen aufloesen.
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#model_map[@]}" ]; then
      model="${model_map[$((choice-1))]}"
    else
      model="$choice"
    fi
  fi

  [ -n "${model:-}" ] || return 1
  printf '%s\n' "$model"
}

# Laedt ein Modell per ollama pull herunter.
pull_model() {
  local model="${1:-}"
  if [ -z "$model" ]; then
    printf "Modellname: "
    read -r model
  fi
  if [ -z "$model" ]; then
    echo "Abgebrochen: kein Modellname angegeben."
    return
  fi
  
  # Pruengen, ob Modell bereits installiert
  if ollama list 2>/dev/null | grep -q "^${model}$"; then
    echo "Hinweis: $model ist bereits installiert."
    return 0
  fi
  
  echo "Installiere: $model"
  ollama pull "$model"
}

# Loescht ein lokal installiertes Modell.
remove_model() {
  local model="${1:-}"
  if [ -z "$model" ]; then
    model="$(pick_model "Welches Modell loeschen?" || true)"
  fi
  if [ -z "$model" ]; then
    echo "Abgebrochen: kein Modellname angegeben."
    return
  fi
  echo "Loesche: $model"
  ollama rm "$model"
}

# Startet ein Modell interaktiv mit ollama run.
run_model() {
  local model="${1:-}"
  if [ -z "$model" ]; then
    model="$(pick_model "Welches Modell starten?" || true)"
  fi
  if [ -z "$model" ]; then
    echo "Abgebrochen: kein Modellname angegeben."
    return
  fi
  
  # Pruengen, ob Modell bereits aktiv
  if ollama list 2>/dev/null | grep -q "^${model}$"; then
    echo "Hinweis: $model ist bereits aktiv."
    return 0
  fi
  
  ollama run "$model"
}

# Stoppt ein laufendes Modell, falls Ollama es kennt.
stop_model() {
  local model="${1:-}"
  if [ -z "$model" ]; then
    model="$(pick_model "Welches Modell stoppen?" || true)"
  fi
  if [ -z "$model" ]; then
    echo "Abgebrochen: kein Modellname angegeben."
    return
  fi
  echo "Stoppe: $model"
  ollama stop "$model"
}

# Textbasiertes Fallback-Menue fuer Terminals ohne whiptail.
text_menu() {
  while true; do
    echo
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
      1) show_list ;;
      2) pull_model ;;
      3) remove_model ;;
      4) run_model ;;
      5) stop_model ;;
      6|q|Q) exit 0 ;;
      *) echo "Ungueltige Auswahl." ;;
    esac
  done
}

# TODO: ok

# Zentraler Einstiegspunkt: prueft Argumente und waehlt interaktiven oder direkten Modus.
main() {
  require_ollama  # Ollama-Pruefung vor Menu-Auswahl
  
  text_menu       # Menu-Auswahl
}
main "$@"
