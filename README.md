# Lernly

<img src="Lernly/Assets.xcassets/AppIcon.appiconset/AppIcon.png" alt="Lernly app icon" width="120" align="right">

Lernly is a lean learning app for iPhone. It is inspired by Duolingo but stripped down to a learning path, streaks and exercises, and nothing else.

What makes it different: **the app ships without any courses.** You create a course (e.g. "Physics") and import your own study material as **`.lernly` files**. Any AI can generate these files from your worksheets, formula sheets or notes. When new material for the same course comes along, you import another file. Its chapters are appended to the end of the course, and your progress is kept.

## Features

- **Learning path:** chapters with lessons along a winding path. Lessons unlock one after another within a chapter; every chapter is open on its own.
- **Streaks and XP:** one lesson per day keeps your streak alive. There is also an adjustable daily goal, a weekly overview and your longest streak.
- **8 exercise types:** single choice, multiple choice, true/false, free text (tolerates typos), cloze with a word bank, ordering, matching pairs and flashcards.
- **Lesson flow:** short theory cards first, then the exercises. Wrong answers come back at the end of the lesson.
- **Three ways to import:** file picker, "Open in Lernly" (e.g. via AirDrop), or simply pasting the JSON. The app shows a preview before importing and detects chapters that already exist. Broken files are reported with a precise list of errors that you can copy and hand back to the AI.
- **AI template inside the app:** under *Profil → Einstellungen → Dateiformat & KI-Vorlage* (Profile → Settings → File format & AI template), with a ready-to-use prompt and a cheat sheet you can screenshot.

The app's interface is in German.

## Requirements

- Xcode 27.2 or later
- iPhone or iPad running iOS 27.2 or later

## Build and run

1. Open `Lernly.xcodeproj` in Xcode.
2. Under *Target Lernly → Signing & Capabilities*, select your own **Team**. A free Personal Team is enough.
3. If Xcode reports that the bundle ID is already taken, change `com.davidmitrovic.Lernly` to an ID of your own.
4. Select your iPhone as the run destination and click **▶︎ Run**.

With a free Personal Team, the installed app expires after 7 days. Just install it again from Xcode; your data is kept.

## The `.lernly` format

A `.lernly` file is JSON with its own file extension:

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

| `type` | fields |
|---|---|
| `single_choice` | `question`, `options`, `answer` (0-based index) |
| `multiple_choice` | `question`, `options`, `answers` (indices) |
| `true_false` | `statement`, `answer` (`true`/`false`) |
| `input` | `question`, `answers` (every accepted spelling) |
| `cloze` | `text` with `{{gap}}`, `distractors` |
| `order` | `question`, `items` (in the correct order) |
| `match` | `question`, `pairs` (`[["left", "right"], …]`) |
| `flashcard` | `front`, `back` |

Every exercise can also have an `explanation`. A complete example is in [`Beispiele/Physik-Beispiel.lernly`](Beispiele/Physik-Beispiel.lernly). The full specification is in [`.claude/skills/lernly-course/references/format.md`](.claude/skills/lernly-course/references/format.md).

### Converting study material with an AI

- **Any chat AI (ChatGPT, Gemini, Claude …):** copy the prompt from *Einstellungen → Dateiformat & KI-Vorlage* in the app, attach your study material and import the answer.
- **Coding agents (Claude Code, Codex …):** the [`lernly-course`](.claude/skills/lernly-course/SKILL.md) skill describes the whole workflow. It comes with a builder (`scripts/lernly_builder.py`) and a validator that checks a file with the same rules as the app:

  ```bash
  python3 .claude/skills/lernly-course/scripts/validate_lernly.py my-course.lernly
  ```

## Project structure

```
Lernly/
├── App/            app entry point and tab navigation
├── Models/         data model, storage (AppStore), .lernly parser, AI template
├── Design/         colors, buttons, layouts
├── Views/
│   ├── Learn/      learning path and chapter banners
│   ├── Lesson/     lesson flow and all exercise types
│   ├── Courses/    course management
│   ├── Import/     import preview and error display
│   └── Profile/    streak, statistics, settings
Lernly-Info.plist   registers the .lernly file type
Beispiele/          example course file
Design/             app icon generator
.claude/skills/     "lernly-course" skill for AI agents
AGENTS.md           notes for AI agents
```

All data is stored locally on the device as JSON in the *Application Support* folder. There is no server and no account.
