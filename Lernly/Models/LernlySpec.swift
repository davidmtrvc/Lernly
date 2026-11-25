import Foundation

/// Beschreibung des .lernly-Formats für KIs (in den Einstellungen unter "Dateiformat & KI-Vorlage").
nonisolated enum LernlySpec {
    static let cheatSheet = #"""
{
  "lernly": 1,
  "course": "Physik",
  "chapters": [{
    "title": "Kapitelname",
    "description": "optional, 1 Satz",
    "icon": "atom",             ← optional, SF-Symbol
    "lessons": [{
      "title": "Lektionsname",
      "theory": [
        { "title": "Merke", "text": "Kurz, **fett** ok" }
      ],
      "exercises": [ { "type": "…", … } ]
    }]
  }]
}

ÜBUNGSTYPEN (jede optional mit "explanation")
single_choice    question, options[], answer: 0
multiple_choice  question, options[], answers: [0,2]
true_false       statement, answer: true|false
input            question, answers: ["9,81","9.81"]
cloze            text: "F = {{m}} · {{a}}",
                 distractors: ["v"]
order            question, items[] ← richtige Reihenf.
match            question, pairs: [["F","Kraft"],…]
flashcard        front, back

Indizes starten bei 0 · Formeln in Unicode (², ·, Δ, √)
Neue Datei = neue Kapitel, werden unten angehängt
"""#

    static let prompt = #"""
Du erstellst Lerninhalte für meine Lern-App „Lernly“. Wandle meinen Lernstoff (unten) in eine .lernly-Datei um.

AUSGABE
- Antworte NUR mit gültigem JSON in einem einzigen Codeblock – kein Text davor oder danach.
- Die Datei ist JSON mit der Endung .lernly (UTF-8).

AUFBAU
- Jedes Kapitel/Thema meines Lernstoffs wird ein Eintrag in "chapters" – in derselben Reihenfolge.
- Teile jedes Kapitel in 2–6 Lektionen, die aufeinander aufbauen (vom Grundlegenden zum Schwierigen).
- Jede Lektion hat 1–3 kurze Theorie-Karten ("theory") mit dem Wichtigsten und danach 5–8 Übungen.
- Decke ALLE prüfungsrelevanten Inhalte ab: Definitionen, Formeln, Einheiten, Zusammenhänge, typische Fehler.
- Mische die Übungstypen. Erfinde nichts, was nicht im Lernstoff steht oder fachlich falsch ist.
- "explanation" erklärt in 1–2 Sätzen, warum die Lösung stimmt.
- Formeln als Unicode schreiben (z. B. v = s / t, E = m · c², Δx, √2, ≈), kein LaTeX.
- Erlaubte Hervorhebungen im Text: **fett**, *kursiv*, `code`.

FORMAT
{
  "lernly": 1,
  "course": "<Kursname, z. B. Physik>",
  "chapters": [
    {
      "title": "<Kapitelname>",
      "description": "<optional, ein Satz>",
      "icon": "<optional: SF-Symbol-Name, z. B. atom, bolt.fill, function>",
      "lessons": [
        {
          "title": "<Lektionsname>",
          "theory": [ { "title": "<optional>", "text": "<kurze Erklärung>" } ],
          "exercises": [ <Übungen, siehe unten> ]
        }
      ]
    }
  ]
}

ÜBUNGSTYPEN (alle Indizes beginnen bei 0)
1. Single Choice – genau eine Antwort richtig:
   { "type": "single_choice", "question": "…", "options": ["A", "B", "C", "D"], "answer": 2, "explanation": "…" }
2. Multiple Choice – mehrere richtig:
   { "type": "multiple_choice", "question": "…", "options": ["A", "B", "C", "D"], "answers": [0, 3], "explanation": "…" }
3. Wahr/Falsch:
   { "type": "true_false", "statement": "…", "answer": false, "explanation": "…" }
4. Freitext – kurze Antwort, alle akzeptierten Schreibweisen angeben:
   { "type": "input", "question": "…", "answers": ["9,81 m/s²", "9.81 m/s²", "9,81"], "explanation": "…" }
5. Lückentext – Lücken mit {{Lösung}}, dazu 1–3 falsche Wörter als Ablenkung:
   { "type": "cloze", "text": "Die Einheit der Kraft ist {{Newton}}.", "distractors": ["Joule", "Watt"], "explanation": "…" }
6. Reihenfolge – Items in der RICHTIGEN Reihenfolge angeben (die App mischt):
   { "type": "order", "question": "…", "items": ["Erster Schritt", "Zweiter Schritt", "Dritter Schritt"] }
7. Paare zuordnen – 3–5 Paare, jede Seite eindeutig:
   { "type": "match", "question": "Ordne zu", "pairs": [["F", "Kraft"], ["m", "Masse"], ["a", "Beschleunigung"]] }
8. Karteikarte – zum Selbst-Abfragen:
   { "type": "flashcard", "front": "Was besagt das 3. Newtonsche Gesetz?", "back": "actio = reactio …" }

WICHTIG
- Wenn ich später neuen Stoff für denselben Kurs schicke, gib nur die NEUEN Kapitel aus (gleicher "course"-Name). Die App hängt sie unten an.
- Prüfe vor der Ausgabe: gültiges JSON, alle Indizes im gültigen Bereich, jeder Lückentext enthält {{…}}.

MEIN LERNSTOFF:
"""#

    static let example = #"""
{
  "lernly": 1,
  "course": "Physik",
  "chapters": [
    {
      "title": "Kräfte und Bewegung",
      "description": "Newtonsche Gesetze und gleichförmige Bewegung",
      "icon": "arrow.right.circle.fill",
      "lessons": [
        {
          "title": "Geschwindigkeit",
          "theory": [
            { "title": "Merke", "text": "Die **Geschwindigkeit** gibt an, welche Strecke in einer bestimmten Zeit zurückgelegt wird: v = s / t. Einheit: m/s." }
          ],
          "exercises": [
            { "type": "single_choice", "question": "Ein Auto fährt 100 m in 5 s. Wie schnell ist es?", "options": ["5 m/s", "20 m/s", "500 m/s", "0,05 m/s"], "answer": 1, "explanation": "v = s / t = 100 m / 5 s = 20 m/s." },
            { "type": "input", "question": "Wie viele m/s sind 36 km/h?", "answers": ["10", "10 m/s"], "explanation": "Teile km/h durch 3,6: 36 / 3,6 = 10 m/s." },
            { "type": "true_false", "statement": "Die SI-Einheit der Geschwindigkeit ist km/h.", "answer": false, "explanation": "Die SI-Einheit ist m/s." },
            { "type": "cloze", "text": "Die Geschwindigkeit ist {{Strecke}} geteilt durch {{Zeit}}.", "distractors": ["Masse", "Kraft"] }
          ]
        },
        {
          "title": "Newtons Gesetze",
          "theory": [
            { "title": "Grundgleichung", "text": "Kraft = Masse · Beschleunigung, also **F = m · a**. Einheit: Newton (N)." }
          ],
          "exercises": [
            { "type": "match", "question": "Ordne die Formelzeichen zu", "pairs": [["F", "Kraft"], ["m", "Masse"], ["a", "Beschleunigung"]] },
            { "type": "multiple_choice", "question": "Welche Aussagen sind richtig?", "options": ["1 N = 1 kg · m/s²", "Kraft ist eine Vektorgröße", "Masse wird in Newton gemessen"], "answers": [0, 1], "explanation": "Masse wird in kg gemessen." },
            { "type": "order", "question": "Sortiere die Gesetze nach ihrer Nummer", "items": ["Trägheitsprinzip", "Aktionsprinzip (F = m · a)", "Wechselwirkungsprinzip"] },
            { "type": "flashcard", "front": "Was besagt das 3. Newtonsche Gesetz?", "back": "Actio = Reactio: Jede Kraft erzeugt eine gleich große Gegenkraft." }
          ]
        }
      ]
    }
  ]
}
"""#
}
