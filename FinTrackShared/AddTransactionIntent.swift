import AppIntents

@available(iOS 18.0, *)
struct AddTransactionIntent: AppIntent {
    static var title: LocalizedStringResource = "Добавить транзакцию"
    static var description = IntentDescription("Открывает форму новой транзакции в monёy")
    static var openAppWhenRun = true
    static var isDiscoverable = true

    func perform() async throws -> some IntentResult & OpensIntent {
        .result(opensIntent: OpenURLIntent(MonyDeepLink.addTransaction))
    }
}
