# Lernly

<img src="Lernly/Assets.xcassets/AppIcon.appiconset/AppIcon.png" alt="Lernly App-Icon" width="120" align="right">

Lernly ist eine schlanke Lern-App für das iPhone, inspiriert von Duolingo, aber ohne Ballast: Lernpfad, Streaks und Übungen, sonst nichts.

Die Besonderheit: **Die App enthält keine Kurse.** Du legst einen Kurs an (z. B. „Physik“) und importierst deinen eigenen Lernstoff als **`.lernly`-Datei**. Diese Dateien lässt du dir von einer beliebigen KI aus deinen Arbeitsblättern, Formelzetteln oder Notizen erstellen. Kommt neuer Stoff für denselben Kurs dazu, importierst du einfach eine weitere Datei. Die neuen Kapitel werden unten an den Kurs angehängt, dein Fortschritt bleibt erhalten.

## Funktionen

- **Lernpfad:** Kapitel mit Lektionen auf einem geschwungenen Pfad. Innerhalb eines Kapitels werden die Lektionen nacheinander freigeschaltet, jedes Kapitel ist für sich offen.
- **Streaks und XP:** Eine Lektion pro Tag hält den Streak. Dazu gibt es ein einstellbares Tagesziel, eine Wochenübersicht und den längsten Streak.
- **8 Übungstypen:** Single Choice, Multiple Choice, Wahr/Falsch, Freitext (mit Toleranz für Tippfehler), Lückentext mit Wortauswahl, Reihenfolge, Paare zuordnen und Karteikarten.
- **Lektionsablauf:** Zuerst kommen kurze Theorie-Karten, dann die Übungen. Falsche Antworten werden am Ende der Lektion wiederholt.
- **Drei Wege zum Import:** Dateiauswahl, „Öffnen in Lernly“ (z. B. per AirDrop) oder JSON einfach einfügen. Vor dem Import zeigt die App eine Vorschau und erkennt Kapitel, die es schon gibt. Fehlerhafte Dateien meldet sie mit genauer Fehlerliste, die man sich kopieren und der KI zurückgeben kann.
- **KI-Vorlage in der App:** unter *Profil → Einstellungen → Dateiformat & KI-Vorlage*, mit fertigem Prompt und einem Spickzettel zum Abfotografieren.

## Voraussetzungen

- Xcode 27.2 oder neuer
- iPhone oder iPad mit iOS 27.2 oder neuer

## App bauen und starten

1. `Lernly.xcodeproj` in Xcode öffnen.
2. Unter *Target Lernly → Signing & Capabilities* dein eigenes **Team** wählen. Ein kostenloses Personal Team reicht.
3. Falls Xcode meldet, dass die Bundle-ID schon vergeben ist, `com.davidmitrovic.Lernly` in eine eigene ID ändern.
4. Das iPhone als Ziel auswählen und auf **▶︎ Run** klicken.

Mit einem kostenlosen Personal Team läuft die installierte App nach 7 Tagen ab. Dann einfach erneut aus Xcode installieren. Die Daten bleiben erhalten.

## Das `.lernly`-Format

Eine `.lernly`-Datei ist JSON mit eigener Dateiendung:

```json
{
  "lernly": 1,
  "course": "Physik",
  "chapters": [{
    "title": "Gleichförmige Bewegung",
    "description": "v = konstant",
    "icon": "speedometer",
    "lessons": [{
      "title": "Einheiten",
      "theory": [{ "title": "Merke", "text": "**km/h → m/s:** durch 3,6 teilen" }],
      "exercises": [
        { "type": "single_choice", "question": "Wie viel sind 72 km/h?", "options": ["20 m/s", "259 m/s"], "answer": 0 },
        { "type": "cloze", "text": "Es gilt s = {{v}} · t.", "distractors": ["a"] }
      ]
    }]
  }]
}
```

| `type` | Felder |
|---|---|
| `single_choice` | `question`, `options`, `answer` (Index ab 0) |
| `multiple_choice` | `question`, `options`, `answers` (Indizes) |
| `true_false` | `statement`, `answer` (`true`/`false`) |
| `input` | `question`, `answers` (alle akzeptierten Schreibweisen) |
| `cloze` | `text` mit `{{Lücke}}`, `distractors` |
| `order` | `question`, `items` (in richtiger Reihenfolge) |
| `match` | `question`, `pairs` (`[["links", "rechts"], …]`) |
| `flashcard` | `front`, `back` |

Jede Übung kann zusätzlich eine `explanation` haben. Ein vollständiges Beispiel liegt in [`Beispiele/Physik-Beispiel.lernly`](Beispiele/Physik-Beispiel.lernly). Die komplette Spezifikation steht in [`.claude/skills/lernly-course/references/format.md`](.claude/skills/lernly-course/references/format.md).

### Lernstoff mit einer KI umwandeln

- **Beliebige KI (ChatGPT, Gemini, Claude …):** In der App unter *Einstellungen → Dateiformat & KI-Vorlage* den Prompt kopieren, deinen Lernstoff anhängen und die Antwort importieren.
- **Coding-Agents (Claude Code, Codex …):** Der Skill [`lernly-course`](.claude/skills/lernly-course/SKILL.md) beschreibt den ganzen Ablauf und bringt einen Builder (`scripts/lernly_builder.py`) und einen Validator mit. Der Validator prüft eine Datei mit denselben Regeln wie die App:

  ```bash
  python3 .claude/skills/lernly-course/scripts/validate_lernly.py meine-datei.lernly
  ```

## Projektstruktur

```
Lernly/
├── App/            App-Einstieg und Tab-Navigation
├── Models/         Datenmodell, Speicherung (AppStore), Parser für .lernly, KI-Vorlage
├── Design/         Farben, Buttons, Layouts
├── Views/
│   ├── Learn/      Lernpfad und Kapitel-Kacheln
│   ├── Lesson/     Lektionsablauf und alle Übungstypen
│   ├── Courses/    Kurse verwalten
│   ├── Import/     Import-Vorschau und Fehleranzeige
│   └── Profile/    Streak, Statistik, Einstellungen
Lernly-Info.plist   Registrierung des Dateityps .lernly
Beispiele/          Beispiel-Kursdatei
Design/             Generator für das App-Icon
.claude/skills/     Skill „lernly-course“ für KI-Agents
AGENTS.md           Hinweise für KI-Agents
```

Die Daten liegen lokal auf dem Gerät als JSON im Ordner *Application Support*. Es gibt keinen Server und kein Konto.
