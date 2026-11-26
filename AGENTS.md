# Lernly – Hinweise für Agents

Lernly ist eine SwiftUI-iPhone-App (Xcode-Projekt `Lernly.xcodeproj`, Quellcode in `Lernly/`).

## Lerninhalte (.lernly-Dateien) erstellen

Willst du aus Lernstoff (Arbeitsblätter, Formelzettel, Notizen, PDFs) eine importierbare `.lernly`-Datei machen, folge dem Skill in
[`.claude/skills/lernly-course/SKILL.md`](.claude/skills/lernly-course/SKILL.md). Dort findest du:

- den Ablauf: Material lesen, Struktur planen, Zahlen per Code nachrechnen, Datei erzeugen, validieren
- `scripts/lernly_builder.py`: Hilfsfunktionen, die gültiges JSON erzeugen
- `scripts/validate_lernly.py`: prüft eine Datei mit denselben Regeln wie der Import der App
- `references/format.md`: die vollständige Formatbeschreibung

Maßgeblich für das Format ist der Parser `Lernly/Models/LernlyFormat.swift`. Wenn du dort etwas änderst, passe auch den Skill, den Validator und `Lernly/Models/LernlySpec.swift` (die KI-Vorlage in der App) an.

Fertige Kursdateien liegen in `Kurse/`.
