import Foundation
import Observation

/// Eingabezustand der aktuell angezeigten Übung (inkl. Mischreihenfolgen).
struct Draft {
    var choice: Int?
    var multi: Set<Int> = []
    var bool: Bool?
    var text = ""
    var optionOrder: [Int] = []

    // Lückentext
    var bank: [String] = []
    var gapFills: [Int?] = []

    // Reihenfolge
    var orderPool: [Int] = []
    var orderPlaced: [Int] = []

    // Paare
    var leftOrder: [Int] = []
    var rightOrder: [Int] = []
    var matched: Set<Int> = []
    var selectedLeft: Int?
    var selectedRight: Int?
    var wrongFlash: Set<String> = []
    var matchMistakes = 0

    // Karteikarte
    var revealed = false

    static func make(for exercise: Exercise) -> Draft {
        var draft = Draft()
        switch exercise.kind {
        case .singleChoice(_, let options, _), .multipleChoice(_, let options, _):
            draft.optionOrder = Array(options.indices).shuffled()
        case .cloze(let text, let distractors):
            let gaps = Cloze.parse(text).gaps
            draft.bank = (gaps + distractors).shuffled()
            draft.gapFills = Array(repeating: nil, count: gaps.count)
        case .order(_, let items):
            var pool = Array(items.indices).shuffled()
            while pool == Array(items.indices) { pool.shuffle() }
            draft.orderPool = pool
        case .match(_, let pairs):
            draft.leftOrder = Array(pairs.indices).shuffled()
            draft.rightOrder = Array(pairs.indices).shuffled()
        case .trueFalse, .input, .flashcard:
            break
        }
        return draft
    }
}

struct Feedback: Identifiable {
    let id = UUID()
    var isCorrect: Bool
    var title: String
    var correctAnswer: String?
    var explanation: String?
    var note: String?
}

@Observable
final class LessonSession {
    enum Item: Identifiable {
        case theory(TheoryCard, index: Int)
        case exercise(Exercise, attempt: Int)

        var id: String {
            switch self {
            case .theory(_, let index): "theory-\(index)"
            case .exercise(let exercise, let attempt): "\(exercise.id)-\(attempt)"
            }
        }
    }

    let lesson: Lesson
    private(set) var queue: [Item]
    private(set) var position = 0
    var draft = Draft()
    private(set) var feedback: Feedback?
    private(set) var finished = false
    private(set) var doneUnits = 0
    private(set) var missedIDs: Set<UUID> = []
    let totalUnits: Int

    init(lesson: Lesson) {
        self.lesson = lesson
        let items = lesson.theory.enumerated().map { Item.theory($1, index: $0) }
            + lesson.exercises.map { Item.exercise($0, attempt: 0) }
        queue = items
        totalUnits = items.count
        if items.isEmpty { finished = true }
        prepareDraft()
    }

    var current: Item? { queue.indices.contains(position) ? queue[position] : nil }
    var progress: Double { totalUnits == 0 ? 1 : Double(doneUnits) / Double(totalUnits) }

    var accuracy: Double {
        let count = lesson.exercises.count
        guard count > 0 else { return 1 }
        return Double(count - missedIDs.count) / Double(count)
    }

    var canCheck: Bool {
        guard feedback == nil, case .exercise(let exercise, _) = current else { return false }
        switch exercise.kind {
        case .singleChoice: return draft.choice != nil
        case .multipleChoice: return !draft.multi.isEmpty
        case .trueFalse: return draft.bool != nil
        case .input: return !draft.text.trimmingCharacters(in: .whitespaces).isEmpty
        case .cloze: return !draft.gapFills.contains(nil)
        case .order(_, let items): return draft.orderPlaced.count == items.count
        case .match, .flashcard: return false
        }
    }

    // MARK: Aktionen

    func continueTheory() {
        guard case .theory = current else { return }
        doneUnits += 1
        advance()
    }

