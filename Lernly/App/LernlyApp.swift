import SwiftUI

@main
struct LernlyApp: App {
    @State private var store = AppStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .fontDesign(.rounded)
                .onOpenURL { url in
                    // "Öffnen in Lernly" aus Dateien, Mail, AirDrop …
                    store.importFile(at: url, preferredCourseID: nil)
                }
        }
    }
}

struct RootView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        @Bindable var store = store
        TabView(selection: $store.selectedTab) {
            Tab("Lernen", systemImage: "graduationcap.fill", value: AppTab.learn) {
                LearnView()
            }
            Tab("Kurse", systemImage: "books.vertical.fill", value: AppTab.courses) {
                CoursesView()
            }
            Tab("Profil", systemImage: "flame.fill", value: AppTab.profile) {
                ProfileView()
            }
        }
        .tint(Theme.primary)
        .sheet(item: $store.pendingImport) { request in
            ImportRequestSheet(request: request)
        }
        .sheet(item: $store.importFailure) { failure in
            ImportErrorView(failure: failure)
        }
    }
}

#Preview {
    RootView()
        .environment(AppStore(inMemory: true))
        .fontDesign(.rounded)
}
