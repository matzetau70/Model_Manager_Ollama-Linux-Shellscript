# Model Manager für Ollama (Linux)

Ein Bash-Skript zur Verwaltung von Ollama-Modellen auf Linux-Systemen. Bietet eine grafische Oberfläche (Whiptail) sowie einen Text-Modus für die Verwaltung von Modellen, Diensten und Installationen.

![Model Manager Whiptail-Modus](ollama-manage.png)

![Model Manager Text-Modus](ollama-manage-text.png)

## 📋 Funktionen

| Nr. | Funktion | Beschreibung |
| ----- | ---------- | -------------- |
| 1 | **Modelle auflisten** | Zeigt alle lokal installierten Ollama-Modelle an |
| 2 | **Modell installieren** | Lädt ein Modell von Ollama herunter (mit Fortschrittsanzeige im Whiptail-Modus) |
| 3 | **Modell löschen** | Entfernt ein Modell unwiderruflich von der Festplatte (mit Sicherheitsabfrage) |
| 4 | **Modell starten** | Startet eine interaktive Chat-Sitzung mit einem Modell |
| 5 | **Modell stoppen** | Entlädt ein Modell aus dem RAM/VRAM (via Ollama-API) |
| 6 | **Ollama installieren/aktualisieren** | Installiert oder aktualisiert Ollama über das offizielle Installationsskript |
| 7 | **Dienst-Status anzeigen** | Zeigt den Status des systemd-Dienstes an |
| 8 | **Dienst starten** | Startet den Ollama-Hintergrunddienst |
| 9 | **Dienst stoppen** | Stoppt den Ollama-Hintergrunddienst |
| 10 | **Beenden** | Beendet das Programm |

## 🚀 Installation

### Voraussetzungen

- **Linux** (mit systemd)
- **Bash** (≥ 4.0)
- **whiptail** (für den grafischen Modus, optional)
- **curl** (für die Installation)
- **Ollama** (wird automatisch erkannt, kann über Menüpunkt 6 installiert werden)

### Installation des Skripts

```bash
# Skript herunterladen oder kopieren
git clone https://github.com/matzetau70/matzetau70-Scripte_BashShellCLI.git
cd "Model_Manager_Ollama(Linux-Shellscript)"

# Ausführbar machen
chmod +x ollama-manage.sh
```

## ▶️ Verwendung

```bash
./ollama-manage.sh
```

### UI-Modus steuern

Das Skript wählt automatisch den passenden Modus:

| Modus | Beschreibung |
| ------- | -------------- |
| **auto** (Standard) | Nutzt Whiptail, wenn ein Terminal und whiptail verfügbar sind, sonst Text-Modus |
| **text** | Erzwingt den Text-Modus |
| **whiptail** | Erzwingt den Whiptail-Modus |

```bash
# Text-Modus erzwingen
OLLAMA_MANAGE_UI=text ./ollama-manage.sh

# Whiptail-Modus erzwingen
OLLAMA_MANAGE_UI=whiptail ./ollama-manage.sh
```

### Umgebungsvariablen

| Variable | Wert | Beschreibung |
| --------- | ------ | -------------- |
| `OLLAMA_MANAGE_UI` | `auto` (Standard) | Automatische Moduswahl (Whiptail, wenn verfügbar, sonst Text) |
| | `text` | Erzwingt den Text-Modus |
| | `whiptail` | Erzwingt den Whiptail-Modus (fällt auf Text zurück, wenn whiptail fehlt) |

### Erweiterte Nutzung

#### fzf-Unterstützung (Text-Modus)

Im Text-Modus wird **fzf** (fuzzy finder) automatisch für die Modellauswahl verwendet, sofern es installiert ist. Dies bietet eine komfortable, durchsuchbare Auswahl aller lokal installierten Modelle:

```bash
# fzf installieren (Debian/Ubuntu)
sudo apt install fzf

# fzf installieren (Arch Linux)
sudo pacman -S fzf
```

Falls fzf nicht verfügbar ist, fällt das Skript auf eine nummerierte Liste mit Texteingabe zurück.

#### Modellnamen-Validierung

Beim Installieren eines Modells (Menüpunkt 2) wird der eingegebene Name validiert. Erlaubt sind nur Buchstaben, Zahlen sowie die Zeichen `.`, `-`, `_`, `:` und `@`. Ungültige Eingaben werden mit einer Fehlermeldung abgewiesen.

#### Modell bereits installiert

Wenn ein Modell bereits lokal vorhanden ist, wird dies beim Installieren erkannt und eine entsprechende Hinweismeldung angezeigt – ein erneuter Download wird vermieden.

## ⚠️ Fehlerbehandlung & Troubleshooting

