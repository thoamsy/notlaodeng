//
//  QuickFilterBar.swift
//  notlaodeng
//
//  快速过滤栏组件
//

import SwiftUI

// MARK: - Quick Filter Type Definition

enum QuickFilterType: String, CaseIterable, Identifiable {
    case favorites
    case abnormal
    case normal

    var id: String { rawValue }

    var title: String {
        switch self {
        case .favorites: return "Favorites"
        case .abnormal: return "Abnormal"
        case .normal: return "Normal"
        }
    }

    var icon: String {
        switch self {
        case .favorites: return "star.fill"
        case .abnormal: return "exclamationmark.triangle.fill"
        case .normal: return "checkmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .favorites: return .yellow
        case .abnormal: return .orange
        case .normal: return .green
        }
    }
}

// MARK: - Quick Filter Bar

struct QuickFilterBar: View {
    @Binding var selectedFilters: Set<QuickFilterType>
    let filterCounts: [QuickFilterType: Int]
    let namespace: Namespace.ID

    /// 可见的过滤器（Favorites 只在有收藏时显示）
    private var visibleFilters: [QuickFilterType] {
        QuickFilterType.allCases.filter { filter in
            if filter == .favorites {
                return (filterCounts[filter] ?? 0) > 0
            }
            return true
        }
    }

    /// 判断某个位置的过滤器是否应该与相邻的选中过滤器融合
    private func shouldUnion(at index: Int) -> Bool {
        let filters = visibleFilters
        let isSelected = selectedFilters.contains(filters[index])

        guard isSelected else { return false }

        let hasSelectedLeft = index > 0 && selectedFilters.contains(filters[index - 1])
        let hasSelectedRight =
            index < filters.count - 1 && selectedFilters.contains(filters[index + 1])

        return hasSelectedLeft || hasSelectedRight
    }

    /// 获取融合组的统一颜色（混合相邻选中按钮的颜色）
    private func unionColor(at index: Int) -> Color {
        let filters = visibleFilters
        guard shouldUnion(at: index) else {
            return filters[index].color
        }

        // 收集当前连续选中组的所有颜色
        var colors: [Color] = []
        var leftIdx = index
        var rightIdx = index

        // 向左扩展找到连续选中的起点
        while leftIdx > 0 && selectedFilters.contains(filters[leftIdx - 1]) {
            leftIdx -= 1
        }
        // 向右扩展找到连续选中的终点
        while rightIdx < filters.count - 1 && selectedFilters.contains(filters[rightIdx + 1]) {
            rightIdx += 1
        }

        // 收集这个连续组内所有选中按钮的颜色
        for i in leftIdx...rightIdx where selectedFilters.contains(filters[i]) {
            colors.append(filters[i].color)
        }

        return blendColors(colors)
    }

    /// 混合多个颜色（使用 iOS 18+ 的 Color.mix API）
    private func blendColors(_ colors: [Color]) -> Color {
        guard !colors.isEmpty else { return .blue }
        guard colors.count > 1 else { return colors[0] }

        // 使用 Color.mix 逐步混合所有颜色
        var result = colors[0]
        for i in 1..<colors.count {
            // 每次混合时，按比例混合（保持平衡）
            let ratio = 1.0 / Double(i + 1)
            result = result.mix(with: colors[i], by: ratio, in: .perceptual)
        }
        return result
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            GlassEffectContainer {
                HStack(spacing: 8) {
                    ForEach(Array(visibleFilters.enumerated()), id: \.element.id) { index, filter in
                        let isUnioned = shouldUnion(at: index)
                        QuickFilterChip(
                            filter: filter,
                            count: filterCounts[filter] ?? 0,
                            isSelected: selectedFilters.contains(filter),
                            isUnioned: isUnioned,
                            tintColor: isUnioned ? unionColor(at: index) : filter.color,
                            namespace: namespace
                        ) {
                            withAnimation(
                                .spring(response: 0.3, dampingFraction: 0.8, blendDuration: 0.2)
                            ) {
                                if selectedFilters.contains(filter) {
                                    selectedFilters.remove(filter)
                                } else {
                                    selectedFilters.insert(filter)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
            }
        }
    }
}

// MARK: - Quick Filter Chip

struct QuickFilterChip: View {
    let filter: QuickFilterType
    let count: Int
    let isSelected: Bool
    let isUnioned: Bool
    let tintColor: Color
    var namespace: Namespace.ID
    let action: () -> Void

    /// 选中时的前景色（根据 tint 颜色自动选择对比色）
    private var foregroundColor: Color {
        isSelected ? .white : .primary
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                // 融合时只显示图标，未融合时显示完整 Label
                if isUnioned {
                    Image(systemName: filter.icon)
                        .font(.subheadline)
                        .fontWeight(.medium)
                } else {
                    Label(filter.title, systemImage: filter.icon)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }

                if count > 0 {
                    Text("\(count)")
                        .font(.caption)
                        .fontWeight(.bold)
                }
            }
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, isUnioned ? 10 : 12)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .glassEffect(
            .regular.tint(isSelected ? tintColor : .clear).interactive(),
            in: .capsule
        )
        .modifier(
            ConditionalGlassUnion(
                shouldUnion: isUnioned,
                unionID: "quickFilter",
                namespace: namespace
            )
        )
    }
}

// MARK: - Conditional Glass Union Modifier

struct ConditionalGlassUnion: ViewModifier {
    let shouldUnion: Bool
    let unionID: String
    let namespace: Namespace.ID

    func body(content: Content) -> some View {
        if shouldUnion {
            content.glassEffectUnion(id: unionID, namespace: namespace)
        } else {
            content
        }
    }
}
