import SwiftUI
import UIKit

// MARK: - Vorschau vor dem Import

struct ImportPreviewView: View {
    var package: ParsedPackage
    var preferredCourseID: UUID?
    var onFinished: () -> Void

    @Environment(AppStore.self) private var store
    @State private var target: Target = .new
    @State private var newCourseName = ""
    @State private var included: Set<UUID> = []
    @State private var didSetup = false

    enum Target: Hashable {
        case existing(UUID)
        case new
    }

    private var targetCourse: Course? {
        if case .existing(let id) = target { return store.course(id) }
        return nil
    }

    private var existingTitles: Set<String> {
        Set((targetCourse?.chapters ?? []).map { $0.title.lowercased() })
    }

    private var selectedChapters: [Chapter] {
        package.chapters.filter { included.contains($0.id) }
    }

    var body: some View {
        Form {
            Section {
                VStack(spacing: 10) {
                    Image(systemName: "shippingbox.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(Theme.primary)
                    Text("\(package.chapters.count) Kapitel · \(package.lessonCount) Lektionen · \(package.exerciseCount) Übungen")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
            }
            .listRowBackground(Color.clear)

            Section {
                Picker("Hinzufügen zu", selection: $target) {
                    ForEach(store.courses) { course in
                        Label(course.name, systemImage: course.icon).tag(Target.existing(course.id))
                    }
                    Label("Neuer Kurs", systemImage: "plus").tag(Target.new)
                }
                if target == .new {
                    TextField("Name des neuen Kurses", text: $newCourseName)
                }
            } header: {
                Text("Ziel-Kurs")
            } footer: {
                if let fileCourse = package.courseName, let course = targetCourse,
                   fileCourse.lowercased() != course.name.lowercased() {
                    Label("Die Datei ist für „\(fileCourse)“ gedacht.", systemImage: "info.circle")
                }
            }

            Section {
                ForEach(package.chapters) { chapter in
                    let duplicate = existingTitles.contains(chapter.title.lowercased())
                    Toggle(isOn: Binding(
                        get: { included.contains(chapter.id) },
                        set: { if $0 { included.insert(chapter.id) } else { included.remove(chapter.id) } }
                    )) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(chapter.title).font(.body.weight(.semibold))
                            Text("\(chapter.lessons.count) Lektionen · \(chapter.exerciseCount) Übungen")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if duplicate {
                                Label("Existiert schon im Kurs", systemImage: "exclamationmark.triangle.fill")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                }
            } header: {
                Text("Kapitel")
            } footer: {
                Text("Die Kapitel werden in dieser Reihenfolge unten an den Kurs angehängt.")
            }

            if !package.warnings.isEmpty {
                Section("Hinweise") {
                    ForEach(package.warnings, id: \.self) { warning in
                        Label(warning, systemImage: "info.circle")
                            .font(.footnote)
                    }
                }
            }
        }
        .navigationTitle("Import")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Button(selectedChapters.count == 1 ? "1 Kapitel hinzufügen" : "\(selectedChapters.count) Kapitel hinzufügen") {
                performImport()
            }
            .buttonStyle(ChunkyButtonStyle(color: targetCourse?.color.color ?? Theme.primary))
            .disabled(selectedChapters.isEmpty || (target == .new && newCourseName.trimmingCharacters(in: .whitespaces).isEmpty))
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .background(.bar)
        }
        .onAppear(perform: setup)
        .onChange(of: target) { _, _ in selectNonDuplicates() }
    }

    private func setup() {
        guard !didSetup else { return }
        didSetup = true
        newCourseName = package.courseName ?? ""
        if let id = preferredCourseID, store.course(id) != nil {
            target = .existing(id)
        } else if let name = package.courseName,
                  let match = store.courses.first(where: { $0.name.lowercased() == name.lowercased() }) {
            target = .existing(match.id)
        } else if package.courseName == nil, let first = store.activeCourse {
            target = .existing(first.id)
        } else {
            target = .new
        }
        selectNonDuplicates()
    }

    private func selectNonDuplicates() {
        included = Set(package.chapters.filter { !existingTitles.contains($0.title.lowercased()) }.map(\.id))
    }

    private func performImport() {
        let courseID: UUID
        switch target {
        case .existing(let id):
            courseID = id
        case .new:
            let index = store.courses.count % CourseColor.allCases.count
            courseID = store.createCourse(name: newCourseName.trimmingCharacters(in: .whitespaces),
                                          icon: "book.fill", color: CourseColor.allCases[index]).id
        }
        store.appendChapters(selectedChapters, to: courseID)
        store.setActiveCourse(courseID)
        store.selectedTab = .learn
        onFinished()
    }
}

/// Sheet, das von der App-Wurzel aus geöffnet wird (Dateiauswahl / "Öffnen in Lernly").
struct ImportRequestSheet: View {
    var request: ImportRequest
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ImportPreviewView(package: request.package, preferredCourseID: request.preferredCourseID) {
                dismiss()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Fehler

struct ImportIssuesList: View {
    var issues: [String]

    var body: some View {
        ForEach(Array(issues.prefix(40).enumerated()), id: \.offset) { _, issue in
            Label {
                Text(issue).font(.footnote)
            } icon: {
                Image(systemName: "xmark.octagon.fill").foregroundStyle(Theme.wrong)
            }
        }
        if issues.count > 40 {
            Text("… und \(issues.count - 40) weitere").font(.footnote).foregroundStyle(.secondary)
        }
    }

    static func reportForAI(_ issues: [String]) -> String {
        "Beim Import in Lernly sind folgende Fehler aufgetreten. Bitte korrigiere die .lernly-Datei und gib sie vollständig neu aus:\n"
            + issues.map { "- \($0)" }.joined(separator: "\n")
    }
}

struct ImportErrorView: View {
    var failure: ImportFailure
    @Environment(\.dismiss) private var dismiss
    @State private var copied = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Die Datei konnte nicht importiert werden.")
                            .font(.headline)
                        Text("Kopiere die Fehler und schick sie der KI, die die Datei erstellt hat – sie kann sie direkt korrigieren.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                Section("Fehler") {
                    ImportIssuesList(issues: failure.issues)
                }
            }
            .navigationTitle("Import fehlgeschlagen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button(copied ? "Kopiert!" : "Fehler für KI kopieren") {
                    UIPasteboard.general.string = ImportIssuesList.reportForAI(failure.issues)
                    copied = true
                }
                .buttonStyle(ChunkyButtonStyle(color: copied ? Theme.correct : Theme.primary))
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .background(.bar)
            }
        }
    }
}

