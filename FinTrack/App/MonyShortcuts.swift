import AppIntents

@available(iOS 18.0, *)
struct MonyShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddTransactionIntent(),
            phrases: [
                "Добавить транзакцию в \(.applicationName)",
                "Новая транзакция в \(.applicationName)"
            ],
            shortTitle: "Транзакция",
            systemImageName: "plus"
        )
    }
}
