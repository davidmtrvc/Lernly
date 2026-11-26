#!/usr/bin/env python3
"""Validate a .lernly file with the same rules as the Lernly app importer
(Lernly/Models/LernlyFormat.swift). Exit code 0 = importable, 1 = errors.

Usage: python3 validate_lernly.py <file.lernly> [--quiet]

The app is a bit more forgiving than this script (it also accepts code fences,
comments and trailing commas). The script expects strict JSON on purpose, so
generated files are always clean.
"""
import json
import re
import sys
from collections import Counter

TYPE_ALIASES = {
    "single_choice": ["single_choice", "choice", "multiple_choice_single", "mc", "quiz"],
    "multiple_choice": ["multiple_choice", "multi_choice", "multiple_select", "multi_select"],
    "true_false": ["true_false", "truefalse", "tf", "bool", "boolean"],
    "input": ["input", "text", "free_text", "short_answer", "type"],
    "cloze": ["cloze", "gap", "fill_blank", "fill_in_the_blank", "gaps"],
    "order": ["order", "ordering", "sort", "sequence"],
    "match": ["match", "matching", "pairs"],
    "flashcard": ["flashcard", "card", "flash_card"],
}
ALIAS = {alias: canonical for canonical, aliases in TYPE_ALIASES.items() for alias in aliases}
GAP = re.compile(r"\{\{(.+?)\}\}")


def s(value):
    """Non-empty trimmed string (numbers allowed, like the app)."""
    if isinstance(value, bool):
        return None
    if isinstance(value, (int, float)):
        return str(value)
    if isinstance(value, str) and value.strip():
        return value.strip()
    return None


def strings(value):
    if s(value) is not None:
        return [s(value)]
    if not isinstance(value, list):
        return None
    result = [s(v) for v in value]
    return None if not result or None in result else result


def index_in(value, options):
    if isinstance(value, bool):
        return None
    if isinstance(value, int):
        return value if 0 <= value < len(options) else None
    text = s(value)
    if text is not None:
        for i, option in enumerate(options):
            if option.lower() == text.lower():
                return i
        if text.isdigit() and int(text) < len(options):
            return int(text)
    return None


def to_bool(value):
    if isinstance(value, bool):
        return value
    if isinstance(value, str):
        v = value.strip().lower()
        if v in ("true", "wahr", "richtig", "ja", "yes"):
            return True
        if v in ("false", "falsch", "nein", "no"):
            return False
    return None


def check_exercise(e, path, errors, warnings):
    if not isinstance(e, dict):
        errors.append(f"{path}: muss ein Objekt {{ … }} sein.")
        return None
    raw_type = (s(e.get("type")) or "").lower().replace("-", "_").replace(" ", "_")
    kind = ALIAS.get(raw_type)
    path = f"{path} ({raw_type or 'ohne type'})"
    question = s(e.get("question")) or s(e.get("prompt"))

    def need(value, field):
        if value is None:
            errors.append(f'{path}: "{field}" fehlt oder ist ungültig.')
        return value

    if kind is None:
        errors.append(f'{path}: unbekannter "type". Erlaubt: {", ".join(TYPE_ALIASES)}.')
        return None
    if kind in ("single_choice", "multiple_choice"):
        if need(question, "question") is None or need(strings(e.get("options")), "options") is None:
            return None
        options = strings(e["options"])
        if len(options) < 2:
            errors.append(f'{path}: mindestens 2 "options" nötig.')
            return None
        if len(set(o.lower() for o in options)) != len(options):
            warnings.append(f"{path}: doppelte Antwortoptionen.")
        if kind == "single_choice":
            if index_in(e.get("answer"), options) is None:
                errors.append(f'{path}: "answer" muss ein Index von 0 bis {len(options) - 1} oder der Text einer Option sein.')
        else:
            raw = e.get("answers", e.get("answer"))
            raw = raw if isinstance(raw, list) else []
            if not raw or any(index_in(a, options) is None for a in raw):
                errors.append(f'{path}: "answers" muss eine Liste gültiger Indizes (0 bis {len(options) - 1}) sein.')
    elif kind == "true_false":
        need(s(e.get("statement")) or question, "statement")
        need(to_bool(e.get("answer")), "answer (true/false)")
    elif kind == "input":
        need(question, "question")
        answers = need(strings(e.get("answers")) or strings(e.get("answer")), "answer")
        if answers and any(re.search(r"\d", a) for a in answers) and not re.search(r"nur die (zahl|nummer|kontonummer)", (question or "").lower()):
            warnings.append(f'{path}: numerische Antwort – sag in der Frage, was eingegeben werden soll (z. B. "nur die Zahl, in m").')
    elif kind == "cloze":
        text = need(s(e.get("text")), "text")
        if text is not None and not GAP.search(text):
            errors.append(f'{path}: "text" braucht mindestens eine Lücke im Format {{{{Wort}}}}.')
    elif kind == "order":
        need(question, "question")
        items = need(strings(e.get("items")), "items")
        if items is not None and len(items) < 2:
            errors.append(f'{path}: mindestens 2 "items" nötig.')
    elif kind == "match":
        pairs = e.get("pairs")
        if not isinstance(pairs, list):
            errors.append(f'{path}: "pairs" fehlt oder ist ungültig.')
            return None
        parsed = []
        for p in pairs:
            if isinstance(p, list) and len(p) == 2 and s(p[0]) and s(p[1]):
                parsed.append((s(p[0]), s(p[1])))
            elif isinstance(p, dict) and s(p.get("left")) and s(p.get("right")):
                parsed.append((s(p["left"]), s(p["right"])))
        if len(parsed) != len(pairs):
            errors.append(f'{path}: jedes Paar muss ["links", "rechts"] sein.')
        elif len(parsed) < 2:
            errors.append(f'{path}: mindestens 2 "pairs" nötig.')
        elif len({l for l, _ in parsed}) != len(parsed) or len({r for _, r in parsed}) != len(parsed):
            errors.append(f"{path}: linke und rechte Seiten müssen jeweils eindeutig sein.")
    elif kind == "flashcard":
        need(s(e.get("front")) or question, "front")
        need(s(e.get("back")) or s(e.get("answer")), "back")
    if "$" in json.dumps(e, ensure_ascii=False) or "\\frac" in json.dumps(e, ensure_ascii=False):
        warnings.append(f"{path}: sieht nach LaTeX aus – die App zeigt nur Unicode-Formeln (·, ², √, Δ).")
    return kind


