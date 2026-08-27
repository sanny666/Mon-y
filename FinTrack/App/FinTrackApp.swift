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
    @State private var chartEntrance = ChartEntranceController()
    @State private var lockController = AppLockController()
    @State private var showPrivacyCover = false
    @State private var showAddTransaction = false
    @State private var pendingAddTransaction = false
    @State private var isQuickAddFromDeepLink = false
    @State private var pendingReceiptJPEG: Data?
    @State private var pendingReceiptNote: String?

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

    /// Action Button / Control deep link — skip Face ID / PIN until the editor dismisses.
    private var isQuickAddActive: Bool {
        isQuickAddFromDeepLink || pendingAddTransaction
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
                        if lockController.hasPIN && hasCompletedOnboarding && container.isLoggedIn,
                           !isQuickAddActive {
                            lockController.lockIfNeeded(enabled: true)
                            Task { await attemptBiometricUnlock() }
                        }
                        consumeQuickAddIfNeeded()
                    }
            }
        }
        .environment(chartEntrance)
        .preferredColorScheme(preferredScheme)
        .tint(Color(hex: appAccentHex))
        .overlay {
            if shouldGateWithLock, lockController.isLocked, !isQuickAddActive {
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
        .fullScreenCover(isPresented: $showAddTransaction, onDismiss: {
            isQuickAddFromDeepLink = false
            pendingReceiptJPEG = nil
            pendingReceiptNote = nil
        }) {
            if let appContainer {
                TransactionEditorView(
                    transaction: nil,
                    initialJPEG: pendingReceiptJPEG,
                    initialNote: pendingReceiptNote
                )
                    .environment(appContainer)
                    .environment(lockController)
                    .preferredColorScheme(preferredScheme)
                    .tint(Color(hex: appAccentHex))
            }
        }
        .onAppear {
            if scenePhase == .active, chartEntrance.generation == 0 {
                chartEntrance.markAppBecameActive()
            }
        }
        .onChange(of: scenePhase) { oldPhase, phase in
            if phase == .active, oldPhase == .background {
                chartEntrance.markAppBecameActive()
            }
            handleScenePhase(phase)
        }
        .onChange(of: lockController.isLocked) { _, _ in
            presentAddTransactionIfPossible()
        }
        .onReceive(NotificationCenter.default.publisher(for: QuickAddFlag.didRequestNotification)) { _ in
            requestQuickAddFromBridge()
        }
        .onOpenURL { url in
            if url.isFileURL {
                try? ReceiptInbox.ingestFile(at: url)
                requestQuickAddFromBridge(consumeFlag: false)
                return
            }
            guard MonyDeepLink.isAddTransaction(url) else { return }
            requestQuickAddFromBridge(consumeFlag: false)
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
            consumeQuickAddIfNeeded()
            if shouldGateWithLock, lockController.isLocked, !isQuickAddActive {
                Task { await attemptBiometricUnlock() }
            }
            presentAddTransactionIfPossible()
        case .inactive:
            if shouldGateWithLock, !isQuickAddActive {
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
        guard faceIDEnabled, !isQuickAddActive else { return }
        _ = await lockController.authenticateWithBiometrics()
        presentAddTransactionIfPossible()
    }

    /// Action Button / Control writes a shared keychain flag; share extension writes a receipt + flag.
    private func consumeQuickAddIfNeeded() {
        let flagged = QuickAddFlag.consumePending()
        guard flagged || ReceiptInbox.hasPending else { return }
        requestQuickAddFromBridge(consumeFlag: false)
    }

    private func requestQuickAddFromBridge(consumeFlag: Bool = true) {
        if consumeFlag {
            _ = QuickAddFlag.consumePending()
        }
        isQuickAddFromDeepLink = true
        pendingAddTransaction = true
        presentAddTransactionIfPossible()
    }

    private func presentAddTransactionIfPossible() {
        guard pendingAddTransaction else { return }
        guard hasCompletedOnboarding, appContainer?.isLoggedIn == true else { return }
        // Deep-link / Action Button: open editor immediately without Face ID / PIN.
        lockController.unlockWithoutAuth()
        pendingAddTransaction = false
        if let receipt = ReceiptInbox.consume() {
            pendingReceiptJPEG = receipt.jpeg
            pendingReceiptNote = receipt.note
        }
        showAddTransaction = true
    }
}
