# .lernly format reference (version 1)

The source of truth is the app's importer, `Lernly/Models/LernlyFormat.swift` (`LernlyParser`). This document describes exactly what it accepts.

## Contents
1. File and encoding
2. Top level
3. Chapter
4. Lesson and theory
5. Exercise types (all fields and aliases)
6. How answers are checked in the app
7. Import behaviour
8. Error messages

## 1. File and encoding
- UTF-8 JSON, extension `.lernly` (`.json` and `.txt` are accepted as well).
- The app is tolerant on import: it strips Markdown code fences (```` ``` ````), ignores text before the first `{` and after the last `}`, allows JSON5 (comments, trailing commas) and replaces typographic quotes “ ” in an emergency. Still, generate strict JSON.

## 2. Top level
| field | type | required | meaning |
|---|---|---|---|
| `lernly` | int | no | format version, currently `1`. Higher versions produce a warning only |
| `course` | string | recommended | course name; the import dialog preselects the course with this name, or offers to create it |
| `chapters` | array | **yes** | at least 1 chapter |

## 3. Chapter
| field | required | notes |
|---|---|---|
| `title` | **yes** | used for duplicate detection (case-insensitive) |
| `description` (alias `summary`) | no | shown on the chapter banner, at most 2 lines |
| `icon` | no | SF Symbol name; invalid names are ignored |
| `lessons` | **yes** | at least 1 |

## 4. Lesson and theory
| field | required | notes |
|---|---|---|
| `title` | no (fallback "Lektion n") | |
| `theory` | no | a string, a list of strings, or a list of `{ "title"?, "text" }` (alias `content`) |
| `exercises` | no* | *a lesson needs `theory` or `exercises`; theory only produces a warning |

Theory cards appear before the exercises, one card per page. Inline Markdown works (`**bold**`, `*italic*`, `` `code` ``), and `\n` makes a line break.

## 5. Exercise types
Every exercise: `type` (required) and `explanation` (optional, shown after answering). The type is matched case-insensitively, and `-` / spaces count as `_`.

### single_choice
Aliases: `choice`, `multiple_choice_single`, `mc`, `quiz`
- `question` (alias `prompt`), `options` (≥ 2 strings)
- `answer`: 0-based index **or** the exact text of an option (case-insensitive)
- The app shuffles the options, so the position of the correct answer does not matter.

### multiple_choice
Aliases: `multi_choice`, `multiple_select`, `multi_select`
- `question`, `options` (≥ 2), `answers` (alias `answer` as a list): indices or option texts, at least 1.
- Counts as correct only if the selected set matches exactly.

### true_false
Aliases: `truefalse`, `tf`, `bool`, `boolean`
- `statement` (or `question`), `answer`: `true`/`false` (also "wahr"/"falsch", "ja"/"nein" as strings)

### input
Aliases: `text`, `free_text`, `short_answer`, `type`
- `question`, `answers` (alias `answer`): a string or a list. Numbers are converted to text.

### cloze
Aliases: `gap`, `fill_blank`, `fill_in_the_blank`, `gaps`
- `text` with at least one gap `{{solution}}`; `distractors` (optional) adds wrong words to the word bank.
- The word bank holds all gap solutions plus the distractors, shuffled. Gaps may contain several words (`{{freier Fall}}`).
- Text is split into words at spaces, so a gap followed directly by punctuation (`{{Newton}}.`) shows the punctuation as its own token. That is fine.

### order
Aliases: `ordering`, `sort`, `sequence`
- `question`, `items` (≥ 2) in the **correct** order. The app shuffles them, and the learner taps them into sequence.

### match
Aliases: `matching`, `pairs`
- `question` (optional, default "Finde die Paare"), `pairs` (≥ 2) as `[["left", "right"], …]` or `[{"left": …, "right": …}]`
- All left values must be distinct, and all right values must be distinct. 3–5 pairs fit on screen best.
- Matched by tapping. Wrong taps cost accuracy, and the exercise still ends as solved.

### flashcard
Aliases: `card`, `flash_card`
- `front` (or `question`), `back` (or `answer`). The learner flips the card and rates "Gewusst" or "Nicht gewusst". A card marked "Nicht gewusst" comes back at the end of the lesson.

## 6. How answers are checked in the app
- **input**: normalised = lowercased, `,` → `.`, whitespace collapsed, trailing `.!?;:` removed. Exact match against any entry in `answers`.
  - Typo tolerance: only when the expected answer contains **no digits** and has ≥ 5 characters. Levenshtein distance ≤ 1, or ≤ 2 from 10 characters on. The app then shows "Kleiner Tippfehler".
  - Units are part of the text, so "9,81" ≠ "9,81 m/s²". Either list both spellings or say "nur die Zahl" in the question.
- **cloze**: a word in a gap is correct if its normalised form equals the gap solution.
- Wrong answers are queued again at the end of the lesson (Duolingo style). Accuracy = share of exercises solved on the first try. Perfect lesson = 15 XP, otherwise 10 XP.

## 7. Import behaviour
- Before importing, the user picks the target course (existing or new) and can deselect individual chapters.
- A chapter whose title already exists in the target course is marked "Existiert schon im Kurs" and **deselected** by default.
- Selected chapters are **appended** to the end of the course in file order. Existing progress is kept.
- Within a chapter, lessons unlock one after another. Every chapter's first lesson is always open.

## 8. Error messages
If something is wrong, the app shows a list such as:
```
Kapitel 2 „Kräfte“ › Lektion 1 › Übung 3 (single_choice): "answer" muss ein Index von 0 bis 3 oder der Text einer Option sein.
```
Users can copy these messages with "Fehler für KI kopieren" and paste them back to the AI. When that happens, fix exactly the reported places and output the **complete** file again.
