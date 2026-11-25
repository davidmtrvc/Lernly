import Foundation
#if canImport(UIKit)
import UIKit
#endif
import UniformTypeIdentifiers

extension UTType {
    /// `.lernly`-Datei: JSON-Inhalt mit eigener Dateiendung (deklariert in Lernly-Info.plist).
    nonisolated static let lernly = UTType(exportedAs: "app.lernly.course", conformingTo: .json)
}

nonisolated struct ParsedPackage: Hashable {
    var courseName: String?
    var chapters: [Chapter]
    var warnings: [String]

    var lessonCount: Int { chapters.reduce(0) { $0 + $1.lessons.count } }
    var exerciseCount: Int { chapters.reduce(0) { $0 + $1.exerciseCount } }
}

nonisolated struct LernlyParseError: Error {
    var issues: [String]
}

/// Liest `.lernly`-Dateien (JSON). Bewusst tolerant gegenüber typischen KI-Ausgaben:
/// Markdown-Codeblöcke, Text vor/nach dem JSON, Kommentare, Komma am Ende, Antworten als Text statt Index.
nonisolated enum LernlyParser {
    static let formatVersion = 1

    static func parse(data: Data) throws -> ParsedPackage {
        guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            throw LernlyParseError(issues: ["Die Datei ist keine Textdatei."])
        }
        return try parse(text: text)
    }

    static func parse(text: String) throws -> ParsedPackage {
        let cleaned = clean(text)
        guard !cleaned.isEmpty else { throw LernlyParseError(issues: ["Es wurde kein Inhalt gefunden."]) }

        let root: Any
        do {
            root = try jsonObject(cleaned)
        } catch {
            // Notfall: typografische Anführungszeichen (z. B. aus Notizen-Apps) ersetzen
            let straightened = cleaned
                .replacingOccurrences(of: "\u{201C}", with: "\"")
                .replacingOccurrences(of: "\u{201D}", with: "\"")
            if let fallback = try? jsonObject(straightened) {
                root = fallback
            } else {
                throw LernlyParseError(issues: ["Kein gültiges JSON: \(describe(error))"])
            }
        }

        guard let object = root as? [String: Any] else {
            throw LernlyParseError(issues: ["Die Datei muss ein JSON-Objekt sein, das mit { beginnt."])
        }

        let issues = IssueList()
        var warnings: [String] = []

        if let version = int(object["lernly"]), version > formatVersion {
            warnings.append("Die Datei nutzt Format-Version \(version), diese App kennt Version \(formatVersion). Unbekannte Felder werden ignoriert.")
        }

        guard let rawChapters = object["chapters"] as? [Any] else {
            throw LernlyParseError(issues: ["Es fehlt die Liste \"chapters\": [ … ]."])
        }
        if rawChapters.isEmpty { issues.add("\"chapters\" ist leer – mindestens ein Kapitel wird benötigt.") }

        var chapters: [Chapter] = []
        for (ci, rawChapter) in rawChapters.enumerated() {
            let path = "Kapitel \(ci + 1)"
            guard let c = rawChapter as? [String: Any] else {
                issues.add("\(path): muss ein Objekt { … } sein.")
                continue
            }
            let title = string(c["title"]) ?? {
                issues.add("\(path): \"title\" fehlt.")
                return "Kapitel \(ci + 1)"
            }()
            let chapterPath = "\(path) „\(title)“"
            let icon = string(c["icon"]).flatMap { isValidSymbol($0) ? $0 : nil }

            guard let rawLessons = c["lessons"] as? [Any], !rawLessons.isEmpty else {
                issues.add("\(chapterPath): \"lessons\" fehlt oder ist leer.")
                continue
            }

            var lessons: [Lesson] = []
            for (li, rawLesson) in rawLessons.enumerated() {
                let lessonPath = "\(chapterPath) › Lektion \(li + 1)"
                guard let l = rawLesson as? [String: Any] else {
                    issues.add("\(lessonPath): muss ein Objekt { … } sein.")
                    continue
                }
                let lessonTitle = string(l["title"]) ?? "Lektion \(li + 1)"
                let theory = parseTheory(l["theory"])
                var exercises: [Exercise] = []
                let rawExercises = (l["exercises"] as? [Any]) ?? []
                for (ei, rawExercise) in rawExercises.enumerated() {
                    if let exercise = parseExercise(rawExercise, path: "\(lessonPath) › Übung \(ei + 1)", issues: issues) {
                        exercises.append(exercise)
                    }
                }
                if theory.isEmpty && rawExercises.isEmpty {
                    issues.add("\(lessonPath): braucht \"theory\" oder \"exercises\".")
                } else if rawExercises.isEmpty {
                    warnings.append("\(lessonPath) „\(lessonTitle)“ hat keine Übungen, nur Theorie.")
                }
                lessons.append(Lesson(title: lessonTitle, theory: theory, exercises: exercises))
            }
            chapters.append(Chapter(title: title, summary: string(c["description"]) ?? string(c["summary"]), icon: icon, lessons: lessons))
        }

        if !issues.list.isEmpty { throw LernlyParseError(issues: issues.list) }
        return ParsedPackage(courseName: string(object["course"]), chapters: chapters, warnings: warnings)
    }

    // MARK: Übungen

    private static func parseExercise(_ raw: Any, path: String, issues: IssueList) -> Exercise? {
        guard let e = raw as? [String: Any] else {
            issues.add("\(path): muss ein Objekt { … } sein.")
            return nil
        }
        let rawType = (string(e["type"]) ?? "").lowercased()
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: " ", with: "_")
        let path = "\(path) (\(rawType.isEmpty ? "ohne type" : rawType))"
        let explanation = string(e["explanation"])
        let question = string(e["question"]) ?? string(e["prompt"])

        func require<T>(_ value: T?, _ field: String) -> T? {
            if value == nil { issues.add("\(path): \"\(field)\" fehlt oder ist ungültig.") }
            return value
        }

        let kind: ExerciseKind?
        switch rawType {
        case "single_choice", "choice", "multiple_choice_single", "mc", "quiz":
            guard let q = require(question, "question"),
                  let options = require(strings(e["options"]), "options") else { return nil }
            guard options.count >= 2 else { issues.add("\(path): mindestens 2 \"options\" nötig."); return nil }
            guard let answer = index(e["answer"], in: options) else {
                issues.add("\(path): \"answer\" muss ein Index von 0 bis \(options.count - 1) oder der Text einer Option sein.")
                return nil
            }
            kind = .singleChoice(question: q, options: options, answer: answer)

        case "multiple_choice", "multi_choice", "multiple_select", "multi_select":
            guard let q = require(question, "question"),
                  let options = require(strings(e["options"]), "options") else { return nil }
            guard options.count >= 2 else { issues.add("\(path): mindestens 2 \"options\" nötig."); return nil }
            let rawAnswers = (e["answers"] as? [Any]) ?? (e["answer"] as? [Any]) ?? []
            let answers = rawAnswers.compactMap { index($0, in: options) }
            guard !answers.isEmpty, answers.count == rawAnswers.count else {
                issues.add("\(path): \"answers\" muss eine Liste gültiger Indizes (0 bis \(options.count - 1)) sein.")
                return nil
            }
            kind = .multipleChoice(question: q, options: options, answers: Array(Set(answers)).sorted())

        case "true_false", "truefalse", "tf", "bool", "boolean":
            guard let statement = require(string(e["statement"]) ?? question, "statement"),
                  let answer = require(bool(e["answer"]), "answer (true/false)") else { return nil }
            kind = .trueFalse(statement: statement, answer: answer)

        case "input", "text", "free_text", "short_answer", "type":
            guard let q = require(question, "question"),
                  let answers = require(strings(e["answers"]) ?? strings(e["answer"]), "answer") else { return nil }
            kind = .input(question: q, answers: answers)

        case "cloze", "gap", "fill_blank", "fill_in_the_blank", "gaps":
            guard let text = require(string(e["text"]), "text") else { return nil }
            guard !Cloze.parse(text).gaps.isEmpty else {
                issues.add("\(path): \"text\" braucht mindestens eine Lücke im Format {{Wort}}.")
                return nil
            }
            kind = .cloze(text: text, distractors: strings(e["distractors"]) ?? [])

        case "order", "ordering", "sort", "sequence":
            guard let q = require(question, "question"),
                  let items = require(strings(e["items"]), "items") else { return nil }
            guard items.count >= 2 else { issues.add("\(path): mindestens 2 \"items\" nötig."); return nil }
            kind = .order(question: q, items: items)

        case "match", "matching", "pairs":
            guard let rawPairs = require(e["pairs"] as? [Any], "pairs") else { return nil }
            let pairs: [MatchPair] = rawPairs.compactMap { raw in
                if let array = raw as? [Any], array.count == 2, let l = string(array[0]), let r = string(array[1]) {
                    return MatchPair(left: l, right: r)
                }
                if let dict = raw as? [String: Any], let l = string(dict["left"]), let r = string(dict["right"]) {
                    return MatchPair(left: l, right: r)
                }
                return nil
            }
            guard pairs.count == rawPairs.count else {
                issues.add("\(path): jedes Paar muss [\"links\", \"rechts\"] sein.")
                return nil
            }
            guard pairs.count >= 2 else { issues.add("\(path): mindestens 2 \"pairs\" nötig."); return nil }
            guard Set(pairs.map(\.left)).count == pairs.count, Set(pairs.map(\.right)).count == pairs.count else {
                issues.add("\(path): linke und rechte Seiten müssen jeweils eindeutig sein.")
                return nil
            }
            kind = .match(question: question ?? "Finde die Paare", pairs: pairs)

        case "flashcard", "card", "flash_card":
            guard let front = require(string(e["front"]) ?? question, "front"),
                  let back = require(string(e["back"]) ?? string(e["answer"]), "back") else { return nil }
            kind = .flashcard(front: front, back: back)

        default:
            issues.add("\(path): unbekannter \"type\". Erlaubt: single_choice, multiple_choice, true_false, input, cloze, order, match, flashcard.")
            return nil
        }

        guard let kind else { return nil }
        return Exercise(kind: kind, explanation: explanation)
    }

    private static func parseTheory(_ raw: Any?) -> [TheoryCard] {
        if let text = string(raw) { return [TheoryCard(title: nil, text: text)] }
        guard let list = raw as? [Any] else { return [] }
        return list.compactMap { item in
            if let text = string(item) { return TheoryCard(title: nil, text: text) }
            if let dict = item as? [String: Any], let text = string(dict["text"]) ?? string(dict["content"]) {
                return TheoryCard(title: string(dict["title"]), text: text)
            }
            return nil
        }
    }

    // MARK: Hilfsfunktionen

    private static func isValidSymbol(_ name: String) -> Bool {
        #if canImport(UIKit)
        UIImage(systemName: name) != nil
        #else
        true
        #endif
    }

    private final class IssueList {
        var list: [String] = []
        func add(_ issue: String) { list.append(issue) }
    }

    private static func clean(_ text: String) -> String {
        var t = text.replacingOccurrences(of: "\u{FEFF}", with: "")
        if let fence = t.range(of: "```") {
            let afterFence = t[fence.upperBound...]
            let bodyStart = afterFence.firstIndex(of: "\n").map { afterFence.index(after: $0) } ?? afterFence.startIndex
            let body = t[bodyStart...]
            t = String(body.range(of: "```").map { body[..<$0.lowerBound] } ?? body)
        }
        guard let first = t.firstIndex(of: "{"), let last = t.lastIndex(of: "}"), first < last else {
            return t.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return String(t[first...last])
    }

    private static func jsonObject(_ text: String) throws -> Any {
        try JSONSerialization.jsonObject(with: Data(text.utf8), options: [.json5Allowed])
    }

    private static func describe(_ error: Error) -> String {
        let ns = error as NSError
        return (ns.userInfo[NSDebugDescriptionErrorKey] as? String) ?? ns.localizedDescription
    }

    private static func isBool(_ number: NSNumber) -> Bool {
        CFGetTypeID(number) == CFBooleanGetTypeID()
    }

    static func string(_ value: Any?) -> String? {
        if let s = value as? String {
            let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        if let n = value as? NSNumber, !isBool(n) { return n.stringValue }
        return nil
    }

    static func strings(_ value: Any?) -> [String]? {
        if let single = string(value) { return [single] }
        guard let list = value as? [Any] else { return nil }
        let result = list.compactMap { string($0) }
        return result.isEmpty || result.count != list.count ? nil : result
    }

    static func int(_ value: Any?) -> Int? {
        if let n = value as? NSNumber, !isBool(n) { return n.intValue }
        if let s = value as? String { return Int(s.trimmingCharacters(in: .whitespaces)) }
        return nil
    }

    static func bool(_ value: Any?) -> Bool? {
        if let n = value as? NSNumber, isBool(n) { return n.boolValue }
        switch (value as? String)?.lowercased().trimmingCharacters(in: .whitespaces) {
        case "true", "wahr", "richtig", "ja", "yes": return true
        case "false", "falsch", "nein", "no": return false
        default: return nil
        }
    }

    /// Index als Zahl oder als Text einer Option.
    private static func index(_ value: Any?, in options: [String]) -> Int? {
        if let n = value as? NSNumber, !isBool(n) {
            let i = n.intValue
            return options.indices.contains(i) ? i : nil
        }
        if let s = string(value) {
            if let i = options.firstIndex(where: { $0.caseInsensitiveCompare(s) == .orderedSame }) { return i }
            if let i = Int(s), options.indices.contains(i) { return i }
        }
        return nil
    }
}

// MARK: - Antwortprüfung für Freitext

nonisolated enum AnswerMatcher {
    enum Result { case exact, typo(String), wrong }

    static func normalize(_ s: String) -> String {
        var t = s.lowercased()
            .replacingOccurrences(of: ",", with: ".")
            .split(whereSeparator: \.isWhitespace).joined(separator: " ")
        while let last = t.last, ".!?;:".contains(last) { t.removeLast() }
        return t
    }

    static func check(_ input: String, against answers: [String]) -> Result {
        let given = normalize(input)
        guard !given.isEmpty else { return .wrong }
        if answers.contains(where: { normalize($0) == given }) { return .exact }
        for answer in answers {
            let expected = normalize(answer)
            // Zahlen müssen exakt stimmen, bei Wörtern sind kleine Tippfehler okay.
            guard !expected.contains(where: \.isNumber), expected.count >= 5 else { continue }
            let tolerance = expected.count >= 10 ? 2 : 1
            if levenshtein(given, expected) <= tolerance { return .typo(answer) }
        }
        return .wrong
    }

    static func levenshtein(_ a: String, _ b: String) -> Int {
        let a = Array(a), b = Array(b)
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }
        var previous = Array(0...b.count)
        for i in 1...a.count {
            var current = [i] + Array(repeating: 0, count: b.count)
            for j in 1...b.count {
                current[j] = min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1))
            }
            previous = current
        }
        return previous[b.count]
    }
}
