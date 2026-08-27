import SwiftUI

private struct GuidePage: Identifiable {
    let id: Int
    let title: String
    let subtitle: String
    let systemImage: String
}

struct OnboardingGuideView: View {
    let onFinish: () -> Void
    @State private var page = 0

    private let pages: [GuidePage] = [
        .init(
            id: 0,
            title: "Транзакции",
            subtitle: "Доходы, расходы и переводы в одном списке. Добавляйте за пару касаний.",
            systemImage: "list.bullet.rectangle"
        ),
        .init(
            id: 1,
            title: "Счета",
            subtitle: "Карты, наличные и депозиты. Общий баланс всегда на главном экране.",
            systemImage: "creditcard"
        ),
        .init(
            id: 2,
            title: "Бюджеты и синхронизация",
            subtitle: "Планируйте месяц и держите данные одинаковыми на всех устройствах.",
            systemImage: "icloud"
        )
    ]

    var body: some View {
        OnboardingScaffold(
            step: 4,
            title: "Краткий гид",
            subtitle: "Три вещи, которые стоит знать перед стартом."
        ) {
            VStack(spacing: 16) {
                TabView(selection: $page) {
                    ForEach(pages) { item in
                        guideCard(item)
                            .tag(item.id)
                            .padding(.horizontal, OnboardingLayout.horizontalPadding)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                HStack(spacing: 8) {
                    ForEach(pages) { item in
                        Circle()
                            .fill(item.id == page ? Color.accentColor : Color.secondary.opacity(0.25))
                            .frame(width: 7, height: 7)
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: page)
            }
        } footer: {
            OnboardingPrimaryButton(
                title: page == pages.count - 1 ? "Начать пользоваться" : "Далее"
            ) {
                if page < pages.count - 1 {
                    withAnimation(.easeInOut(duration: 0.25)) { page += 1 }
                } else {
                    onFinish()
                }
            }
        }
    }

    private func guideCard(_ item: GuidePage) -> some View {
        OnboardingCard {
            VStack(spacing: 20) {
                Image(systemName: item.systemImage)
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(Color.accentColor)
                    .symbolRenderingMode(.hierarchical)
                    .frame(width: 80, height: 80)
                    .background(
                        Circle()
                            .fill(Color.accentColor.opacity(0.12))
                    )

                VStack(spacing: 8) {
                    Text(item.title)
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                    Text(item.subtitle)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
        }
        .frame(maxHeight: .infinity, alignment: .center)
    }
}
