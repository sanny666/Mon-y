import SwiftUI

struct DashboardCard<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var verticalPadding: CGFloat = 16
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(.horizontal, 16)
            .padding(.vertical, verticalPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background { AppCardSurface() }
            .shadow(
                color: shadowColor,
                radius: reduceTransparency ? 0 : (colorScheme == .dark ? 0 : 4),
                x: 0,
                y: reduceTransparency ? 0 : (colorScheme == .dark ? 0 : 2)
            )
    }

    private var shadowColor: Color {
        colorScheme == .dark
            ? .clear
            : Color.black.opacity(0.05)
    }
}

/// Shared card chrome for dashboard tiles and analytics blocks.
struct AppCardSurface: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var cornerRadius: CGFloat = 22

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        if colorScheme == .dark {
            shape
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .overlay {
                    shape.strokeBorder(darkEdgeGlass, lineWidth: 1)
                }
        } else if reduceTransparency {
            shape
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .overlay {
                    shape.strokeBorder(Color.black.opacity(0.06), lineWidth: 1)
                }
        } else {
            shape
                .fill(.thickMaterial)
                .overlay {
                    shape
                        .fill(lightSpecularFill)
                        .allowsHitTesting(false)
                }
                .overlay {
                    shape
                        .strokeBorder(lightRimGradient, lineWidth: 1)
                }
        }
    }

    private var darkEdgeGlass: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(0.14),
                Color.white.opacity(0.05),
                Color.white.opacity(0.03)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var lightSpecularFill: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(0.42),
                Color.white.opacity(0.12),
                Color.clear
            ],
            startPoint: .topLeading,
            endPoint: UnitPoint(x: 0.55, y: 0.65)
        )
    }

    private var lightRimGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(0.7),
                Color.white.opacity(0.2),
                Color.black.opacity(0.1)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

/// Matches dashboard card fill inside system grouped lists.
struct AppListRowBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Color(uiColor: .secondarySystemGroupedBackground)
            .overlay(alignment: .top) {
                if colorScheme == .dark {
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.08),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 1)
                    .allowsHitTesting(false)
                }
            }
    }
}

extension View {
    /// Same surface language as dashboard cards for inset grouped lists / forms.
    func appGroupedList() -> some View {
        self
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color(uiColor: .systemGroupedBackground))
            .listRowBackground(AppListRowBackground())
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
                .lineLimit(1)
                .minimumScaleFactor(0.85)
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