def validate(data):
    errors, warnings, kinds = [], [], Counter()
    if not isinstance(data, dict):
        return ["Die Datei muss ein JSON-Objekt sein, das mit { beginnt."], [], kinds, 0, 0
    if not s(data.get("course")):
        warnings.append('"course" fehlt – empfohlen, damit die App den passenden Kurs vorschlägt.')
    chapters = data.get("chapters")
    if not isinstance(chapters, list):
        return ['Es fehlt die Liste "chapters": [ … ].'], warnings, kinds, 0, 0
    if not chapters:
        errors.append('"chapters" ist leer – mindestens ein Kapitel wird benötigt.')
    titles, lesson_count = Counter(), 0
    for ci, c in enumerate(chapters, 1):
        path = f"Kapitel {ci}"
        if not isinstance(c, dict):
            errors.append(f"{path}: muss ein Objekt {{ … }} sein.")
            continue
        title = s(c.get("title"))
        if title is None:
            errors.append(f'{path}: "title" fehlt.')
        else:
            titles[title.lower()] += 1
            path = f"{path} „{title}“"
        lessons = c.get("lessons")
        if not isinstance(lessons, list) or not lessons:
            errors.append(f'{path}: "lessons" fehlt oder ist leer.')
            continue
        for li, l in enumerate(lessons, 1):
            lpath = f"{path} › Lektion {li}"
            if not isinstance(l, dict):
                errors.append(f"{lpath}: muss ein Objekt {{ … }} sein.")
                continue
            lesson_count += 1
            exercises = l.get("exercises") or []
            theory = l.get("theory")
            if not exercises and not theory:
                errors.append(f'{lpath}: braucht "theory" oder "exercises".')
            elif not exercises:
                warnings.append(f"{lpath}: hat keine Übungen, nur Theorie.")
            for ei, e in enumerate(exercises, 1):
                kind = check_exercise(e, f"{lpath} › Übung {ei}", errors, warnings)
                if kind:
                    kinds[kind] += 1
    for title, n in titles.items():
        if n > 1:
            warnings.append(f"Kapiteltitel „{title}“ kommt {n}-mal vor – die App erkennt Duplikate am Titel.")
    return errors, warnings, kinds, len(chapters), lesson_count


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(2)
    path = sys.argv[1]
    try:
        with open(path, encoding="utf-8-sig") as f:
            data = json.load(f)
    except json.JSONDecodeError as err:
        print(f"FEHLER: kein gültiges JSON – {err}")
        sys.exit(1)
    errors, warnings, kinds, n_chapters, n_lessons = validate(data)
    for w in warnings:
        if "--quiet" not in sys.argv:
            print(f"Hinweis: {w}")
    if errors:
        print(f"\n{len(errors)} FEHLER – die App würde den Import ablehnen:")
        for e in errors:
            print(f"  - {e}")
        sys.exit(1)
    total = sum(kinds.values())
    print(f"OK – {n_chapters} Kapitel, {n_lessons} Lektionen, {total} Übungen")
    print("Typen: " + ", ".join(f"{k}={v}" for k, v in sorted(kinds.items())))


if __name__ == "__main__":
    main()
