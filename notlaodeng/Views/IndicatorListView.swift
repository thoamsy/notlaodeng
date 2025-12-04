//
//  IndicatorListView.swift
//  notlaodeng
//
//  指标列表视图
//

import SwiftData
import SwiftUI

// MARK: - 主视图

struct IndicatorListView: View {
    @ObserveInjection var forceRedraw

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \IndicatorTemplate.name) private var templates: [IndicatorTemplate]
    @Query private var profiles: [UserProfile]
    @Query private var allRecords: [HealthRecord]

    @Namespace private var filterNamespace

    @State private var selectedCategories: Set<IndicatorCategory> = []
    @State private var selectedBodyZones: Set<BodyZone> = []
    @State private var searchText = ""
    @State private var showingFilterSheet = false
    @State private var selectedQuickFilters: Set<QuickFilterType> = []

    private var currentGender: Gender {
        profiles.first?.gender ?? .male
    }

    /// 是否有任何健康记录数据
    private var hasAnyData: Bool {
        !allRecords.isEmpty
    }

    /// 只显示有数据的模板
    private var templatesWithData: [IndicatorTemplate] {
        templates.filter { $0.latestRecord != nil }
    }

    // 统计数据（基于有数据的模板）
    private var abnormalCount: Int {
        templatesWithData.filter { template in
            template.latestRecord?.status(for: currentGender).isAbnormal == true
        }.count
    }

    private var normalCount: Int {
        templatesWithData.filter { template in
            template.latestRecord?.status(for: currentGender) == .normal
        }.count
    }

    private var favoritesCount: Int {
        templatesWithData.filter { $0.isFavorite }.count
    }

    /// 过滤器数量字典（传给 QuickFilterBar）
    private var filterCounts: [QuickFilterType: Int] {
        [
            .favorites: favoritesCount,
            .abnormal: abnormalCount,
            .normal: normalCount,
        ]
    }

    /// 判断模板是否匹配某个过滤器
    private func matches(_ template: IndicatorTemplate, filter: QuickFilterType) -> Bool {
        switch filter {
        case .favorites:
            return template.isFavorite
        case .abnormal:
            return template.latestRecord?.status(for: currentGender).isAbnormal == true
        case .normal:
            return template.latestRecord?.status(for: currentGender) == .normal
        }
    }

    var filteredTemplates: [IndicatorTemplate] {
        var result = templatesWithData

        // 快速过滤（OR 逻辑：匹配任一选中的过滤器即可）
        if !selectedQuickFilters.isEmpty {
            result = result.filter { template in
                selectedQuickFilters.contains { filter in
                    matches(template, filter: filter)
                }
            }
        }

        // 分类过滤（多选，AND with quick filters）
        if !selectedCategories.isEmpty {
            result = result.filter { selectedCategories.contains($0.category) }
        }

        // 身体部位过滤（多选）
        if !selectedBodyZones.isEmpty {
            result = result.filter { selectedBodyZones.contains($0.bodyZone) }
        }

        // 搜索过滤
        if !searchText.isEmpty {
            result = result.filter {
                $0.name.localizedCaseInsensitiveContains(searchText)
                    || ($0.abbreviation?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }

        return result
    }

    var groupedTemplates: [IndicatorCategory: [IndicatorTemplate]] {
        Dictionary(grouping: filteredTemplates, by: { $0.category })
    }

    private var hasActiveFilter: Bool {
        !selectedCategories.isEmpty || !selectedBodyZones.isEmpty
    }

    private var activeFilterCount: Int {
        selectedCategories.count + selectedBodyZones.count
    }

    var body: some View {
        NavigationStack {
            Group {
                if !hasAnyData {
                    // 没有数据时显示空状态
                    emptyStateView
                } else {
                    // 有数据时显示完整 UI
                    VStack(spacing: 0) {
                        // 快速过滤栏
                        filterBar

                        // 当前过滤条件显示
                        if hasActiveFilter {
                            activeFiltersBar
                        }

                        // 内容
                        if filteredTemplates.isEmpty {
                            noResultsView
                        } else {
                            indicatorList
                        }
                    }
                    .searchable(text: $searchText, prompt: "Search indicators")
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                showingFilterSheet = true
                            } label: {
                                ZStack(alignment: .topTrailing) {
                                    Image(systemName: "slider.horizontal.3")
                                        .font(.body)

                                    if activeFilterCount > 0 {
                                        Text("\(activeFilterCount)")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundStyle(.white)
                                            .frame(width: 16, height: 16)
                                            .background(.blue)
                                            .clipShape(Circle())
                                            .offset(x: 8, y: -8)
                                    }
                                }
                            }
                        }
                    }
                    .sheet(isPresented: $showingFilterSheet) {
                        FilterSheetView(
                            selectedCategories: $selectedCategories,
                            selectedBodyZones: $selectedBodyZones
                        )
                        .presentationDetents([.medium, .large])
                        .presentationDragIndicator(.visible)
                    }
                }
            }
            .navigationTitle("Health Indicators")
        }
        .id(forceRedraw)
        .eraseToAnyView()
    }

    // MARK: - 快速过滤栏

    private var filterBar: some View {
        QuickFilterBar(
            selectedFilters: $selectedQuickFilters,
            filterCounts: filterCounts,
            namespace: filterNamespace
        )
    }

    // MARK: - 当前过滤条件（融合效果）

    @Namespace private var activeFilterNamespace

    /// 所有活跃的 filter items（用于计算融合）
    private var activeFilterItems: [(id: String, icon: String, text: String, isCategory: Bool)] {
        var items: [(id: String, icon: String, text: String, isCategory: Bool)] = []
        for category in selectedCategories.sorted(by: { $0.rawValue < $1.rawValue }) {
            items.append(
                (
                    id: "cat-\(category.rawValue)", icon: category.icon, text: category.rawValue,
                    isCategory: true
                ))
        }
        for zone in selectedBodyZones.sorted(by: { $0.rawValue < $1.rawValue }) {
            items.append(
                (
                    id: "zone-\(zone.rawValue)", icon: zone.icon, text: zone.rawValue,
                    isCategory: false
                ))
        }
        return items
    }

    /// 判断是否应该融合（有多个 filter 时融合）
    private func shouldUnionActiveFilter(at index: Int) -> Bool {
        let items = activeFilterItems
        guard items.count > 1 else { return false }

        // 检查左右是否有相邻 item
        let hasLeft = index > 0
        let hasRight = index < items.count - 1

        return hasLeft || hasRight
    }

    @ViewBuilder
    private var activeFiltersBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            GlassEffectContainer {
                HStack(spacing: 8) {
                    ForEach(Array(activeFilterItems.enumerated()), id: \.element.id) {
                        index, item in
                        ActiveFilterTag(
                            icon: item.icon,
                            shouldUnion: shouldUnionActiveFilter(at: index),
                            namespace: activeFilterNamespace
                        ) {
                            withAnimation(.spring(response: 0.3)) {
                                if item.isCategory {
                                    if let category = IndicatorCategory.allCases.first(where: {
                                        $0.rawValue == item.text
                                    }) {
                                        _ = selectedCategories.remove(category)
                                    }
                                } else {
                                    if let zone = BodyZone.allCases.first(where: {
                                        $0.rawValue == item.text
                                    }) {
                                        _ = selectedBodyZones.remove(zone)
                                    }
                                }
                            }
                        }
                    }

                    if hasActiveFilter {
                        Button {
                            withAnimation(.spring(response: 0.3)) {
                                selectedCategories.removeAll()
                                selectedBodyZones.removeAll()
                            }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.body)
                        }
                        .buttonStyle(.glass)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
        }
    }

    // MARK: - 空状态

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("No Health Data", systemImage: "heart.text.clipboard")
        } description: {
            VStack(spacing: 8) {
                Text("Import your health checkup reports to start tracking your indicators.")
                Text("Go to **Reports** tab to scan or import PDF.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var noResultsView: some View {
        ContentUnavailableView {
            Label("No Results", systemImage: "magnifyingglass")
        } description: {
            // 只选了 Abnormal 且没有结果时，说明没有异常指标
            let onlyAbnormal =
                selectedQuickFilters == [.abnormal]
                || (selectedQuickFilters.contains(.abnormal) && selectedQuickFilters.count == 1)
            if onlyAbnormal {
                Text("Great! No abnormal indicators found.")
            } else {
                Text("Try adjusting your search or filter.")
            }
        }
    }

    // MARK: - 指标列表

    private var indicatorList: some View {
        List {
            ForEach(IndicatorCategory.allCases.filter { groupedTemplates[$0] != nil }, id: \.self) {
                category in
                Section {
                    ForEach(groupedTemplates[category] ?? []) { template in
                        IndicatorRow(template: template, gender: currentGender)
                            .swipeActions(edge: .trailing) {
                                Button {
                                    withAnimation {
                                        template.isFavorite.toggle()
                                    }
                                } label: {
                                    Label(
                                        template.isFavorite ? "Unfavorite" : "Favorite",
                                        systemImage: template.isFavorite ? "star.slash" : "star"
                                    )
                                }
                                .tint(.yellow)
                            }
                    }
                } header: {
                    CategorySectionHeader(category: category)
                }
            }
        }
    }
}

// MARK: - 过滤器 Sheet

struct FilterSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedCategories: Set<IndicatorCategory>
    @Binding var selectedBodyZones: Set<BodyZone>

    // 临时状态，不会立即影响列表
    @State private var tempCategories: Set<IndicatorCategory> = []
    @State private var tempBodyZones: Set<BodyZone> = []

    private var hasChanges: Bool {
        tempCategories != selectedCategories || tempBodyZones != selectedBodyZones
    }

    private var hasTempSelections: Bool {
        !tempCategories.isEmpty || !tempBodyZones.isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    // Category Section
                    FilterSection(title: "Category", icon: "folder") {
                        FlowLayout(spacing: 10) {
                            ForEach(IndicatorCategory.allCases, id: \.self) { category in
                                FilterSelectableBadge(
                                    icon: category.icon,
                                    text: category.rawValue,
                                    isSelected: tempCategories.contains(category),
                                    tintColor: .blue
                                ) {
                                    withAnimation(.spring(response: 0.3)) {
                                        if tempCategories.contains(category) {
                                            _ = tempCategories.remove(category)
                                        } else {
                                            tempCategories.insert(category)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Body Zone Section
                    FilterSection(title: "Body Zone", icon: "figure.stand") {
                        FlowLayout(spacing: 10) {
                            ForEach(BodyZone.allCases, id: \.self) { zone in
                                FilterSelectableBadge(
                                    icon: zone.icon,
                                    text: zone.rawValue,
                                    isSelected: tempBodyZones.contains(zone),
                                    tintColor: .purple
                                ) {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        if tempBodyZones.contains(zone) {
                                            _ = tempBodyZones.remove(zone)
                                        } else {
                                            tempBodyZones.insert(zone)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Reset") {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            tempCategories.removeAll()
                            tempBodyZones.removeAll()
                        }
                    }
                    .foregroundStyle(hasTempSelections ? .red : .secondary)
                    .disabled(!hasTempSelections)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        selectedCategories = tempCategories
                        selectedBodyZones = tempBodyZones
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            tempCategories = selectedCategories
            tempBodyZones = selectedBodyZones
        }
    }
}

// MARK: - Filter Section

struct FilterSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(title)
                    .font(.headline)
            }

            content()
        }
    }
}

// MARK: - Filter Selectable Badge (Sheet 内使用，无融合)

struct FilterSelectableBadge: View {
    let icon: String
    let text: String
    let isSelected: Bool
    let tintColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(text, systemImage: icon)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(isSelected ? .white : .primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .glassEffect(
            .regular.tint(isSelected ? tintColor : .clear).interactive(),
            in: .capsule
        )
    }
}

// MARK: - Flow Layout (flex-wrap)

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(
        in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
    ) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(
                at: CGPoint(
                    x: bounds.minX + result.positions[index].x,
                    y: bounds.minY + result.positions[index].y),
                proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }

                positions.append(CGPoint(x: x, y: y))
                lineHeight = max(lineHeight, size.height)
                x += size.width + spacing

                self.size.width = max(self.size.width, x - spacing)
            }

            self.size.height = y + lineHeight
        }
    }
}