// MARK: - Text einfügen

struct PasteImportSheet: View {
    var preferredCourseID: UUID?
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var package: ParsedPackage?
    @State private var issues: [String] = []
    @State private var showPreview = false
    @State private var copied = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    PasteButton(payloadType: String.self) { strings in
                        if let first = strings.first {
                            text = first
                            validate()
                        }
                    }
                    .labelStyle(.titleAndIcon)
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                }
                Section {
                    TextEditor(text: $text)
                        .font(.system(.footnote, design: .monospaced))
                        .frame(minHeight: 220)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onChange(of: text) { _, _ in issues = [] }
                } header: {
                    Text("Inhalt der .lernly-Datei")
                } footer: {
                    Text("Füge den kompletten JSON-Code ein, den dir die KI erstellt hat. Codeblock-Markierungen (```) werden automatisch entfernt.")
                }
                if !issues.isEmpty {
                    Section("Fehler") {
                        ImportIssuesList(issues: issues)
                        Button(copied ? "Kopiert!" : "Fehler für KI kopieren", systemImage: "doc.on.doc") {
                            UIPasteboard.general.string = ImportIssuesList.reportForAI(issues)
                            copied = true
                        }
                    }
                }
            }
            .navigationTitle("Text einfügen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Prüfen") { validate() }
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .navigationDestination(isPresented: $showPreview) {
                if let package {
                    ImportPreviewView(package: package, preferredCourseID: preferredCourseID) { dismiss() }
                }
            }
        }
    }

    private func validate() {
        copied = false
        do {
            package = try LernlyParser.parse(text: text)
            issues = []
            showPreview = true
        } catch let error as LernlyParseError {
            issues = error.issues
        } catch {
            issues = [error.localizedDescription]
        }
    }
}
