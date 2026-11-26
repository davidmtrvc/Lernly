"""Helper functions to build .lernly course files without hand-writing JSON.

Usage:
    import sys; sys.path.insert(0, "<skill-dir>/scripts")
    from lernly_builder import *
    write_course("Physik", [chapter(...), ...], "Physik-Test.lernly")
"""
import json

__all__ = ["sc", "mc", "tf", "inp", "cloze", "order", "match", "card",
           "th", "lesson", "chapter", "course", "write_course"]


def _with_explanation(exercise, explanation):
    if explanation:
        exercise["explanation"] = explanation
    return exercise


def sc(question, options, answer, explanation=None):
    """Single choice. `answer` is the 0-based index of the correct option."""
    return _with_explanation({"type": "single_choice", "question": question,
                              "options": list(options), "answer": answer}, explanation)


def mc(question, options, answers, explanation=None):
    """Multiple choice. `answers` is a list of 0-based indices."""
    return _with_explanation({"type": "multiple_choice", "question": question,
                              "options": list(options), "answers": list(answers)}, explanation)


def tf(statement, answer, explanation=None):
    """True/false statement."""
    return _with_explanation({"type": "true_false", "statement": statement,
                              "answer": bool(answer)}, explanation)


def inp(question, answers, explanation=None):
    """Free-text input. List every accepted spelling/rounding in `answers`."""
    if isinstance(answers, str):
        answers = [answers]
    return _with_explanation({"type": "input", "question": question,
                              "answers": list(answers)}, explanation)


def cloze(text, distractors=(), explanation=None):
    """Cloze text. Mark gaps as {{answer}}; distractors are extra wrong words for the word bank."""
    return _with_explanation({"type": "cloze", "text": text,
                              "distractors": list(distractors)}, explanation)


def order(question, items, explanation=None):
    """Ordering task. Give `items` in the CORRECT order – the app shuffles them."""
    return _with_explanation({"type": "order", "question": question,
                              "items": list(items)}, explanation)


def match(question, pairs, explanation=None):
    """Matching task. `pairs` = [[left, right], ...]; every left and every right must be unique."""
    return _with_explanation({"type": "match", "question": question,
                              "pairs": [list(p) for p in pairs]}, explanation)


def card(front, back):
    """Flashcard (self-rated)."""
    return {"type": "flashcard", "front": front, "back": back}


def th(title, text):
    """Theory card shown before the exercises. `title` may be None."""
    card_ = {"text": text}
    if title:
        card_["title"] = title
    return card_


def lesson(title, theory, exercises):
    return {"title": title, "theory": list(theory), "exercises": list(exercises)}


def chapter(title, description, icon, lessons):
    ch = {"title": title, "lessons": list(lessons)}
    if description:
        ch["description"] = description
    if icon:
        ch["icon"] = icon
    return ch


def course(name, chapters):
    return {"lernly": 1, "course": name, "chapters": list(chapters)}


def write_course(name, chapters, path):
    """Write the course to `path` (UTF-8, pretty-printed) and print a short summary."""
    data = course(name, chapters)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write("\n")
    lessons = sum(len(c["lessons"]) for c in data["chapters"])
    exercises = sum(len(l["exercises"]) for c in data["chapters"] for l in c["lessons"])
    print(f"{path}: {len(data['chapters'])} Kapitel, {lessons} Lektionen, {exercises} Übungen")
    return data
