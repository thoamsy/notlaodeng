//
//  IndicatorListView.swift
//  notlaodeng
//
//  指标列表视图
//

import SwiftUI
import SwiftData

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

    @State private var selectedCategory: IndicatorCategory?
    @State private var selectedBodyZone: BodyZone?
    @State private var selectedFilter: IndicatorFilter = .all
    @State private var searchText = ""

    private var currentGender: Gender {
        profiles.first?.gender ?? .male
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
        var result = templates

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

        // 分类过滤
        if let category = selectedCategory {
            result = result.filter { $0.category == category }
        }

        // 身体部位过滤
        if let bodyZone = selectedBodyZone {
            result = result.filter { $0.bodyZone == bodyZone }
        }

        // 搜索过滤
        if !searchText.isEmpty {
            result = result.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                ($0.abbreviation?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }

        return result
    }

    var groupedTemplates: [IndicatorCategory: [IndicatorTemplate]] {
        Dictionary(grouping: filteredTemplates, by: { $0.category })
    }

    private var hasActiveFilter: Bool {
        selectedCategory != nil || selectedBodyZone != nil
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 快速过滤栏
                filterBar

                // 当前过滤条件显示
                if hasActiveFilter {
                    activeFiltersBar
                }

                // 内容
                Group {
                    if templates.isEmpty {
                        emptyStateView
                    } else if filteredTemplates.isEmpty {
                        noResultsView
                    } else {
                        indicatorList
                    }
                }
            }
            .navigationTitle("Health Indicators")
            .searchable(text: $searchText, prompt: "Search indicators")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    filterMenu
                }
            }
        }
        .id(forceRedraw)
        .eraseToAnyView()
    }

    // MARK: - 过滤菜单

    private var filterMenu: some View {
        Menu {
            // 分类过滤
            Section("Category") {
                Button {
                    selectedCategory = nil
                } label: {
                    Label("All Categories", systemImage: selectedCategory == nil ? "checkmark" : "")
                }

                ForEach(IndicatorCategory.allCases, id: \.self) { category in
                    Button {
                        selectedCategory = category
                    } label: {
                        Label {
                            Text(category.rawValue)
                        } icon: {
                            Image(systemName: selectedCategory == category ? "checkmark" : category.icon)
                        }
                    }
                }
            }

            Divider()

            // 身体部位过滤
            Section("Body Zone") {
                Button {
                    selectedBodyZone = nil
                } label: {
                    Label("All Zones", systemImage: selectedBodyZone == nil ? "checkmark" : "")
                }

                ForEach(BodyZone.allCases, id: \.self) { zone in
                    Button {
                        selectedBodyZone = zone
                    } label: {
                        Label {
                            Text(zone.rawValue)
                        } icon: {
                            Image(systemName: selectedBodyZone == zone ? "checkmark" : zone.icon)
                        }
                    }
                }
            }

            if hasActiveFilter {
                Divider()
                Button(role: .destructive) {
                    selectedCategory = nil
                    selectedBodyZone = nil
                } label: {
                    Label("Clear All Filters", systemImage: "xmark.circle")
                }
            }
        } label: {
            Label("Filter", systemImage: hasActiveFilter ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
        }
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

    private var activeFiltersBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if let category = selectedCategory {
                    ActiveFilterTag(
                        icon: category.icon,
                        text: category.rawValue,
                        color: .purple
                    ) {
                        withAnimation { selectedCategory = nil }
                    }
                }

                if let zone = selectedBodyZone {
                    ActiveFilterTag(
                        icon: zone.icon,
                        text: zone.rawValue,
                        color: .teal
                    ) {
                        withAnimation { selectedBodyZone = nil }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color(.systemGray6))
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
            Label("No Indicators", systemImage: "list.bullet.clipboard")
        } description: {
            Text("Add health indicators to start tracking your health data.")
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
            ForEach(IndicatorCategory.allCases.filter { groupedTemplates[$0] != nil }, id: \.self) { category in
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

// MARK: - 当前过滤标签

struct ActiveFilterTag: View {
    let icon: String
    let text: String
    let color: Color
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)

            Text(text)
                .font(.caption)

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .foregroundStyle(color)
        .background(color.opacity(0.15))
        .clipShape(Capsule())
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
                Image(systemName: filter.icon)
                    .font(.system(size: 14, weight: .medium))

                Text(filter.rawValue)
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
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .foregroundStyle(isSelected ? .white : filter.color)
            .background(isSelected ? filter.color : filter.color.opacity(0.1))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
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
        .modelContainer(for: [IndicatorTemplate.self, HealthRecord.self, UserProfile.self], inMemory: true)
}
