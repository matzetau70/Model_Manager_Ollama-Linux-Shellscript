# 📋 Projekt-Review: Model Manager für Ollama (Linux)

**Review-Datum:** 20. August 2026  
**Reviewer:** Matthias Post (matzetau70)  
**Version:** 0.8  
**Hauptskript:** `ollama-manage.sh` (571 Zeilen)  
**Testskript:** `tests/test_ollama_manage.sh` (683 Zeilen, 50 Tests)

---

## 1. Zusammenfassung

Das Projekt ist ein gut strukturiertes, funktionsreiches Bash-Skript zur Verwaltung von Ollama-Modellen auf Linux-Systemen. Es bietet eine Whiptail-GUI sowie einen Text-Modus und deckt alle wesentlichen Verwaltungsaufgaben ab: Modellverwaltung (Liste, Installieren, Löschen, Starten, Stoppen), Dienstverwaltung (Status, Start, Stopp) und Installation/Aktualisierung von Ollama selbst.

**Gesamtbewertung: 8,5 / 10** – Sehr gut umgesetzt, mit wenigen Verbesserungspotenzialen.

---

## 2. Stärken

### 2.1 Architektur & Code-Qualität

- ✅ **Klare Struktur:** Funktionen sind logisch gruppiert und gut benannt (`install_ollama`, `status_service`, `pull_model`, etc.)
- ✅ **Robuste Fehlerbehandlung:** `set -euo pipefail` verhindert stille Fehler
- ✅ **Konsistente UI-Abstraktion:** Jede Funktion akzeptiert `ui_mode` als Parameter und rendert entsprechend (Whiptail vs. Text)
- ✅ **Modularität:** Wiederverwendbare Helfer wie `have()`, `check_installed()`, `require_ollama()`, `list_models()`, `pick_model()`
- ✅ **Saubere Kommentare:** Funktionen sind mit erklärenden Kommentaren versehen

### 2.2 Benutzerfreundlichkeit

- ✅ **Dual-Mode-UI:** Automatische Moduswahl (Whiptail ↔ Text) mit manueller Überschreibung via `OLLAMA_MANAGE_UI`
- ✅ **fzf-Unterstützung:** Komfortable Modellauswahl im Text-Modus, wenn fzf installiert ist
- ✅ **Sicherheitsabfragen:** Löschvorgänge mit `--defaultno` (Standard: "Nein")
- ✅ **Fortschrittsanzeige:** `whiptail --gauge` für Download-Fortschritt
- ✅ **Live-Speicherdaten:** `ollama ps`-Daten (Größe, GPU) im Stopp-Menü
- ✅ **Statusanzeige:** Ollama-Version wird im Menü angezeigt

### 2.3 Fehlerbehandlung

- ✅ **Daemon-Prüfung:** `require_ollama()` blockiert Menüpunkte 1–5, wenn Ollama fehlt oder der Daemon nicht erreichbar ist
- ✅ **Dienst-Existenzprüfung:** Menüpunkt 7 prüft, ob der systemd-Dienst überhaupt existiert
- ✅ **Modellnamen-Validierung:** Regex `^[a-zA-Z0-9_@:.-]+$` verhindert ungültige Eingaben
- ✅ **Duplikat-Erkennung:** Bereits installierte Modelle werden erkannt
- ✅ **HTTP-Statuscode-Prüfung:** Beim Stoppen von Modellen wird der API-Response geprüft

### 2.4 Testabdeckung

- ✅ **50 Tests** decken alle 10 Menüpunkte in beiden UI-Modi ab
- ✅ **Fehlerfall-Simulation:** Ollama nicht installiert, Daemon nicht erreichbar, Dienst nicht gestartet, Dienst existiert nicht
- ✅ **Fake-Binaries:** Isolierte Tests ohne echte Systemabhängigkeiten
- ✅ **Syntaxprüfung:** `bash -n` als erster Test

### 2.5 Dokumentation

- ✅ **README.md:** Umfassend (190 Zeilen) mit Funktionstabelle, Installation, Verwendung, Troubleshooting, Sicherheitshinweisen
- ✅ **Screenshots:** Whiptail- und Text-Modus visuell dokumentiert
- ✅ **MIT-Lizenz:** Klar definiert

