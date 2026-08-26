import SwiftData
import SwiftUI

@main
struct FinTrackApp: App {
    private let container: ModelContainer

    init() {
        let schema = Schema([
            Account.self,
            Category.self,
            Transaction.self,
            Budget.self,
            Goal.self,
            RecurringTransaction.self
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: false)
        do {
            container = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Не удалось создать ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(AppStorageKeys.hasCompletedOnboarding) private var hasCompletedOnboarding = false
    @AppStorage(AppStorageKeys.appTheme) private var appThemeRaw = AppTheme.system.rawValue
    @State private var appContainer: AppContainer?

    private var preferredScheme: ColorScheme? {
        switch AppTheme(rawValue: appThemeRaw) ?? .system {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    var body: some View {
        Group {
            if let appContainer {
                if hasCompletedOnboarding {
                    MainTabView()
                        .environment(appContainer)
                } else {
                    OnboardingView {
                        hasCompletedOnboarding = true
                    }
                    .environment(appContainer)
                }
            } else {
                ProgressView("Загрузка…")
                    .onAppear {
                        let container = AppContainer(context: modelContext)
                        container.seedDefaultCategoriesIfNeeded()
                        container.processDueRecurring()
                        appContainer = container
                    }
            }
        }
        .preferredColorScheme(preferredScheme)
        .tint(Color(hex: "#268F6B"))
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                appContainer?.handleSceneBecameActive()
            }
        }
    }
}
