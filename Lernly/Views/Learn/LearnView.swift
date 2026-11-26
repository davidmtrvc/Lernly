import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct LearnView: View {
    @Environment(AppStore.self) private var store
    @State private var launch: LessonLaunch?
    @State private var showNewCourse = false

    var body: some View {
        NavigationStack {
            Group {
                if let course = store.activeCourse {
                    CoursePathView(course: course) { chapter, lesson in
                        launch = LessonLaunch(courseID: course.id, chapterTitle: chapter.title, lesson: lesson, color: course.color)
                    }
                } else {
                    WelcomeView { showNewCourse = true }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if let course = store.activeCourse {
                    ToolbarItem(placement: .topBarLeading) { courseMenu(course) }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 14) {
                        StatPill(icon: "flame.fill", value: "\(store.stats.currentStreak())",
                                 color: store.stats.isActive(.now) ? Theme.flame : Color(.systemGray2))
                        StatPill(icon: "bolt.fill", value: "\(store.stats.totalXP)", color: Theme.xp)
                    }
                    .padding(.horizontal, 6)
                }
            }
        }
        .fullScreenCover(item: $launch) { launch in
            LessonView(launch: launch)
        }
        .sheet(isPresented: $showNewCourse) {
            CourseEditorSheet(course: nil)
        }
    }

    private func courseMenu(_ course: Course) -> some View {
        Menu {
            ForEach(store.courses) { item in
                Button {
                    store.setActiveCourse(item.id)
                } label: {
                    Label(item.name, systemImage: item.id == course.id ? "checkmark" : item.icon)
                }
            }
            Divider()
            Button {
                showNewCourse = true
            } label: {
                Label("Neuer Kurs", systemImage: "plus")
            }
            Button {
                store.selectedTab = .courses
            } label: {
                Label("Kurse verwalten", systemImage: "books.vertical")
            }
        } label: {
            HStack(spacing: 8) {
                CourseIconTile(icon: course.icon, color: course.color.color, size: 28)
                Text(course.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)
        }
    }
}

// MARK: - Pfad

struct CoursePathView: View {
    var course: Course
    var onStart: (Chapter, Lesson) -> Void
    @State private var showFileImporter = false
    @State private var showPaste = false
    @Environment(AppStore.self) private var store

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if course.chapters.isEmpty {
                    EmptyCourseView(course: course, onFile: { showFileImporter = true }, onPaste: { showPaste = true })
                        .padding(.top, 40)
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(course.chapters.enumerated()), id: \.element.id) { chapterIndex, chapter in
                            ChapterBanner(chapter: chapter, number: chapterIndex + 1, color: course.color)
                                .padding(.horizontal, 16)
                                .padding(.top, chapterIndex == 0 ? 8 : 28)
                                .padding(.bottom, 26)

                            VStack(spacing: 18) {
                                ForEach(Array(chapter.lessons.enumerated()), id: \.element.id) { lessonIndex, lesson in
                                    PathNode(
                                        lesson: lesson,
                                        number: lessonIndex + 1,
                                        total: chapter.lessons.count,
                                        isUnlocked: chapter.isUnlocked(lessonIndex),
                                        isNext: course.nextLessonID == lesson.id,
                                        isLast: lessonIndex == chapter.lessons.count - 1,
                                        color: course.color
                                    ) {
                                        onStart(chapter, lesson)
                                    }
                                    .offset(x: Self.offset(for: lessonIndex))
                                    .id(lesson.id)
                                }
                            }
                        }

                        AddContentCard(courseName: course.name, color: course.color.color,
                                       onFile: { showFileImporter = true }, onPaste: { showPaste = true })
                            .padding(.horizontal, 16)
                            .padding(.top, 40)
                            .padding(.bottom, 32)
                    }
                }
            }
            .background(Color(.systemBackground))
            .onAppear {
                if let next = course.nextLessonID {
                    proxy.scrollTo(next, anchor: .center)
                }
            }
        }
        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.lernly, .json, .plainText]) { result in
            if case .success(let url) = result { store.importFile(at: url, preferredCourseID: course.id) }
        }
        .sheet(isPresented: $showPaste) {
            PasteImportSheet(preferredCourseID: course.id)
        }
    }

    /// Schlangenlinie wie ein Pfad.
    static func offset(for index: Int) -> CGFloat {
        let pattern: [CGFloat] = [0, 44, 72, 44, 0, -44, -72, -44]
        return pattern[index % pattern.count]
    }
}