---

## 3. Schwächen & Verbesserungspotenziale

### 3.1 Code-Qualität

| # | Bereich | Problem | Empfehlung |
| --- | --------- | --------- | ------------ |
| 1 | **Duplikation** | `show_list_whiptail()` und `show_list_text()` sind fast identisch | Zu einer Funktion mit `ui_mode`-Parameter zusammenfassen |
| 2 | **Duplikation** | Modellauswahl-Logik in `remove_model()`, `run_model()`, `stop_model()` wiederholt sich | Gemeinsame Helferfunktion `select_model_whiptail()` extrahieren |
| 3 | **Magische Zahlen** | Whiptail-Größen (10 60, 20 78, 22 80) sind hartcodiert | Konstanten definieren (z.B. `MSG_HEIGHT=10`, `MSG_WIDTH=60`) |
| 4 | **`ollama ps`-Parsing** | Spaltenbasierte Extraktion (`awk '{print $1}'`) ist fragil bei variabler Ausgabe | Robustere Parsing-Logik oder `--format json` verwenden |
| 5 | **`sudo`-Handling** | Keine Prüfung, ob `sudo` verfügbar ist | `have sudo` prüfen und verständliche Fehlermeldung ausgeben |
| 6 | **`curl`-Abhängigkeit** | `curl` wird für Installation und API-Calls benötigt, aber nicht geprüft | `have curl` in `require_ollama()` oder beim Start prüfen |

### 3.2 Funktionalität

| # | Bereich | Problem | Empfehlung |
| --- | --------- | --------- | ------------ |
| 7 | **Kein Update-Check** | Keine Prüfung auf neuere Skript-Versionen | Optionalen Update-Check (z.B. via GitHub-API) einbauen |
| 8 | **Kein Backup** | Keine Möglichkeit, Modell-Listen zu exportieren | `ollama list` als CSV/JSON exportieren |
| 9 | **Kein Batch-Betrieb** | Keine Unterstützung für Skripting/Automatisierung | Nicht-interaktiven Modus (`--list`, `--pull MODEL`, etc.) hinzufügen |
| 10 | **Kein Logging** | Keine Log-Datei für Aktionen | Optionales Logging (z.B. `~/.ollama-manage.log`) |
| 11 | **Kein Konfigurationsfile** | Alle Einstellungen sind hartcodiert | Optionales Config-File (z.B. `~/.config/ollama-manage.conf`) |

### 3.3 Sicherheit

| # | Bereich | Problem | Empfehlung |
| --- | --------- | --------- | ------------ |
| 12 | **`sudo`-Passwort** | Keine Prüfung, ob der Benutzer `sudo`-Rechte hat | `sudo -n true` vorab prüfen und verständliche Meldung |
| 13 | **Installationsskript** | `curl ... \| sh` ist ein Sicherheitsrisiko (Supply-Chain) | Checksum-Prüfung oder manuelle Installation als Option anbieten |
| 14 | **API-Endpoint** | `http://localhost:11434` ist hartcodiert | Konfigurierbar machen (z.B. `OLLAMA_HOST`-Variable) |

### 3.4 Testabdeckung

| # | Bereich | Problem | Empfehlung |
| --- | --------- | --------- | ------------ |
| 15 | **Keine Tests für `pick_model()`** | Die fzf- und Text-Fallback-Logik ist nicht getestet | Tests für Modellauswahl mit fzf und nummerierter Liste |
| 16 | **Keine Tests für Validierung** | Modellnamen-Validierung (Regex) nicht getestet | Tests für gültige/ungültige Modellnamen |
| 17 | **Keine Tests für Duplikat-Erkennung** | Bereits installierte Modelle nicht getestet | Test, dass kein erneuter Download erfolgt |
| 18 | **Keine Tests für `stop_model()`** | API-Call und HTTP-Statuscode-Prüfung nicht getestet | Fake-`curl` erstellen und 200/Fehler-Fälle testen |
| 19 | **Keine Tests für `install_ollama()`** | Installationsskript-Ausführung nicht getestet | Fake-`curl` und `sh` für Installations-Tests |

