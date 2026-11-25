import Foundation
import Observation
import SwiftUI

enum AppTab: Hashable {
    case learn, courses, profile
}

struct ImportRequest: Identifiable {
    let id = UUID()
    var package: ParsedPackage
    var preferredCourseID: UUID?
}

struct ImportFailure: Identifiable {
    let id = UUID()
    var issues: [String]
}

nonisolated private struct LibrarySnapshot: Codable {
    var courses: [Course]
    var stats: UserStats
    var activeCourseID: UUID?
}

/// Zentrale App-Daten. Wird als JSON in Application Support gespeichert.
@Observable
final class AppStore {
    private(set) var courses: [Course] = []
    private(set) var stats = UserStats()
    private(set) var activeCourseID: UUID?

    // UI-Zustand (nicht gespeichert)
    var selectedTab: AppTab = .learn
    var pendingImport: ImportRequest?
    var importFailure: ImportFailure?

    @ObservationIgnored private let fileURL: URL

    init(inMemory: Bool = false) {
        let directory = inMemory
            ? FileManager.default.temporaryDirectory
            : URL.applicationSupportDirectory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appending(path: inMemory ? "lernly-preview-\(UUID()).json" : "lernly-library.json")
        load()
    }

    // MARK: Kurse

    var activeCourse: Course? {
        courses.first { $0.id == activeCourseID } ?? courses.first
    }

    func course(_ id: UUID) -> Course? {
        courses.first { $0.id == id }
    }

    func setActiveCourse(_ id: UUID) {
        activeCourseID = id
        save()
    }

    @discardableResult
    func createCourse(name: String, icon: String, color: CourseColor) -> Course {
        let course = Course(name: name, icon: icon, color: color)
        courses.append(course)
        if activeCourse?.id != activeCourseID || activeCourseID == nil { activeCourseID = course.id }
        save()
        return course
    }

    func updateCourse(_ id: UUID, name: String, icon: String, color: CourseColor) {
        mutate(id) {
            $0.name = name
            $0.icon = icon
            $0.color = color
        }
    }

    func deleteCourse(_ id: UUID) {
        courses.removeAll { $0.id == id }
        if activeCourseID == id { activeCourseID = courses.first?.id }
        save()
    }

    func appendChapters(_ chapters: [Chapter], to courseID: UUID) {
        let stamped = chapters.map { chapter -> Chapter in
            var copy = chapter
            copy.importedAt = .now
            return copy
        }
        mutate(courseID) { $0.chapters.append(contentsOf: stamped) }
    }

    func deleteChapter(_ chapterID: UUID, in courseID: UUID) {
        mutate(courseID) { $0.chapters.removeAll { $0.id == chapterID } }
    }

    func moveChapters(in courseID: UUID, from source: IndexSet, to destination: Int) {
        mutate(courseID) { $0.chapters.move(fromOffsets: source, toOffset: destination) }
    }

    func resetProgress(of courseID: UUID) {
        mutate(courseID) { course in
            for c in course.chapters.indices {
                for l in course.chapters[c].lessons.indices {
                    course.chapters[c].lessons[l].completedCount = 0
                    course.chapters[c].lessons[l].bestAccuracy = nil
                }
            }
        }
    }

    // MARK: Lernfortschritt

    func completeLesson(_ lessonID: UUID, in courseID: UUID, accuracy: Double) -> LessonReward {
        let today = Date.now
        let wasActiveToday = stats.isActive(today)
        let lessonsBefore = stats.lessons(on: today)

        mutate(courseID, persist: false) { course in
            for c in course.chapters.indices {
                if let l = course.chapters[c].lessons.firstIndex(where: { $0.id == lessonID }) {
                    course.chapters[c].lessons[l].completedCount += 1
                    let best = course.chapters[c].lessons[l].bestAccuracy ?? 0
                    course.chapters[c].lessons[l].bestAccuracy = max(best, accuracy)
                }
            }
        }

        let xp = 10 + (accuracy >= 0.999 ? 5 : 0)
        stats.totalXP += xp
        stats.lessonsCompleted += 1
        stats.lessonsPerDay[DayKey.key(for: today), default: 0] += 1
        save()

        return LessonReward(
            xp: xp,
            accuracy: accuracy,
            streak: stats.currentStreak(today: today),
            streakExtended: !wasActiveToday,
            dailyGoalJustReached: lessonsBefore < stats.dailyGoal && lessonsBefore + 1 >= stats.dailyGoal
        )
    }

    func setDailyGoal(_ goal: Int) {
        stats.dailyGoal = max(1, goal)
        save()
    }

    func resetAllData() {
        courses = []
        stats = UserStats()
        activeCourseID = nil
        save()
    }

    // MARK: Import

    func importFile(at url: URL, preferredCourseID: UUID?) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: url)
            // Per "Öffnen in…" übergebene Dateien landen in Documents/Inbox und werden danach aufgeräumt.
            if url.path().contains("/Inbox/") { try? FileManager.default.removeItem(at: url) }
            importText(String(decoding: data, as: UTF8.self), preferredCourseID: preferredCourseID, delayed: true)
        } catch {
            presentLater { self.importFailure = ImportFailure(issues: ["Die Datei konnte nicht gelesen werden: \(error.localizedDescription)"]) }
        }
    }

    /// Prüft den Text; bei Erfolg erscheint die Import-Vorschau, sonst die Fehlerliste.
    func importText(_ text: String, preferredCourseID: UUID?, delayed: Bool = false) {
        let action: () -> Void
        do {
            let package = try LernlyParser.parse(text: text)
            action = { self.pendingImport = ImportRequest(package: package, preferredCourseID: preferredCourseID) }
        } catch let error as LernlyParseError {
            action = { self.importFailure = ImportFailure(issues: error.issues) }
        } catch {
            action = { self.importFailure = ImportFailure(issues: [error.localizedDescription]) }
        }
        if delayed { presentLater(action) } else { action() }
    }

    /// Der Dateiauswahl-Dialog muss erst verschwinden, bevor ein neues Sheet erscheinen kann.
    private func presentLater(_ action: @escaping () -> Void) {
        Task {
            try? await Task.sleep(for: .milliseconds(500))
            action()
        }
    }

    // MARK: Persistenz

    private func mutate(_ id: UUID, persist: Bool = true, _ body: (inout Course) -> Void) {
        guard let index = courses.firstIndex(where: { $0.id == id }) else { return }
        body(&courses[index])
        if persist { save() }
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let snapshot = try? JSONDecoder().decode(LibrarySnapshot.self, from: data) else { return }
        courses = snapshot.courses
        stats = snapshot.stats
        activeCourseID = snapshot.activeCourseID
    }

    private func save() {
        let snapshot = LibrarySnapshot(courses: courses, stats: stats, activeCourseID: activeCourseID)
        do {
            let data = try JSONEncoder().encode(snapshot)
            try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
        } catch {
            print("Lernly: Speichern fehlgeschlagen – \(error)")
        }
    }
}
