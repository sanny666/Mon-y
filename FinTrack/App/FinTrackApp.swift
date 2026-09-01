import SwiftData
import SwiftUI

@main
struct FinTrackApp: App {
    @State private var modelContainer: ModelContainer?

    init() {
        FreshInstall.resetStaleSecretsIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let modelContainer {
                    RootView()
                        .modelContainer(modelContainer)
                } else {
                    DashboardSkeleton()
                        .task(priority: .userInitiated) {
                            let container = await Task.detached(priority: .userInitiated) {
                                Self.makeModelContainer()
                            }.value
                            modelContainer = container
                        }
                }
            }
        }
    }

    private static func makeModelContainer() -> ModelContainer {
        let schema = Schema([
            Account.self,
            Category.self,
            Transaction.self,
            Budget.self,
            Goal.self,
            RecurringTransaction.self,
            ItemDictionaryEntry.self
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Не удалось создать ModelContainer: \(error)")
        }
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
    @State private var pendingQuickAddKind: QuickAddKind?
    @State private var isQuickAddFromDeepLink = false
    @State private var quickAddRoute: QuickAddRoute?

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

    /// Action Button / Control deep link — skip Face ID / PIN until the cover dismisses.
    private var isQuickAddActive: Bool {
        isQuickAddFromDeepLink || pendingQuickAddKind != nil || quickAddRoute != nil
    }

    var body: some View {
        Group {
            if let appContainer {
                rootContent(appContainer)
                    .environment(appContainer)
                    .environment(appContainer.voiceInput)
                    .environment(lockController)
                    .id("session-\(appContainer.sessionEpoch)")
            } else {
                DashboardSkeleton()
                    .task(priority: .userInitiated) {
                        let container = AppContainer(context: modelContext)
                        container.seedDefaultCategoriesIfNeeded()
                        container.processDueRecurring()
                        container.publishWidgetSnapshot()
                        appContainer = container
                        if lockController.hasPIN && hasCompletedOnboarding && container.isLoggedIn,
                           !isQuickAddActive {
                            lockController.lockIfNeeded(enabled: true)
                            await attemptBiometricUnlock()
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
        .fullScreenCover(item: $quickAddRoute, onDismiss: {
            isQuickAddFromDeepLink = false
        }) { route in
            if let appContainer {
                quickAddContent(route: route, container: appContainer)
                    .environment(appContainer)
                    .environment(appContainer.voiceInput)
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
            presentQuickAddIfPossible()
        }
        .onChange(of: hasCompletedOnboarding) { _, _ in
            presentQuickAddIfPossible()
        }
        .onChange(of: appContainer?.sessionEpoch) { _, _ in
            presentQuickAddIfPossible()
        }
        .onChange(of: appContainer?.isLoggedIn) { _, _ in
            presentQuickAddIfPossible()
        }
        .onReceive(NotificationCenter.default.publisher(for: QuickAddFlag.didRequestNotification)) { _ in
            requestQuickAddFromBridge()
        }
        .onOpenURL { url in
            if url.isFileURL {
                try? ReceiptInbox.ingestFile(at: url)
                requestQuickAddFromBridge(kind: .add, consumeFlag: false)
                return
            }
            if MonyDeepLink.isVoiceTransaction(url) {
                requestQuickAddFromBridge(kind: .voice, consumeFlag: false)
                return
            }
            guard MonyDeepLink.isAddTransaction(url) else { return }
            requestQuickAddFromBridge(kind: .add, consumeFlag: false)
        }
    }

    @ViewBuilder
    private func quickAddContent(route: QuickAddRoute, container: AppContainer) -> some View {
        switch route.kind {
        case .editor(let receipt):
            TransactionEditorView(
                transaction: nil,
                initialJPEG: receipt?.jpeg,
                initialNote: receipt?.note,
                fromSharedInbox: receipt != nil
            )
        case .voice:
            VoiceQuickAddFlowView()
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
            presentQuickAddIfPossible()
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
        presentQuickAddIfPossible()
    }

    /// Action Button / Control writes a shared keychain flag; share extension writes a receipt + flag.
    private func consumeQuickAddIfNeeded() {
        let kind = QuickAddFlag.consumePending()
        if ReceiptInbox.hasPending {
            // Receipt must not be lost — inbox always wins over a voice flag.
            pendingQuickAddKind = .add
            isQuickAddFromDeepLink = true
            presentQuickAddIfPossible()
            return
        }
        guard let kind else { return }
        pendingQuickAddKind = kind
        isQuickAddFromDeepLink = true
        presentQuickAddIfPossible()
    }

    private func requestQuickAddFromBridge(kind: QuickAddKind? = nil, consumeFlag: Bool = true) {
        let resolved: QuickAddKind
        if consumeFlag {
            resolved = QuickAddFlag.consumePending() ?? kind ?? .add
        } else {
            resolved = kind ?? .add
        }

        if ReceiptInbox.hasPending {
            pendingQuickAddKind = .add
        } else {
            pendingQuickAddKind = resolved
        }
        isQuickAddFromDeepLink = true
        presentQuickAddIfPossible()
    }

    private func presentQuickAddIfPossible() {
        guard let kind = pendingQuickAddKind else { return }
        guard hasCompletedOnboarding, appContainer?.isLoggedIn == true else { return }

        // Deep-link / Action Button: open immediately without Face ID / PIN.
        lockController.unlockWithoutAuth()
        pendingQuickAddKind = nil

        // Last-write-wins: dismiss any open cover, then present with a fresh identity.
        let next = QuickAddRoute(kind: kind == .voice ? .voice : .editor(ReceiptInbox.peek()))
        if quickAddRoute != nil {
            quickAddRoute = nil
            DispatchQueue.main.async {
                quickAddRoute = next
            }
        } else {
            quickAddRoute = next
        }
    }
}

private struct QuickAddRoute: Identifiable {
    enum Kind {
        case editor(PendingReceipt?)
        case voice
    }

    let id = UUID()
    let kind: Kind
}
