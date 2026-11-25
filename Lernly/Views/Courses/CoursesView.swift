import SwiftUI
import UniformTypeIdentifiers

struct CoursesView: View {
    @Environment(AppStore.self) private var store
    @State private var showNewCourse = false
    @State private var showFileImporter = false

    var body: some View {
        NavigationStack {
            ScrollView {
                if store.courses.isEmpty {
                    ContentUnavailableView {
                        Label("Noch keine Kurse", systemImage: "books.vertical")
                    } description: {
                        Text("Lernly startet bewusst leer. Lege einen Kurs an und importiere deinen Lernstoff.")
                    } actions: {
                        Button("Kurs anlegen") { showNewCourse = true }
                            .buttonStyle(.borderedProminent)
                    }
                    .padding(.top, 80)
                } else {
                    LazyVStack(spacing: 14) {
                        ForEach(store.courses) { course in
                            NavigationLink(value: course.id) {
                                CourseCard(course: course, isActive: course.id == store.activeCourse?.id)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(16)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Kurse")
            .navigationDestination(for: UUID.self) { id in
                CourseDetailView(courseID: id)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Neuer Kurs", systemImage: "plus") { showNewCourse = true }
                        Button("Datei importieren", systemImage: "doc.badge.plus") { showFileImporter = true }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showNewCourse) {
                CourseEditorSheet(course: nil)
            }
            .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.lernly, .json, .plainText]) { result in
                if case .success(let url) = result { store.importFile(at: url, preferredCourseID: nil) }
            }
        }
    }
}

struct CourseCard: View {
    var course: Course
    var isActive: Bool

    var body: some View {
        HStack(spacing: 14) {
            CourseIconTile(icon: course.icon, color: course.color.color, size: 56)
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(course.name)
                        .font(.headline)
                        .lineLimit(1)
                    if isActive {
                        Text("Aktiv")
                            .font(.caption2.weight(.heavy))
                            .textCase(.uppercase)
                            .foregroundStyle(course.color.color)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(course.color.color.opacity(0.12), in: Capsule())
                    }
                }
                Text(course.chapters.isEmpty ? "Noch leer" : "\(course.chapters.count) Kapitel · \(course.lessonCount) Lektionen")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                ProgressCapsule(value: course.progress, color: course.color.color, height: 8)
            }
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .contentShape(Rectangle())
    }
}

// MARK: - Kursdetails

struct CourseDetailView: View {
    let courseID: UUID
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var showEditor = false
    @State private var showFileImporter = false
    @State private var showPaste = false
    @State private var confirmDelete = false
    @State private var confirmReset = false
    @State private var chapterToDelete: Chapter?

    var body: some View {
        if let course = store.course(courseID) {
            content(course)
        } else {
            ContentUnavailableView("Kurs nicht gefunden", systemImage: "questionmark.folder")
        }
    }

    private func content(_ course: Course) -> some View {
        List {
            Section {
                VStack(spacing: 14) {
                    CourseIconTile(icon: course.icon, color: course.color.color, size: 72)
                    Text(course.name)
                        .font(.title2.weight(.heavy))
                    HStack(spacing: 18) {
                        metric("\(course.chapters.count)", "Kapitel")
                        metric("\(course.lessonCount)", "Lektionen")
                        metric("\(Int((course.progress * 100).rounded()))%", "Erledigt")
                    }
                    Button("Lernen") {
                        store.setActiveCourse(course.id)
                        store.selectedTab = .learn
                    }
                    .buttonStyle(ChunkyButtonStyle(color: course.color.color))
                    .disabled(course.chapters.isEmpty)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .listRowBackground(Color.clear)

            Section {
                Button("Datei importieren", systemImage: "doc.badge.plus") { showFileImporter = true }
                Button("Text einfügen", systemImage: "doc.on.clipboard") { showPaste = true }
            } header: {
                Text("Inhalte hinzufügen")
            } footer: {
                Text("Neue Kapitel werden unten an den Kurs angehängt. Dein bisheriger Fortschritt bleibt erhalten.")
            }

            if !course.chapters.isEmpty {
                Section("Kapitel") {
                    ForEach(Array(course.chapters.enumerated()), id: \.element.id) { index, chapter in
                        DisclosureGroup {
                            ForEach(chapter.lessons) { lesson in
                                HStack {
                                    Image(systemName: lesson.isCompleted ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(lesson.isCompleted ? Theme.correct : Color(.systemGray3))
                                    Text(lesson.title)
                                    Spacer()
                                    Text("\(lesson.exercises.count)")
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("\(index + 1). \(chapter.title)")
                                    .font(.body.weight(.semibold))
                                Text("\(chapter.completedLessonCount)/\(chapter.lessons.count) Lektionen · \(chapter.exerciseCount) Übungen")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .swipeActions {
                            Button("Löschen", systemImage: "trash", role: .destructive) { chapterToDelete = chapter }
                        }
                    }
                    .onMove { store.moveChapters(in: course.id, from: $0, to: $1) }
                }
            }
        }
        .navigationTitle(course.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Bearbeiten", systemImage: "pencil") { showEditor = true }
                    Button("Fortschritt zurücksetzen", systemImage: "arrow.counterclockwise") { confirmReset = true }
                    Divider()
                    Button("Kurs löschen", systemImage: "trash", role: .destructive) { confirmDelete = true }
                } label: {
                    Image(systemName: "ellipsis")
                }
            }
        }
        .sheet(isPresented: $showEditor) { CourseEditorSheet(course: course) }
        .sheet(isPresented: $showPaste) { PasteImportSheet(preferredCourseID: course.id) }
        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.lernly, .json, .plainText]) { result in
            if case .success(let url) = result { store.importFile(at: url, preferredCourseID: course.id) }
        }
        .confirmationDialog("„\(course.name)“ löschen?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Kurs löschen", role: .destructive) {
                dismiss()
                store.deleteCourse(course.id)
            }
        } message: {
            Text("Alle Kapitel und dein Fortschritt in diesem Kurs werden entfernt. Das kann nicht rückgängig gemacht werden.")
        }
        .confirmationDialog("Fortschritt zurücksetzen?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Zurücksetzen", role: .destructive) { store.resetProgress(of: course.id) }
        } message: {
            Text("Alle Lektionen in „\(course.name)“ werden wieder als offen markiert. XP und Streak bleiben.")
        }
        .confirmationDialog(
            "Kapitel löschen?",
            isPresented: Binding(get: { chapterToDelete != nil }, set: { if !$0 { chapterToDelete = nil } }),
            titleVisibility: .visible,
            presenting: chapterToDelete
        ) { chapter in
            Button("„\(chapter.title)“ löschen", role: .destructive) {
                store.deleteChapter(chapter.id, in: course.id)
            }
        }
    }

    private func metric(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.headline.monospacedDigit())
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
    }
}

// MARK: - Kurs anlegen / bearbeiten

struct CourseEditorSheet: View {
    var course: Course?
    var suggestedName: String = ""
    var onCreate: ((Course) -> Void)?

    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var icon = "atom"
    @State private var color: CourseColor = .indigo
    @FocusState private var nameFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 12) {
                            CourseIconTile(icon: icon, color: color.color, size: 84)
                            Text(name.isEmpty ? "Kursname" : name)
                                .font(.title3.weight(.bold))
                                .foregroundStyle(name.isEmpty ? .tertiary : .primary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 6)
                }
                .listRowBackground(Color.clear)

