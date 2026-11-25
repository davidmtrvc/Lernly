import SwiftUI
import UIKit

struct SettingsView: View {
    @Environment(AppStore.self) private var store
    @State private var confirmReset = false

    var body: some View {
        Form {
            Section {
                Picker("Tagesziel", selection: Binding(get: { store.stats.dailyGoal }, set: { store.setDailyGoal($0) })) {
                    Text("1 Lektion").tag(1)
                    Text("2 Lektionen").tag(2)
                    Text("3 Lektionen").tag(3)
                    Text("5 Lektionen").tag(5)
                }
            } header: {
                Text("Lernen")
            } footer: {
                Text("Für deinen Streak reicht eine Lektion pro Tag. Das Tagesziel ist dein persönlicher Ansporn.")
            }

            Section("Daten") {
                Button("Alle Daten löschen", role: .destructive) { confirmReset = true }
            }

            Section("Über") {
                LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                LabeledContent("Dateiformat", value: ".lernly v\(LernlyParser.formatVersion)")
            }

            // Bewusst unauffällig ganz unten
            Section {
                NavigationLink {
                    SyntaxTemplateView()
                } label: {
                    Label("Dateiformat & KI-Vorlage", systemImage: "curlybraces")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Für Fortgeschrittene")
            } footer: {
                Text("Vorlage, mit der jede KI deinen Lernstoff in eine .lernly-Datei umwandeln kann.")
            }
        }
        .navigationTitle("Einstellungen")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Alle Daten löschen?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Alles löschen", role: .destructive) { store.resetAllData() }
        } message: {
            Text("Alle Kurse, XP und dein Streak werden gelöscht. Das kann nicht rückgängig gemacht werden.")
        }
    }
}

struct SyntaxTemplateView: View {
    @State private var copiedPrompt = false
    @State private var copiedExample = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("So geht's: Kopiere den Prompt, füge ihn in eine beliebige KI ein (ChatGPT, Claude, Gemini …) und hänge deinen Lernstoff an. Die Antwort speicherst du als .lernly-Datei oder fügst sie im Kurs über **Text einfügen** ein.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 10) {
                    Button {
                        UIPasteboard.general.string = LernlySpec.prompt
                        copiedPrompt = true
                    } label: {
                        Label(copiedPrompt ? "Kopiert" : "KI-Prompt kopieren", systemImage: copiedPrompt ? "checkmark" : "doc.on.doc")
                    }
                    .buttonStyle(ChunkyButtonStyle())
                    ShareLink(item: LernlySpec.prompt) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .buttonStyle(OutlineChunkyButtonStyle())
                    .frame(width: 64)
                }

                // Kompakter Spickzettel – passt auf einen Screenshot.
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        SectionLabel(text: "Lernly-Syntax (.lernly = JSON)", color: Theme.primary)
                        Spacer()
                        Image(systemName: "curlybraces")
                            .foregroundStyle(Theme.primary)
                    }
                    Text(LernlySpec.cheatSheet)
                        .font(.system(size: 11, design: .monospaced))
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(16)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                DisclosureGroup("Vollständiges Beispiel") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(LernlySpec.example)
                            .font(.system(size: 11, design: .monospaced))
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                        Button(copiedExample ? "Kopiert" : "Beispiel kopieren", systemImage: "doc.on.doc") {
                            UIPasteboard.general.string = LernlySpec.example
                            copiedExample = true
                        }
                        .font(.subheadline.weight(.semibold))
                    }
                    .padding(.top, 8)
                }
                .tint(Theme.primary)
                .padding(16)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .padding(16)
        }
        .navigationTitle("KI-Vorlage")
        .navigationBarTitleDisplayMode(.inline)
    }
}