struct ChapterBanner: View {
    var chapter: Chapter
    var number: Int
    var color: CourseColor

    private var isDone: Bool { !chapter.lessons.isEmpty && chapter.completedLessonCount == chapter.lessons.count }
    private var progress: Double {
        chapter.lessons.isEmpty ? 0 : Double(chapter.completedLessonCount) / Double(chapter.lessons.count)
    }

    /// Kapitel-Symbol ohne eigenen Kreis (der Fortschrittsring ist schon der Kreis).
    private var symbol: String {
        if isDone { return "checkmark" }
        guard let icon = chapter.icon else { return "book.closed.fill" }
        for suffix in [".circle.fill", ".circle"] where icon.hasSuffix(suffix) {
            let base = String(icon.dropLast(suffix.count))
            if UIImage(systemName: base) != nil { return base }
        }
        return icon
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Kapitel \(number)")
                    .font(.caption.weight(.bold))
                    .textCase(.uppercase)
                    .tracking(0.8)
                    .foregroundStyle(color.color)
                Text(chapter.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                if let summary = chapter.summary {
                    Text(summary)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 8)
            ZStack {
                Circle()
                    .stroke(color.color.opacity(0.18), lineWidth: 4)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(color.color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Image(systemName: symbol)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(color.color)
            }
            .frame(width: 46, height: 46)
            .animation(.spring(duration: 0.5), value: progress)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.color.opacity(0.10), in: shape)
        .overlay(shape.strokeBorder(color.color.opacity(0.16), lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityValue("\(chapter.completedLessonCount) von \(chapter.lessons.count) Lektionen")
    }
}

struct PathNode: View {
    var lesson: Lesson
    var number: Int
    var total: Int
    var isUnlocked: Bool
    var isNext: Bool
    var isLast: Bool
    var color: CourseColor
    var onStart: () -> Void
    @State private var showDetails = false

    private var icon: String {
        if !isUnlocked { return "lock.fill" }
        if lesson.isCompleted { return isLast ? "trophy.fill" : "checkmark" }
        return isLast ? "trophy.fill" : "star.fill"
    }

    private var fill: Color {
        if !isUnlocked { return Theme.locked }
        if lesson.isCompleted { return Theme.xp }
        return color.color
    }

    var body: some View {
        Button {
            showDetails = true
        } label: {
            Image(systemName: icon)
                .font(.system(size: 28, weight: .heavy))
                .foregroundStyle(isUnlocked ? .white : Color(.systemGray2))
        }
        .buttonStyle(NodeButtonStyle(color: fill))
        .overlay {
            if isNext {
                Circle()
                    .strokeBorder(color.color.opacity(0.3), lineWidth: 6)
                    .frame(width: 92, height: 92)
                    .offset(y: 2)
                    .allowsHitTesting(false)
            }
        }
        .overlay(alignment: .top) {
            if isNext && !showDetails {
                Text("Start")
                    .font(.subheadline.weight(.heavy))
                    .textCase(.uppercase)
                    .foregroundStyle(color.color)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Theme.border, lineWidth: 2))
                    .fixedSize()
                    .phaseAnimator([0.0, -6.0]) { content, phase in
                        content.offset(y: phase)
                    } animation: { _ in .easeInOut(duration: 0.8) }
                    .offset(y: -52)
                    .allowsHitTesting(false)
            }
        }
        .padding(.top, isNext ? 34 : 0)
        .popover(isPresented: $showDetails) {
            details
                .presentationCompactAdaptation(.popover)
        }
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(lesson.title)
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if isUnlocked {
                Button(lesson.isCompleted ? "Wiederholen  +10 XP" : "Starten  +10 XP") {
                    showDetails = false
                    // Erst das Popover schließen lassen, dann die Lektion im Vollbild öffnen.
                    Task {
                        try? await Task.sleep(for: .milliseconds(350))
                        onStart()
                    }
                }
                .buttonStyle(ChunkyButtonStyle(color: color.color))
            } else {
                Label("Schließe zuerst die vorherige Lektion ab.", systemImage: "lock.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .frame(width: 280, alignment: .leading)
    }

    private var subtitle: String {
        var parts = ["Lektion \(number) von \(total)"]
        if !lesson.exercises.isEmpty { parts.append("\(lesson.exercises.count) Übungen") }
        if let best = lesson.bestAccuracy { parts.append("Bestwert \(Int((best * 100).rounded()))%") }
        return parts.joined(separator: " · ")
    }
}

struct NodeButtonStyle: ButtonStyle {
    var color: Color
    var size: CGFloat = 72
    var depth: CGFloat = 7

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        configuration.label
            .frame(width: size, height: size - 4)
            .background(Ellipse().fill(color))
            .overlay(alignment: .top) {
                Ellipse()
                    .fill(.white.opacity(0.18))
                    .frame(width: size * 0.55, height: size * 0.18)
                    .padding(.top, size * 0.1)
            }
            .background(Ellipse().fill(color.mix(with: .black, by: 0.25)).offset(y: pressed ? 0 : depth))
            .offset(y: pressed ? depth : 0)
            .padding(.bottom, depth)
            .animation(.spring(duration: 0.12), value: pressed)
    }
}

// MARK: - Leere Zustände

struct WelcomeView: View {
    var onCreate: () -> Void

    var body: some View {
        VStack(spacing: 22) {
            Spacer()
            Image(systemName: "graduationcap.fill")
                .font(.system(size: 64))
                .foregroundStyle(Theme.primary.gradient)
                .padding(28)
                .background(Theme.primary.opacity(0.1), in: Circle())
            VStack(spacing: 10) {
                Text("Willkommen bei Lernly")
                    .font(.title.weight(.heavy))
                Text("Lege einen Kurs an, z. B. „Physik“, und importiere danach deinen Lernstoff als .lernly-Datei.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Spacer()
            Button("Ersten Kurs anlegen", action: onCreate)
                .buttonStyle(ChunkyButtonStyle())
        }
        .padding(24)
    }
}

struct EmptyCourseView: View {
    var course: Course
    var onFile: () -> Void
    var onPaste: () -> Void

    var body: some View {
        VStack(spacing: 22) {
            CourseIconTile(icon: course.icon, color: course.color.color, size: 96)
            VStack(spacing: 8) {
                Text("\(course.name) ist noch leer")
                    .font(.title2.weight(.heavy))
                    .multilineTextAlignment(.center)
                Text("Importiere eine .lernly-Datei. Jedes Kapitel daraus erscheint hier als Abschnitt in deinem Lernpfad.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            VStack(spacing: 6) {
                Button(action: onFile) {
                    Label("Datei importieren", systemImage: "doc.badge.plus")
                }
                .buttonStyle(ChunkyButtonStyle(color: course.color.color))
                Button(action: onPaste) {
                    Label("Text einfügen", systemImage: "doc.on.clipboard")
                }
                .buttonStyle(OutlineChunkyButtonStyle(tint: course.color.color))
            }
        }
        .padding(24)
    }
}

struct AddContentCard: View {
    var courseName: String
    var color: Color
    var onFile: () -> Void
    var onPaste: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "plus.circle.fill")
                .font(.largeTitle)
                .foregroundStyle(color)
            Text("Neuer Stoff für \(courseName)?")
                .font(.headline)
            Text("Neue Kapitel werden unten an den Pfad angehängt.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            HStack(spacing: 10) {
                Button("Datei", systemImage: "doc.badge.plus", action: onFile)
                    .buttonStyle(.bordered)
                Button("Einfügen", systemImage: "doc.on.clipboard", action: onPaste)
                    .buttonStyle(.bordered)
            }
            .tint(color)
            .font(.subheadline.weight(.semibold))
        }
        .padding(22)
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [7, 6]))
                .foregroundStyle(Theme.border)
        }
    }
}
