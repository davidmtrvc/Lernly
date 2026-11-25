import Foundation

// MARK: - Kurs-Struktur: Kurs → Kapitel → Lektion → Übung

nonisolated struct Course: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var icon: String
    var color: CourseColor
    var createdAt = Date()
    var chapters: [Chapter] = []

    var lessonCount: Int { chapters.reduce(0) { $0 + $1.lessons.count } }
    var completedLessonCount: Int { chapters.reduce(0) { $0 + $1.completedLessonCount } }
    var progress: Double {
        lessonCount == 0 ? 0 : Double(completedLessonCount) / Double(lessonCount)
    }

    /// Die nächste offene Lektion im gesamten Kurs (für den "START"-Marker).
    var nextLessonID: UUID? {
        for chapter in chapters {
            if let lesson = chapter.lessons.first(where: { !$0.isCompleted }) { return lesson.id }
        }
        return nil
    }
}

nonisolated struct Chapter: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    var summary: String?
    var icon: String?
    var lessons: [Lesson]
    var importedAt = Date()

    var completedLessonCount: Int { lessons.filter(\.isCompleted).count }
    var exerciseCount: Int { lessons.reduce(0) { $0 + $1.exercises.count } }

    /// Innerhalb eines Kapitels werden Lektionen nacheinander freigeschaltet.
    /// Jedes Kapitel ist für sich offen, damit neu importierte Kapitel sofort lernbar sind.
    func isUnlocked(_ lessonIndex: Int) -> Bool {
        lessonIndex == 0 || lessons[lessonIndex - 1].isCompleted
    }
}

nonisolated struct Lesson: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    var theory: [TheoryCard]
    var exercises: [Exercise]
    var completedCount = 0
    var bestAccuracy: Double?

    var isCompleted: Bool { completedCount > 0 }
}

nonisolated struct TheoryCard: Codable, Hashable {
    var title: String?
    var text: String
}

nonisolated struct Exercise: Identifiable, Codable, Hashable {
    var id = UUID()
    var kind: ExerciseKind
    var explanation: String?
}

nonisolated struct MatchPair: Codable, Hashable {
    var left: String
    var right: String
}

nonisolated enum ExerciseKind: Codable, Hashable {
    case singleChoice(question: String, options: [String], answer: Int)
    case multipleChoice(question: String, options: [String], answers: [Int])
    case trueFalse(statement: String, answer: Bool)
    case input(question: String, answers: [String])
    /// Lückentext: Lücken stehen als {{Wort}} im Text.
    case cloze(text: String, distractors: [String])
    /// Items stehen in der richtigen Reihenfolge, die App mischt sie.
    case order(question: String, items: [String])
    case match(question: String, pairs: [MatchPair])
    case flashcard(front: String, back: String)

    var typeName: String {
        switch self {
        case .singleChoice: "single_choice"
        case .multipleChoice: "multiple_choice"
        case .trueFalse: "true_false"
        case .input: "input"
        case .cloze: "cloze"
        case .order: "order"
        case .match: "match"
        case .flashcard: "flashcard"
        }
    }
}

// MARK: - Lückentext-Hilfen

nonisolated enum ClozeSegment: Hashable {
    case text(String)
    case gap(Int)
}

nonisolated enum Cloze {
    static func parse(_ text: String) -> (segments: [ClozeSegment], gaps: [String]) {
        var segments: [ClozeSegment] = []
        var gaps: [String] = []
        var rest = Substring(text)
        while let open = rest.range(of: "{{") {
            guard let close = rest.range(of: "}}", range: open.upperBound..<rest.endIndex) else { break }
            let before = rest[..<open.lowerBound]
            if !before.isEmpty { segments.append(.text(String(before))) }
            let answer = rest[open.upperBound..<close.lowerBound].trimmingCharacters(in: .whitespaces)
            segments.append(.gap(gaps.count))
            gaps.append(answer)
            rest = rest[close.upperBound...]
        }
        if !rest.isEmpty { segments.append(.text(String(rest))) }
        return (segments, gaps)
    }

    /// Der Satz mit eingesetzten Lösungen.
    static func solved(_ text: String) -> String {
        parse(text).segments.map { segment in
            switch segment {
            case .text(let string): string
            case .gap(let index): parse(text).gaps[index]
            }
        }.joined()
    }
}

// MARK: - Statistik & Streaks

nonisolated enum DayKey {
    static func key(for date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    static func date(from key: String, calendar: Calendar = .current) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }
}

nonisolated struct UserStats: Codable, Hashable {
    var totalXP = 0
    var lessonsCompleted = 0
    var dailyGoal = 1
    /// "yyyy-MM-dd" → Anzahl abgeschlossener Lektionen an diesem Tag
    var lessonsPerDay: [String: Int] = [:]

    func lessons(on date: Date) -> Int { lessonsPerDay[DayKey.key(for: date)] ?? 0 }
    func isActive(_ date: Date) -> Bool { lessons(on: date) > 0 }

    /// Ein Tag zählt zum Streak, sobald mindestens eine Lektion abgeschlossen wurde.
    /// Ist heute noch nichts passiert, bleibt der Streak von gestern bestehen.
    func currentStreak(today: Date = .now) -> Int {
        let calendar = Calendar.current
        var day = calendar.startOfDay(for: today)
        if !isActive(day) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = yesterday
        }
        var count = 0
        while isActive(day) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return count
    }

    var longestStreak: Int {
        let calendar = Calendar.current
        let days = lessonsPerDay.filter { $0.value > 0 }.keys.compactMap { DayKey.date(from: $0) }.sorted()
        var best = 0
        var run = 0
        var previous: Date?
        for day in days {
            if let previous, calendar.dateComponents([.day], from: previous, to: day).day == 1 {
                run += 1
            } else {
                run = 1
            }
            best = max(best, run)
            previous = day
        }
        return best
    }
}

nonisolated struct LessonReward: Hashable {
    var xp: Int
    var accuracy: Double
    var streak: Int
    var streakExtended: Bool
    var dailyGoalJustReached: Bool
}
