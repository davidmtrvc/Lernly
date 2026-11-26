---
name: lernly-course
description: Create .lernly course files (JSON) for the Lernly iOS learning app from study material such as worksheets, formula sheets, lecture notes, scanned PDFs or photos. Use this whenever the user wants to turn study or test material into Lernly chapters, lessons and exercises, add new chapters to an existing Lernly course, update or fix a .lernly file, or asks for a "Lernly-Datei", ".lernly", "Lektionen für meine App" or "Übungen zum Importieren" – even if they only say something like "mach mir daraus was zum Lernen für den Test".
---

# Creating .lernly course files

Lernly is a Duolingo-style iPhone app that ships without content. Users create an empty course (e.g. "Physik") and import `.lernly` files. Every chapter in a file becomes a section of the learning path, and imported chapters are **appended** to the end of the course. A `.lernly` file is plain UTF-8 JSON with a custom extension.

Your goal is a file that (1) imports without errors and (2) actually prepares the learner for their test: correct answers, good coverage, sensible difficulty.

## Workflow

1. **Read all material completely.** Worksheets often contain the teacher's solutions in brackets – use them to cross-check your own results. Scanned PDFs usually have no text layer: if text extraction returns nothing, render the pages to images and read those. Handwritten notes can hold the learner's own mistakes; point these out (see step 6).
2. **Plan the structure** before writing anything:
   - Chapters follow the topics of the material in teaching order (a formula sheet's headings are a good skeleton).
   - 2–6 lessons per chapter, building from basics to harder problems. Each lesson has 1–3 short theory cards and about 6–12 exercises.
   - Optionally add a final "Testtraining" chapter with mixed exam-style problems, typical pitfalls and flashcards of every formula.
3. **Compute every numeric answer with code** (for example a short Python script), never in your head. Compare the results with any solutions on the sheet. If they disagree, recheck. If the sheet is wrong, use the correct value and say so in the `explanation`.
4. **Generate the file with `scripts/lernly_builder.py`** instead of typing JSON by hand. The builder gives you one helper function per exercise type and writes valid JSON. See "Using the builder" below.
5. **Validate** with `python3 scripts/validate_lernly.py <file>`. It applies the same rules as the app's importer and prints statistics. Fix every error and re-run it until it passes.
6. **Report to the user**: the number of chapters, lessons and exercises, where the file is, how to import it, and any errors you found in the material or in their own solutions.

## Format at a glance

```json
{
  "lernly": 1,
  "course": "Physik",
  "chapters": [{
    "title": "Gleichförmige Bewegung",
    "description": "optional, one sentence",
    "icon": "arrow.right.circle.fill",
    "lessons": [{
      "title": "Einheiten & s = v · t",
      "theory": [{ "title": "Merke", "text": "**s = v · t** …" }],
      "exercises": [
        { "type": "single_choice", "question": "…", "options": ["A", "B", "C", "D"], "answer": 1, "explanation": "…" }
      ]
    }]
  }]
}
```

| type | required fields | notes |
|---|---|---|
| `single_choice` | `question`, `options` (≥2), `answer` | 0-based index; the app shuffles the options |
| `multiple_choice` | `question`, `options`, `answers` | list of 0-based indices |
| `true_false` | `statement`, `answer` | `true` / `false` |
| `input` | `question`, `answers` | list of every accepted spelling |
| `cloze` | `text` with `{{gap}}`, optional `distractors` | gaps are filled from a word bank |
| `order` | `question`, `items` (≥2) | items in the **correct** order; the app shuffles them |
| `match` | `question`, `pairs` (≥2) | `[["left", "right"], …]`, each side unique |
| `flashcard` | `front`, `back` | the learner rates themself |

All types accept an optional `explanation`, which is shown after answering. The full specification, including the validation rules and tolerated aliases, is in `references/format.md`. Read it when you need edge-case details.

## What makes a good Lernly file

**Answers must match how the app checks them.** For `input`, the app lowercases the text, treats `,` and `.` as equal, collapses whitespace and ignores trailing punctuation. Small typos are tolerated only for non-numeric answers with at least 5 characters, and numbers must match exactly. Units are compared as text too, so "27,8" ≠ "27,8 m". That is why numeric input questions work best when they say exactly what to type, e.g. *"(in m, nur die Zahl, 1 Nachkommastelle)"*, and `answers` lists the reasonable roundings: `["27,8", "27,78"]`. If many answer formats are plausible, use `single_choice` instead.

**Distractors should be real mistakes.** For calculation questions, build wrong options from typical errors: forgetting the ÷3.6 conversion, using the diameter instead of the radius, the arithmetic mean instead of total distance ÷ total time, s(4) instead of s(4) − s(3). This trains exactly what the test checks. Avoid joke options and "all of the above".

**Mix the types.** A good lesson combines calculations (single choice and input) with conceptual checks (true/false, cloze, match) and at least one structural task (order the solution steps, match formulas to their meaning). Use flashcards for definitions and formulas that must be memorised.

**Keep theory short.** Theory cards summarise only what the following exercises need: formulas, units and a common trap. Inline Markdown works: `**bold**`, `*italic*` and `` `code` ``. Use `\n` for line breaks.

**Write formulas in Unicode, not LaTeX.** For example `v = s / t`, `a = Δv / Δt`, `½ · g · t²`, `ω²`, `√(2 · g · h)`, `10⁻⁴`, `≈`, `°`, `π`. The app does not render LaTeX.

**Reference the source in explanations**, e.g. `"(AB 3.1, Nr. 5b)"`. This lets the learner find the original problem in their notes.

**Write in the language of the material.** For this user that is usually German.

## Adding to an existing course

When the user already has a course and brings new material (a new test, a new worksheet):

- Output **only the new chapters** and use the same `"course"` name. The app appends them at the bottom.
- The app detects duplicates by chapter **title**. A chapter whose title already exists in the course is deselected by default on import. Give new chapters distinct titles.
- If you regenerate a file the user has already imported, tell them to delete the old chapters first (Kurse → course → swipe left on a chapter), otherwise the new version is treated as a duplicate.

## Using the builder

`scripts/lernly_builder.py` contains small helper functions. Write a generator script in a scratch location, import the builder and save the result:

```python
import sys; sys.path.insert(0, "<skill-dir>/scripts")
from lernly_builder import *

chapters = [
    chapter("Freier Fall", "g ≈ 9,81 m/s²", "arrow.down.circle.fill", [
        lesson("Grundlagen", [th("Formeln", "**v = g · t**\n**s = ½ · g · t²**")], [
            inp("Geschwindigkeit nach 2 s? (in m/s, nur die Zahl)", ["19,62", "19,6"], "v = 9,81 · 2 = 19,62 m/s"),
            sc("Weg zwischen 3. und 4. Sekunde?", ["34,3 m", "78,5 m", "44,1 m", "9,81 m"], 0, "s(4) − s(3) = 34,3 m"),
            tf("Schwere Körper fallen ohne Luftwiderstand schneller.", False, "Alle fallen gleich schnell."),
        ]),
    ]),
]
write_course("Physik", chapters, "/path/to/Physik-Test.lernly")
```

`write_course` prints a summary. Run the validator afterwards anyway, because it also catches content problems such as out-of-range indices or cloze texts without gaps.

## Chapter icons

`icon` takes an optional SF Symbol name. Unknown names are ignored silently. The banner draws its own ring around the icon and drops a `.circle` / `.circle.fill` suffix when possible. Safe choices include `atom`, `function`, `sum`, `speedometer`, `bolt.fill`, `flask.fill`, `leaf.fill`, `globe.europe.africa.fill`, `book.fill`, `brain.head.profile`, `chart.bar.fill`, `clock.fill`, `ruler.fill`, `arrow.right.circle.fill`, `arrow.down.circle.fill`, `arrow.down.right.circle.fill`, `arrow.triangle.2.circlepath`, `checkmark.seal.fill`, `lightbulb.fill`, `text.book.closed.fill`, `character.book.closed.fill`, `cpu.fill`, `building.columns.fill`.

## Delivering the file

Save the file with a descriptive name such as `Physik-Test-Bewegungslehre.lernly` in a place the user can reach. In the Lernly repository, `Kurse/` is used for this. If a file-sending tool is available, send the file to the user. To import, the user AirDrops the file to the iPhone and opens it with Lernly, or saves it in the Files app and taps **Datei importieren** in the course. Pasting the JSON via **Text einfügen** also works.
