import SwiftUI

struct SkeletonBar: View {
    var width: CGFloat? = nil
    var height: CGFloat = 12
    var corner: CGFloat = 6

    var body: some View {
        RoundedRectangle(cornerRadius: corner, style: .continuous)
            .fill(Color.primary.opacity(0.08))
            .frame(width: width, height: height)
            .frame(maxWidth: width == nil ? .infinity : nil, alignment: .leading)
    }
}

struct SkeletonCircle: View {
    var size: CGFloat = 36

    var body: some View {
        Circle()
            .fill(Color.primary.opacity(0.08))
            .frame(width: size, height: size)
    }
}

struct SkeletonPulseModifier: ViewModifier {
    @State private var dimmed = false

    func body(content: Content) -> some View {
        content
            .opacity(dimmed ? 0.5 : 1)
            .animation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true), value: dimmed)
            .onAppear { dimmed = true }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Загрузка")
    }
}

extension View {
    func skeletonPulse() -> some View {
        modifier(SkeletonPulseModifier())
    }
}

enum FirstLoad {
    @MainActor
    static func finish(_ isLoading: Binding<Bool>, _ work: () -> Void) {
        work()
        isLoading.wrappedValue = false
    }
}

struct SkeletonRow: View {
    var showsTrailing = true

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(0.08))
                .frame(width: 36, height: 36)
            VStack(alignment: .leading, spacing: 6) {
                SkeletonBar(width: 140, height: 12)
                SkeletonBar(width: 88, height: 8)
            }
            Spacer()
            if showsTrailing {
                SkeletonBar(width: 64, height: 14)
            }
        }
        .padding(.vertical, 4)
    }
}

struct SkeletonProgressRow: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.primary.opacity(0.08))
                    .frame(width: 22, height: 22)
                SkeletonBar(width: 120, height: 14)
                Spacer()
                SkeletonBar(width: 72, height: 10)
            }
            SkeletonBar(height: 6, corner: 3)
        }
        .padding(.vertical, 6)
    }
}

struct ListSkeleton: View {
    var rows: Int = 6
    var kind: Kind = .row

    enum Kind {
        case row
        case progress
        case category
    }

    var body: some View {
        List {
            ForEach(0..<rows, id: \.self) { index in
                Group {
                    switch kind {
                    case .row:
                        SkeletonRow()
                    case .progress:
                        SkeletonProgressRow()
                    case .category:
                        if index == 0 {
                            SkeletonBar(width: 72, height: 10)
                        }
                        SkeletonRow(showsTrailing: false)
                    }
                }
                .listRowBackground(Color(uiColor: .secondarySystemGroupedBackground))
            }
        }
        .listStyle(.insetGrouped)
        .scrollDisabled(true)
        .skeletonPulse()
        .allowsHitTesting(false)
    }
}

struct DashboardSkeleton: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SkeletonBar(width: 160, height: 14)
                    .padding(.top, -4)

                DashboardCard {
                    VStack(alignment: .leading, spacing: 10) {
                        SkeletonBar(width: 110, height: 12)
                        SkeletonBar(width: 180, height: 34, corner: 8)
                    }
                }

                donutPlaceholder
                donutPlaceholder

                DashboardCard {
                    VStack(alignment: .leading, spacing: 12) {
                        header
                        SkeletonBar(width: 220, height: 14)
                        HStack(alignment: .bottom, spacing: 8) {
                            ForEach(0..<7, id: \.self) { index in
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(Color.primary.opacity(0.08))
                                    .frame(height: [48, 72, 36, 88, 56, 64, 40][index])
                            }
                        }
                        .frame(height: 96)
                    }
                }

                DashboardCard {
                    VStack(alignment: .leading, spacing: 12) {
                        header
                        ForEach(0..<3, id: \.self) { index in
                            SkeletonRow()
                            if index < 2 {
                                Divider().opacity(0.5)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 108)
        }
        .scrollDisabled(true)
        .background(Color(uiColor: .systemGroupedBackground))
        .skeletonPulse()
        .allowsHitTesting(false)
    }

    private var header: some View {
        HStack(spacing: 8) {
            SkeletonCircle(size: 18)
            SkeletonBar(width: 100, height: 14)
            Spacer()
        }
    }

    private var donutPlaceholder: some View {
        DashboardCard {
            VStack(alignment: .leading, spacing: 16) {
                header
                HStack(spacing: 20) {
                    SkeletonCircle(size: 148)
                    VStack(alignment: .leading, spacing: 12) {
                        legendLine
                        legendLine
                    }
                }
            }
        }
    }

    private var legendLine: some View {
        HStack(spacing: 8) {
            SkeletonCircle(size: 8)
            SkeletonBar(height: 10)
        }
    }
}

struct AnalyticsSkeleton: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.primary.opacity(0.08))
                    .frame(height: 32)

                ForEach(0..<3, id: \.self) { _ in
                    VStack(alignment: .leading, spacing: 12) {
                        SkeletonBar(width: 180, height: 16)
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.primary.opacity(0.08))
                            .frame(height: 180)
                    }
                }
            }
            .padding()
        }
        .scrollDisabled(true)
        .skeletonPulse()
        .allowsHitTesting(false)
    }
}

struct AccountDetailSkeleton: View {
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    SkeletonBar(width: 200, height: 32, corner: 8)
                    SkeletonBar(width: 120, height: 12)
                }
                .padding(.vertical, 4)
            }
            Section {
                ForEach(0..<4, id: \.self) { _ in
                    SkeletonRow()
                }
            }
        }
        .scrollDisabled(true)
        .skeletonPulse()
        .allowsHitTesting(false)
    }
}
