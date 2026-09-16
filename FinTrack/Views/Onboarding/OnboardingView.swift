import SwiftUI

struct OnboardingView: View {
    enum Phase: Hashable {
        case setup
        case pin
        case guide
    }

    enum EntryMode {
        /// First launch: registration → setup → pin → guide
        case full
        /// Logged out returning user: login/register only
        case authOnly
        /// Logged in, setup/guide/pin not finished
        case setupOnly
        /// Logged in user without PIN (migration / interrupted onboarding)
        case pinOnly
    }

    let entryMode: EntryMode
    let onComplete: () -> Void

    @Environment(AppLockController.self) private var lockController
    @Environment(\.appAccentColor) private var accent
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            root
                .navigationDestination(for: Phase.self) { phase in
                    switch phase {
                    case .setup:
                        OnboardingSetupView {
                            path.append(Phase.pin)
                        }
                    case .pin:
                        OnboardingPINView {
                            if entryMode == .authOnly {
                                onComplete()
                            } else {
                                path.append(Phase.guide)
                            }
                        }
                    case .guide:
                        OnboardingGuideView(onFinish: onComplete)
                    }
                }
        }
        .tint(accent)
    }

    @ViewBuilder
    private var root: some View {
        switch entryMode {
        case .full, .authOnly:
            OnboardingAuthView { isNewRegistration in
                if entryMode == .authOnly {
                    if lockController.hasPIN {
                        onComplete()
                    } else {
                        path.append(Phase.pin)
                    }
                } else if isNewRegistration {
                    path.append(Phase.setup)
                } else {
                    // Login into existing account: setup is skipped in AppContainer.login.
                    if lockController.hasPIN {
                        onComplete()
                    } else {
                        path.append(Phase.pin)
                    }
                }
            }
        case .setupOnly:
            OnboardingSetupView {
                path.append(Phase.pin)
            }
        case .pinOnly:
            OnboardingPINView {
                onComplete()
            }
        }
    }
}