### 3.5 Dokumentation

| # | Bereich | Problem | Empfehlung |
| --- | --------- | --------- | ------------ |
| 20 | **Keine CHANGELOG** | Versionshistorie fehlt | `CHANGELOG.md` mit Versions-Einträgen anlegen |
| 21 | **Keine CONTRIBUTING** | Keine Anleitung für Beiträge | `CONTRIBUTING.md` mit Entwicklungsrichtlinien |
| 22 | **Keine Man-Page** | Keine `man`-Seite für das Skript | `ollama-manage.1` erstellen |

---

## 4. Code-Review im Detail

### 4.1 `ollama-manage.sh`

**Positiv:**

- `set -euo pipefail` (Zeile 2) – exzellente Basis
- `have()` (Zeile 8) – sauberer Abhängigkeits-Check
- `require_ollama()` (Zeile 44) – zentrale Daemon-Prüfung
- `pick_model()` (Zeile 192) – intelligente Modus-Auswahl (Whiptail → fzf → Text)
- `pull_model()` (Zeile 247) – Fortschrittsanzeige mit `awk`-Prozentwert-Extraktion
- `stop_model()` (Zeile 412) – Live-Daten aus `ollama ps` mit HTTP-Statuscode-Prüfung
- `|| true` in allen Case-Zweigen – verhindert `set -e`-Abbrüche

**Verbesserungswürdig:**

- `show_list_whiptail()` (Zeile 171) und `show_list_text()` (Zeile 179) – Duplikation
- `remove_model()`, `run_model()`, `stop_model()` – wiederholte Modellauswahl-Logik
- `status_service()` (Zeile 86) – `return 0` im Fehlerfall ist ungewöhnlich (aber bewusst, um `set -e` zu umgehen)

### 4.2 `tests/test_ollama_manage.sh`

**Positiv:**

- Strukturierte Tests mit `print_header()` und `print_result()`
- Fake-Binaries für isolierte Tests
- Fehlerfall-Simulation mit PATH-Manipulation

**Verbesserungswürdig:**

- Tests prüfen hauptsächlich Exit-Codes und Menü-Rückkehr, nicht die tatsächliche Funktionslogik
- Keine Tests für `pick_model()`, Validierung, Duplikat-Erkennung, `stop_model()`, `install_ollama()`

---

## 5. Empfehlungen

### Kurzfristig (hohe Priorität)

1. **`curl`- und `sudo`-Prüfung** beim Start hinzufügen
2. **Duplikationen** in `show_list_*` und Modellauswahl-Logik reduzieren
3. **`OLLAMA_HOST`-Variable** für API-Endpoint konfigurierbar machen

### Mittelfristig (mittlere Priorität)

1. **Nicht-interaktiven Modus** für Skripting/Automatisierung hinzufügen
2. **Tests erweitern** für `pick_model()`, Validierung, Duplikat-Erkennung, `stop_model()`, `install_ollama()`
3. **CHANGELOG.md** anlegen

### Langfristig (niedrige Priorität)

1. **Konfigurationsdatei** für Einstellungen
2. **Logging** für Aktionen
3. **Man-Page** erstellen

---

## 6. Fazit

Das Projekt ist **sehr gut umgesetzt** und erfüllt seinen Zweck vollständig. Die Architektur ist sauber, die Fehlerbehandlung robust und die Testabdeckung solide. Die dokumentierten Verbesserungspotenziale sind überwiegend **Erweiterungen** und keine kritischen Fehler.

**Besonders hervorzuheben:**

- ✅ Exzellente Dual-Mode-UI (Whiptail + Text + fzf)
- ✅ Robuste Fehlerbehandlung mit `set -euo pipefail`
- ✅ Umfassende Testabdeckung (50 Tests)
- ✅ Gute Dokumentation (README, Screenshots, Lizenz)

**Nächste Schritte (empfohlen):**

1. Version 0.9 mit `curl`/`sudo`-Prüfung und `OLLAMA_HOST`-Unterstützung
2. Tests für die fehlenden Bereiche erweitern
3. CHANGELOG.md anlegen

---

*Review erstellt am 20. August 2026*
