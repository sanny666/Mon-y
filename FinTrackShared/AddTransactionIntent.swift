import AppIntents

@available(iOS 18.0, *)
enum AddTransactionTarget: String, AppEnum {
    case newTransaction

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Экран")
    static var caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .newTransaction: DisplayRepresentation(title: "Новая транзакция")
    ]
}

/// Opens monёy to the quick-add transaction form.
/// Uses `OpenIntent` (not `OpenURLIntent` + custom scheme — Controls don't deliver those URLs).
@available(iOS 18.0, *)
struct AddTransactionIntent: OpenIntent {
    static var title: LocalizedStringResource = "Добавить транзакцию"
    static var description = IntentDescription("Открывает быструю форму новой транзакции в monёy")
    static var isDiscoverable = true

    @Parameter(title: "Target")
    var target: AddTransactionTarget

    init() {
        self.target = .newTransaction
    }

    init(target: AddTransactionTarget) {
        self.target = target
    }

    func perform() async throws -> some IntentResult {
        QuickAddFlag.markPending(kind: .add)
        return .result()
    }
}

/// Opens monёy to the voice transaction capture flow.
@available(iOS 18.0, *)
enum VoiceTransactionTarget: String, AppEnum {
    case voiceInput

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Экран")
    static var caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .voiceInput: DisplayRepresentation(title: "Голосовой ввод")
    ]
}

@available(iOS 18.0, *)
struct VoiceTransactionIntent: OpenIntent {
    static var title: LocalizedStringResource = "Голосовая транзакция"
    static var description = IntentDescription("Открывает голосовой ввод транзакции в monёy")
    static var isDiscoverable = true

    @Parameter(title: "Target")
    var target: VoiceTransactionTarget

    init() {
        self.target = .voiceInput
    }

    init(target: VoiceTransactionTarget) {
        self.target = target
    }

    func perform() async throws -> some IntentResult {
        QuickAddFlag.markPending(kind: .voice)
        return .result()
    }
}
