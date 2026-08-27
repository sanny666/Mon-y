import SwiftData
import SwiftUI

@main
struct FinTrackApp: App {
    private let container: ModelContainer

    init() {
        FreshInstall.resetStaleSecretsIfNeeded()
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
    @AppStorage(AppStorageKeys.appAccentHex) private var appAccentHex = AppAccent.defaultHex
    @AppStorage(AppStorageKeys.faceIDEnabled) private var faceIDEnabled = false
    @State private var appContainer: AppContainer?
    @State private var lockController = AppLockController()
    @State private var showPrivacyCover = false
    @State private var showAddTransaction = false
    @State private var pendingAddTransaction = false

    private var preferredScheme: ColorScheme? {
        switch AppTheme(rawValue: appThemeRaw) ?? .system {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    /// App lock requires a PIN set during onboarding.
    private var shouldGateWithLock: Bool {
        lockController.hasPIN
            && hasCompletedOnboarding
            && (appContainer?.isLoggedIn ?? false)
    }

    var body: some View {
        Group {
            if let appContainer {
                rootContent(appContainer)
                    .environment(appContainer)
                    .environment(lockController)
                    .id("session-\(appContainer.sessionEpoch)")
            } else {
                DashboardSkeleton()
                    .onAppear {
                        let container = AppContainer(context: modelContext)
                        container.seedDefaultCategoriesIfNeeded()
                        container.processDueRecurring()
                        container.publishWidgetSnapshot()
                        appContainer = container
                        if lockController.hasPIN && hasCompletedOnboarding && container.isLoggedIn {
                            lockController.lockIfNeeded(enabled: true)
                            Task { await attemptBiometricUnlock() }
                        }
                        presentAddTransactionIfPossible()
                    }
            }
        }
        .preferredColorScheme(preferredScheme)
        .tint(Color(hex: appAccentHex))
        .overlay {
            if shouldGateWithLock, lockController.isLocked {
                AppLockView(
                    lockController: lockController,
                    faceIDEnabled: faceIDEnabled
                ) {
                    Task { await attemptBiometricUnlock() }
                }
                .transition(.opacity)
                .zIndex(2)
            }
        }
        .overlay {
            if showPrivacyCover {
                AppPrivacyCover()
                    .zIndex(3)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            handleScenePhase(phase)
        }
        .onChange(of: lockController.isLocked) { _, _ in
            presentAddTransactionIfPossible()
        }
        .onOpenURL { url in
            guard MonyDeepLink.isAddTransaction(url) else { return }
            pendingAddTransaction = true
            presentAddTransactionIfPossible()
        }
    }

    @ViewBuilder
    private func rootContent(_ container: AppContainer) -> some View {
        let loggedIn = container.isLoggedIn
        let needsPIN = !lockController.hasPIN

        if loggedIn && hasCompletedOnboarding && needsPIN {
            // Migration: older installs without PIN must set one before using the app.
            OnboardingView(entryMode: .pinOnly) {
                hasCompletedOnboarding = true
                lockController.unlockWithoutAuth()
            }
        } else if loggedIn && hasCompletedOnboarding {
            MainTabView()
                .sheet(isPresented: $showAddTransaction) {
                    TransactionEditorView(transaction: nil)
                }
        } else if loggedIn && !hasCompletedOnboarding {
            OnboardingView(entryMode: .setupOnly) {
                hasCompletedOnboarding = true
            }
        } else if !loggedIn && hasCompletedOnboarding {
            OnboardingView(entryMode: .authOnly) {
                // After login: if PIN missing, OnboardingView routes to pin step;
                // when PIN exists, sessionEpoch remounts into MainTabView.
            }
        } else {
            OnboardingView(entryMode: .full) {
                hasCompletedOnboarding = true
            }
        }
    }

    private func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .active:
            showPrivacyCover = false
            appContainer?.handleSceneBecameActive()
            if shouldGateWithLock, lockController.isLocked {
                Task { await attemptBiometricUnlock() }
            }
            presentAddTransactionIfPossible()
        case .inactive:
            if shouldGateWithLock {
                showPrivacyCover = true
            }
        case .background:
            showPrivacyCover = false
            if shouldGateWithLock {
                lockController.lockIfNeeded(enabled: true)
            }
        @unknown default:
            break
        }
    }

    private func attemptBiometricUnlock() async {
        guard faceIDEnabled else { return }
        _ = await lockController.authenticateWithBiometrics()
        presentAddTransactionIfPossible()
    }

    private func presentAddTransactionIfPossible() {
        guard pendingAddTransaction else { return }
        guard hasCompletedOnboarding, appContainer?.isLoggedIn == true else { return }
        if shouldGateWithLock, lockController.isLocked { return }
        pendingAddTransaction = false
        showAddTransaction = true
    }
}