### Häufige Fehlermeldungen

| Fehlermeldung | Ursache | Lösung |
| ---------------- | --------- | -------- |
| `ollama wurde nicht gefunden` | Ollama ist nicht installiert | Menüpunkt 6 (Ollama installieren) |
| `Der Ollama-Daemon ist nicht erreichbar` | Ollama-Dienst läuft nicht | Menüpunkt 8 (Dienst starten) oder `ollama serve` |
| `Der systemd-Dienst 'ollama' existiert nicht` | Ollama wurde nicht über das offizielle Installationsskript installiert | Ollama über Menüpunkt 6 neu installieren |
| `Der Ollama-Dienst ist nicht gestartet` | Dienst ist installiert, aber nicht aktiv | Menüpunkt 8 (Dienst starten) |
| `Ungültiger Modellname` | Eingabe enthält nicht erlaubte Zeichen | Nur Buchstaben, Zahlen, `.`, `-`, `_`, `:`, `@` verwenden |
| `API-Fehler beim Stoppen des Modells` | Ollama-API nicht erreichbar oder Modell nicht geladen | Prüfen, ob der Dienst läuft (Menüpunkt 7) |

### Sicherheitshinweise

- **Menüpunkte 7–9** (Dienst-Status, Start, Stopp) verwenden `sudo` und erfordern Administratorrechte. Sie werden nach dem Passwort gefragt.
- **Menüpunkt 3** (Modell löschen) entfernt Modelle **unwiderruflich** von der Festplatte. Im Whiptail-Modus erscheint eine Sicherheitsabfrage, die standardmäßig auf **"Nein"** voreingestellt ist.
- **Menüpunkt 6** (Ollama installieren) führt das offizielle Installationsskript von `https://ollama.com/install.sh` aus. Dies erfordert eine Internetverbindung und `sudo`-Rechte.

### Hinweise zur Fehlerbehandlung

- Das Skript verwendet `set -euo pipefail` für robuste Fehlerbehandlung.
- Fehlermeldungen werden im Text-Modus auf `stderr` ausgegeben, im Whiptail-Modus als Dialogbox angezeigt.
- Bei nicht installiertem Ollama oder nicht erreichbarem Daemon werden die Menüpunkte 1–5 automatisch blockiert und eine verständliche Fehlermeldung angezeigt.

## 🧪 Tests

Das Projekt enthält ein umfassendes Testskript:

```bash
bash tests/test_ollama_manage.sh
```

Das Testskript testet alle 10 Menüpunkte in beiden UI-Modi sowie Fehlerfälle (Ollama nicht installiert, Daemon nicht erreichbar, Dienst nicht gestartet, Dienst existiert nicht).

## 📁 Projektstruktur

``` text
├── ollama-manage.sh          # Hauptskript
├── ollama-manage.png         # Screenshot (Whiptail-Modus)
├── ollama-manage-text.png    # Screenshot (Text-Modus)
├── tests/
│   ├── test_ollama_manage.sh # Testskript
│   └── fakebin/              # Fake-Binaries für Tests (ignoriert)
├── .gitignore
├── LICENSE
└── README.md
```

## 🛠️ Technische Details

- **Sprache:** Bash (≥ 4.0)
- **GUI:** Whiptail (Dialogboxen)
- **Modellauswahl (Text-Modus):** fzf (optional, mit Fallback auf nummerierte Liste)
- **Modellverwaltung:** `ollama list`, `ollama pull`, `ollama rm`, `ollama run`, `ollama ps`
- **Dienstverwaltung:** `systemctl` (start, stop, status)
- **Modell stoppen:** Ollama-API (`POST /api/generate` mit `keep_alive: 0`)
- **Installation:** Offizielles Ollama-Installationsskript (`https://ollama.com/install.sh`)
- **Fehlerbehandlung:** `set -euo pipefail`, `|| true` in Menü-Case-Zweigen
- **Versionserkennung:** `ollama -v` mit Regex-Extraktion (`version is X.Y.Z`)
- **Modellnamen-Validierung:** Regex `^[a-zA-Z0-9_@:.-]+$`
- **Download-Fortschritt (Whiptail):** `ollama pull` mit `awk`-Prozentwert-Extraktion und `whiptail --gauge`

## 📄 Lizenz

**Copyright © 2026 Matthias Post (matzetau70)** – Alle Rechte vorbehalten.

Dieses Projekt ist unter der **MIT-Lizenz** veröffentlicht.

``` text
MIT License

Copyright (c) 2026 Matthias Post (matzetau70)

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

Die vollständige Lizenz finden Sie in der Datei [`LICENSE`](LICENSE).

## 👤 Autor

- **GitHub:** [matzetau70](https://github.com/matzetau70)
