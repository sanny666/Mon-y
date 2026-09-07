import SwiftUI

struct DashboardCard<Content: View, SurfaceOverlay: View>: View {
    var verticalPadding: CGFloat = 16
    @ViewBuilder var content: Content
    @ViewBuilder var surfaceOverlay: SurfaceOverlay

    init(
        verticalPadding: CGFloat = 16,
        @ViewBuilder surfaceOverlay: () -> SurfaceOverlay,
        @ViewBuilder content: () -> Content
    ) {
        self.verticalPadding = verticalPadding
        self.content = content()
        self.surfaceOverlay = surfaceOverlay()
    }

    var body: some View {
        content
            .padding(.horizontal, MoneyLayout.pageInset)
            .padding(.vertical, verticalPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                AppCardSurface()
                    .overlay {
                        surfaceOverlay
                    }
                    .clipShape(RoundedRectangle(cornerRadius: MoneyLayout.cardRadius, style: .continuous))
            }
    }

}

extension DashboardCard where SurfaceOverlay == EmptyView {
    init(
        verticalPadding: CGFloat = 16,
        @ViewBuilder content: () -> Content
    ) {
        self.init(verticalPadding: verticalPadding, surfaceOverlay: { EmptyView() }, content: content)
    }
}

/// Shared card chrome for dashboard tiles and analytics blocks.
struct AppCardSurface: View {
    var cornerRadius: CGFloat = MoneyLayout.cardRadius
    var body: some View { MoneyCardSurface(cornerRadius: cornerRadius) }
}

struct AppListRowBackground: View {
    var body: some View { Color(uiColor: .secondarySystemGroupedBackground) }
}

extension View {
    /// Same surface language as dashboard cards for inset grouped lists / forms.
    func appGroupedList() -> some View {
        self
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(MoneyPalette.canvas)
            .listRowBackground(AppListRowBackground())
            .contentMargins(.top, 12, for: .scrollContent)
            .environment(\.defaultMinListRowHeight, 52)
            .frame(maxWidth: MoneyLayout.contentWidth)
            .frame(maxWidth: .infinity)
            .background(MoneyPalette.canvas)
    }
}

struct DashboardSectionHeader: View {
    let title: String
    let systemImage: String
    var tint: Color = Color(hex: "#268F6B")
    var tintTitle: Bool = false
    var compact: Bool = false
    var action: (() -> Void)?

    var body: some View {
        Group {
            if let action {
                Button(action: action) {
                    label
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .accessibilityAddTraits(.isButton)
            } else {
                label
            }
        }
    }

    private var label: some View {
        HStack(spacing: compact ? 6 : 8) {
            Image(systemName: systemImage)
                .font((compact ? Font.subheadline : Font.body).weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: compact ? 18 : 22, alignment: .center)
            Text(title)
                .font(compact ? .subheadline.weight(.semibold) : .headline)
                .foregroundStyle(tintTitle ? tint : Color.primary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            if action != nil {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}
