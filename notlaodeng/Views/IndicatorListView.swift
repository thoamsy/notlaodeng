//
//  IndicatorListView.swift
//  notlaodeng
//
//  指标列表视图
//

import SwiftData
import SwiftUI

// MARK: - 过滤选项

enum IndicatorFilter: String, CaseIterable {
    case all = "All"
    case abnormal = "Abnormal"
    case normal = "Normal"

    var icon: String {
        switch self {
        case .all: return "list.bullet"
        case .abnormal: return "exclamationmark.triangle.fill"
        case .normal: return "checkmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .all: return .blue
        case .abnormal: return .orange
        case .normal: return .green
        }
    }
}

// MARK: - 主视图

struct IndicatorListView: View {
    @ObserveInjection var forceRedraw

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \IndicatorTemplate.name) private var templates: [IndicatorTemplate]
    @Query private var profiles: [UserProfile]
    @Query private var allRecords: [HealthRecord]

    @State private var selectedCategories: Set<IndicatorCategory> = []
    @State private var selectedBodyZones: Set<BodyZone> = []
    @State private var selectedFilter: IndicatorFilter = .all
    @State private var searchText = ""
    @State private var showingFilterSheet = false

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

    // 统计数据
    private var abnormalCount: Int {
        templates.filter { template in
            guard let record = template.latestRecord else { return false }
            return record.status(for: currentGender).isAbnormal
        }.count
    }

    private var normalCount: Int {
        templates.filter { template in
            guard let record = template.latestRecord else { return false }
            return record.status(for: currentGender) == .normal
        }.count
    }

    var filteredTemplates: [IndicatorTemplate] {
        // 只显示有数据的模板
        var result = templatesWithData

        // 状态过滤
        switch selectedFilter {
        case .all:
            break
        case .abnormal:
            result = result.filter { template in
                guard let record = template.latestRecord else { return false }
                return record.status(for: currentGender).isAbnormal
            }
        case .normal:
            result = result.filter { template in
                guard let record = template.latestRecord else { return false }
                return record.status(for: currentGender) == .normal
            }
        }

        // 分类过滤（多选）
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
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(IndicatorFilter.allCases, id: \.self) { filter in
                    FilterChip(
                        filter: filter,
                        count: countFor(filter),
                        isSelected: selectedFilter == filter
                    ) {
                        withAnimation(.spring(response: 0.3)) {
                            selectedFilter = filter
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .background(.ultraThinMaterial)
    }

    // MARK: - 当前过滤条件

    @ViewBuilder
    private var activeFiltersBar: some View {
        let bgColor = Color.gray.opacity(0.1)

        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(selectedCategories), id: \.self) { category in
                    GlassFilterTag(
                        icon: category.icon,
                        text: category.rawValue
                    ) {
                        withAnimation(.spring(response: 0.3)) {
                            _ = selectedCategories.remove(category)
                        }
                    }
                }

                ForEach(Array(selectedBodyZones), id: \.self) { zone in
                    GlassFilterTag(
                        icon: zone.icon,
                        text: zone.rawValue
                    ) {
                        withAnimation(.spring(response: 0.3)) {
                            _ = selectedBodyZones.remove(zone)
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
                        Text("Clear All")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(bgColor)
    }

    private func countFor(_ filter: IndicatorFilter) -> Int {
        switch filter {
        case .all: return templates.filter { $0.latestRecord != nil }.count
        case .abnormal: return abnormalCount
        case .normal: return normalCount
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
            if selectedFilter == .abnormal {
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
                                GlassSelectableBadge(
                                    icon: category.icon,
                                    text: category.rawValue,
                                    isSelected: tempCategories.contains(category)
                                ) {
                                    if tempCategories.contains(category) {
                                        _ = tempCategories.remove(category)
                                    } else {
                                        tempCategories.insert(category)
                                    }
                                }
                            }
                        }
                    }

                    // Body Zone Section
                    FilterSection(title: "Body Zone", icon: "figure.stand") {
                        FlowLayout(spacing: 10) {
                            ForEach(BodyZone.allCases, id: \.self) { zone in
                                GlassSelectableBadge(
                                    icon: zone.icon,
                                    text: zone.rawValue,
                                    isSelected: tempBodyZones.contains(zone)
                                ) {
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
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Reset") {
                        selectedCategories.removeAll()
                        selectedBodyZones.removeAll()
                        dismiss()
                    }
                    .foregroundStyle(hasTempSelections ? .red : .secondary)
                    .disabled(!hasTempSelections)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        // 只有点击 Done 才保存更改
                        selectedCategories = tempCategories
                        selectedBodyZones = tempBodyZones
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            // 初始化临时状态
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

// MARK: - Glass Button Style Helper

extension View {
    @ViewBuilder
    func glassButtonStyle(prominent: Bool) -> some View {
        if prominent {
            self.buttonStyle(.glassProminent)
        } else {
            self.buttonStyle(.glass)
        }
    }
}

// MARK: - iOS 26 风格透明 Badge（可选中）

struct GlassSelectableBadge: View {
    let icon: String
    let text: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(text, systemImage: icon) {
            withAnimation {
                action()
            }
        }
        .glassButtonStyle(prominent: isSelected)
    }
}

// MARK: - 当前过滤标签（玻璃风格）

struct GlassFilterTag: View {
    let icon: String
    let text: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))

            Text(text)
                .font(.caption)
                .fontWeight(.medium)

            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .foregroundStyle(.primary)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .strokeBorder(.quaternary, lineWidth: 0.5)
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

// MARK: - 过滤芯片

struct FilterChip: View {
    let filter: IndicatorFilter
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {

                Label(filter.rawValue, systemImage: filter.icon)
                    .font(.subheadline)
                    .fontWeight(.medium)

                if count > 0 {
                    Text("\(count)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(isSelected ? .white.opacity(0.3) : filter.color.opacity(0.2))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .foregroundStyle(isSelected ? .white : filter.color)
        .background(isSelected ? filter.color : filter.color.opacity(0.2))
        .clipShape(Capsule())
        // .buttonBorderShape(.capsule)
        // .glassEffect(.regular.interactive(), in: .capsule)
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