                Section("Name") {
                    TextField("z. B. Physik", text: $name)
                        .focused($nameFocused)
                        .submitLabel(.done)
                }

                Section("Farbe") {
                    HStack {
                        ForEach(CourseColor.allCases) { option in
                            Circle()
                                .fill(option.color)
                                .frame(width: 30, height: 30)
                                .overlay {
                                    if option == color {
                                        Image(systemName: "checkmark")
                                            .font(.caption.weight(.heavy))
                                            .foregroundStyle(.white)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .onTapGesture { color = option }
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Symbol") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 6), spacing: 10) {
                        ForEach(CourseIcons.all, id: \.self) { symbol in
                            Image(systemName: symbol)
                                .font(.title3)
                                .frame(width: 44, height: 44)
                                .foregroundStyle(symbol == icon ? .white : .primary)
                                .background(symbol == icon ? color.color : Color(.tertiarySystemFill),
                                            in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .onTapGesture { icon = symbol }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle(course == nil ? "Neuer Kurs" : "Kurs bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(course == nil ? "Anlegen" : "Sichern") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if let course {
                    name = course.name
                    icon = course.icon
                    color = course.color
                } else {
                    name = suggestedName
                    color = CourseColor.allCases[store.courses.count % CourseColor.allCases.count]
                    nameFocused = true
                }
            }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if let course {
            store.updateCourse(course.id, name: trimmed, icon: icon, color: color)
        } else {
            let created = store.createCourse(name: trimmed, icon: icon, color: color)
            onCreate?(created)
        }
        dismiss()
    }
}
