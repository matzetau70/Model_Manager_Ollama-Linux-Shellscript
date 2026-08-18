#!/usr/bin/env bash
set -euo pipefail

# Modellpaket fuer lokale Tests und Demo-Setups.
# Jeder Aufruf laedt ein Modell in den Ollama-Cache.

# Prueft, ob ollama installiert und der Daemon erreichbar ist.
if ! command -v ollama >/dev/null 2>&1; then
  echo "Fehler: ollama wurde nicht gefunden."
  echo "Bitte ollama installieren und erneut versuchen."
  exit 1
fi

if ! ollama list >/dev/null 2>&1; then
  echo "Fehler: ollama ist installiert, aber der Daemon ist nicht erreichbar."
  echo "Bitte den Ollama-Dienst starten (z. B. 'ollama serve') und erneut versuchen."
  exit 1
fi

ollama pull smollm:135m
ollama pull smollm2:135m
ollama pull smollm2:360m
ollama pull qwen2.5:0.5b
#ollama pull llama3.2:1b

# Beispiele zum manuellen Starten nach dem Download.
# ollama run smollm:135m
# ollama run smollm2:135m
# ollama run smollm2:360m
# ollama run qwen2.5:0.5b
# ollama run llama3.2:1b