// MARK: - Active Filter Tag（支持融合的当前过滤标签）

struct ActiveFilterTag: View {
    let icon: String
    let shouldUnion: Bool
    var namespace: Namespace.ID
    let onRemove: () -> Void

    var body: some View {
        Button(action: onRemove) {
            Image(systemName: icon)
                .font(.body)

        }
        .buttonStyle(.glassProminent)
        .modifier(
            ConditionalGlassUnion(
                shouldUnion: shouldUnion,
                unionID: "activeFilter",
                namespace: namespace
            )
        )
    }
}

// MARK: - Section Header

struct CategorySectionHeader: View {
    let category: IndicatorCategory

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: category.icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)

            Text(category.rawValue)
                .font(.subheadline)
                .fontWeight(.semibold)
        }
    }
}

// MARK: - 指标行

struct IndicatorRow: View {
    let template: IndicatorTemplate
    let gender: Gender

    private var latestRecord: HealthRecord? {
        template.latestRecord
    }

    private var status: HealthStatus {
        latestRecord?.status(for: gender) ?? .unknown
    }

    var latestValue: String {
        guard let record = latestRecord else {
            return "--"
        }
        return "\(record.formattedValue) \(template.unit)"
    }

    var body: some View {
        NavigationLink {
            IndicatorDetailView(template: template)
        } label: {
            HStack(spacing: 12) {
                // 身体部位图标 + 状态
                ZStack(alignment: .bottomTrailing) {
                    Image(systemName: template.bodyZone.icon)
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary)
                        .frame(width: 36, height: 36)
                        .background(Color(.systemGray5))
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    // 状态小圆点
                    if status != .unknown {
                        Circle()
                            .fill(status.color)
                            .frame(width: 10, height: 10)
                            .overlay(
                                Circle()
                                    .stroke(.white, lineWidth: 2)
                            )
                            .offset(x: 3, y: 3)
                    }
                }

                // 指标信息
                VStack(alignment: .leading, spacing: 4) {
                    Text(template.name)
                        .font(.headline)

                    if let abbr = template.abbreviation {
                        Text(abbr)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // 数值 + 状态标签
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(latestValue)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(status.isAbnormal ? status.color : .primary)

                        if status.isAbnormal {
                            Image(systemName: status.icon)
                                .font(.caption)
                                .foregroundStyle(status.color)
                        }
                    }

                    Text(template.referenceRangeText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
    }
}

// MARK: - 状态徽章（保留备用）

struct StatusBadge: View {
    let status: HealthStatus

    var body: some View {
        Image(systemName: status.icon)
            .font(.system(size: 20))
            .foregroundStyle(status.color)
            .frame(width: 32, height: 32)
            .background(status.backgroundColor)
            .clipShape(Circle())
    }
}

// MARK: - Preview

#Preview {
    IndicatorListView()
        .modelContainer(
            for: [IndicatorTemplate.self, HealthRecord.self, UserProfile.self], inMemory: true)
}