    func check() {
        guard canCheck, case .exercise(let exercise, let attempt) = current else { return }
        switch exercise.kind {
        case .singleChoice(_, let options, let answer):
            resolve(exercise, attempt: attempt, correct: draft.choice == answer, answer: options[answer])

        case .multipleChoice(_, let options, let answers):
            resolve(exercise, attempt: attempt, correct: draft.multi == Set(answers),
                    answer: answers.map { options[$0] }.joined(separator: "\n"))

        case .trueFalse(_, let answer):
            resolve(exercise, attempt: attempt, correct: draft.bool == answer, answer: answer ? "Wahr" : "Falsch")

        case .input(_, let answers):
            switch AnswerMatcher.check(draft.text, against: answers) {
            case .exact:
                resolve(exercise, attempt: attempt, correct: true, answer: answers[0])
            case .typo(let expected):
                resolve(exercise, attempt: attempt, correct: true, answer: expected,
                        note: "Kleiner Tippfehler – richtig geschrieben: \(expected)")
            case .wrong:
                resolve(exercise, attempt: attempt, correct: false, answer: answers[0])
            }

        case .cloze(let text, _):
            let gaps = Cloze.parse(text).gaps
            let correct = gaps.indices.allSatisfy { i in
                guard let fill = draft.gapFills[i] else { return false }
                return AnswerMatcher.normalize(draft.bank[fill]) == AnswerMatcher.normalize(gaps[i])
            }
            resolve(exercise, attempt: attempt, correct: correct, answer: Cloze.solved(text))

        case .order(_, let items):
            resolve(exercise, attempt: attempt, correct: draft.orderPlaced == Array(items.indices),
                    answer: items.enumerated().map { "\($0 + 1). \($1)" }.joined(separator: "\n"))

        case .match, .flashcard:
            break
        }
    }

    func finishMatch() {
        guard feedback == nil, case .exercise(let exercise, _) = current else { return }
        if draft.matchMistakes > 0 { missedIDs.insert(exercise.id) }
        doneUnits += 1
        feedback = Feedback(isCorrect: true, title: draft.matchMistakes == 0 ? "Perfekt zugeordnet!" : "Alle Paare gefunden!",
                            explanation: exercise.explanation)
    }

    func rateFlashcard(knewIt: Bool) {
        guard feedback == nil, case .exercise(let exercise, let attempt) = current else { return }
        if knewIt {
            doneUnits += 1
            feedback = Feedback(isCorrect: true, title: Self.praise.randomElement()!, explanation: exercise.explanation)
        } else {
            missedIDs.insert(exercise.id)
            queue.append(.exercise(exercise, attempt: attempt + 1))
            feedback = Feedback(isCorrect: false, title: "Kein Problem",
                                explanation: exercise.explanation, note: "Die Karte kommt gleich nochmal.")
        }
    }

    func advance() {
        feedback = nil
        position += 1
        if position >= queue.count {
            finished = true
        } else {
            prepareDraft()
        }
    }

    // MARK: Intern

    private static let praise = ["Richtig!", "Super!", "Klasse!", "Genau so!", "Stark!", "Sehr gut!"]

    private func resolve(_ exercise: Exercise, attempt: Int, correct: Bool, answer: String?, note: String? = nil) {
        if correct {
            doneUnits += 1
            feedback = Feedback(isCorrect: true, title: Self.praise.randomElement()!,
                                explanation: exercise.explanation, note: note)
        } else {
            missedIDs.insert(exercise.id)
            queue.append(.exercise(exercise, attempt: attempt + 1))
            feedback = Feedback(isCorrect: false, title: "Leider falsch", correctAnswer: answer,
                                explanation: exercise.explanation)
        }
    }

    private func prepareDraft() {
        if case .exercise(let exercise, _) = current {
            draft = Draft.make(for: exercise)
        } else {
            draft = Draft()
        }
    }
}
