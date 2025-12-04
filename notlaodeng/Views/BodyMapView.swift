//
//  BodyMapView.swift
//  notlaodeng
//
//  人体地图视图 - 分层交互式查看各部位健康状态
//

import SwiftData
import SwiftUI

// MARK: - 大区域定义

enum BodyRegion: String, CaseIterable, Identifiable {
    case headNeck = "Head & Neck"
    case chest = "Chest"
    case abdomen = "Abdomen"
    case systemic = "Systemic"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .headNeck: return "brain.head.profile"
        case .chest: return "heart.fill"
        case .abdomen: return "leaf.fill"
        case .systemic: return "drop.fill"
        }
    }

    var zones: [BodyZone] {
        switch self {
        case .headNeck:
            return [.head, .eye, .ear, .oral, .thyroid, .nervous]
        case .chest:
            return [.chest, .heart, .lung]
        case .abdomen:
            return [.liver, .digestive, .kidney, .urinary, .reproductive]
        case .systemic:
            return [.blood, .bone, .skin, .fullBody]
        }
    }

    // 在人体图上的位置 (y: 0-1)
    var verticalPosition: CGFloat {
        switch self {
        case .headNeck: return 0.12
        case .chest: return 0.32
        case .abdomen: return 0.52
        case .systemic: return 0.75
        }
    }
}

// MARK: - 主视图

struct BodyMapView: View {
    @ObserveInjection var forceRedraw

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \IndicatorTemplate.name) private var templates: [IndicatorTemplate]
    @Query private var profiles: [UserProfile]

    @State private var selectedRegion: BodyRegion?
    @State private var selectedZone: BodyZone?
    @Namespace private var animation

    private var currentGender: Gender {
        profiles.first?.gender ?? .male
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let bodyHeight = geometry.size.height * 0.7
                let bodyWidth = bodyHeight * 0.45

                ScrollView {
                    VStack(spacing: 24) {
                        // 健康状态概览
                        healthSummaryCard

                        // Body Map 主体
                        ZStack {
                            if selectedRegion == nil {
                                // 第一层：大区域概览
                                regionOverviewView(bodyWidth: bodyWidth, bodyHeight: bodyHeight)
                                    .transition(.opacity)
                            } else {
                                // 第二层：区域详情
                                regionDetailView(bodyWidth: bodyWidth, bodyHeight: bodyHeight)
                                    .transition(.opacity)
                            }
                        }
                        .frame(width: bodyWidth, height: bodyHeight)
                        .frame(maxWidth: .infinity)
                        .animation(
                            .spring(response: 0.4, dampingFraction: 0.8), value: selectedRegion)

                        // 图例
                        legendView

                        Spacer(minLength: 20)
                    }
                    .padding()
                }
            }
            .navigationTitle("Body Map")
            .toolbar {
                if selectedRegion != nil {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            withAnimation(.spring(response: 0.3)) {
                                selectedRegion = nil
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                Text("Overview")
                            }
                        }
                    }
                }
            }
            .sheet(item: $selectedZone) { zone in
                ZoneDetailSheet(
                    zone: zone,
                    templates: templates.filter { $0.bodyZone == zone },
                    gender: currentGender
                )
            }
        }
        .id(forceRedraw)
        .eraseToAnyView()
    }

    // MARK: - Region Overview (第一层)

    private func regionOverviewView(bodyWidth: CGFloat, bodyHeight: CGFloat) -> some View {
        ZStack {
            // 人体轮廓
            BodySilhouette()
                .fill(Color(.systemGray5))

            // 大区域热点
            ForEach(BodyRegion.allCases) { region in
                RegionButton(
                    region: region,
                    status: regionStatus(for: region),
                    indicatorCount: indicatorCount(for: region),
                    bodyWidth: bodyWidth,
                    bodyHeight: bodyHeight
                ) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        selectedRegion = region
                    }
                }
            }
        }
    }

    // MARK: - Region Detail (第二层)

    private func regionDetailView(bodyWidth: CGFloat, bodyHeight: CGFloat) -> some View {
        VStack(spacing: 0) {
            if let region = selectedRegion {
                // 区域标题
                HStack {
                    Image(systemName: region.icon)
                        .font(.title2)
                        .foregroundStyle(regionStatus(for: region).color)
                    Text(region.rawValue)
                        .font(.title2)
                        .fontWeight(.semibold)
                }
                .padding(.bottom, 16)

                // 该区域的子部位网格
                let zones = region.zones
                let columns = zones.count <= 4 ? 2 : 3

                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: columns),
                    spacing: 16
                ) {
                    ForEach(zones, id: \.self) { zone in
                        ZoneCard(
                            zone: zone,
                            status: zoneStatus(for: zone),
                            indicatorCount: templates.filter { $0.bodyZone == zone }.count
                        ) {
                            selectedZone = zone
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Health Summary Card

    private var healthSummaryCard: some View {
        let abnormalCount = BodyZone.allCases.filter { zoneStatus(for: $0) == .abnormal }.count
        let normalCount = BodyZone.allCases.filter { zoneStatus(for: $0) == .normal }.count
        let noDataCount = BodyZone.allCases.filter { zoneStatus(for: $0) == .noData }.count

        return HStack(spacing: 16) {
            SummaryItem(
                count: abnormalCount, label: "Abnormal", color: .orange,
                icon: "exclamationmark.triangle.fill")
            SummaryItem(
                count: normalCount, label: "Normal", color: .green, icon: "checkmark.circle.fill")
            SummaryItem(count: noDataCount, label: "No Data", color: .gray, icon: "minus.circle")
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }

    private var legendView: some View {
        HStack(spacing: 20) {
            LegendItem(color: .orange, label: "Abnormal")
            LegendItem(color: .green, label: "Normal")
            LegendItem(color: .gray.opacity(0.5), label: "No Data")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    // MARK: - Status Helpers

    private func zoneStatus(for zone: BodyZone) -> ZoneHealthStatus {
        let zoneTemplates = templates.filter { $0.bodyZone == zone }
        guard !zoneTemplates.isEmpty else { return .noData }

        let hasAbnormal = zoneTemplates.contains { template in
            guard let record = template.latestRecord else { return false }
            return record.status(for: currentGender).isAbnormal
        }

        let hasData = zoneTemplates.contains { $0.latestRecord != nil }

        if hasAbnormal { return .abnormal }
        if hasData { return .normal }
        return .noData
    }

    private func regionStatus(for region: BodyRegion) -> ZoneHealthStatus {
        let statuses = region.zones.map { zoneStatus(for: $0) }
        if statuses.contains(.abnormal) { return .abnormal }
        if statuses.contains(.normal) { return .normal }
        return .noData
    }

    private func indicatorCount(for region: BodyRegion) -> Int {
        region.zones.reduce(0) { count, zone in
            count + templates.filter { $0.bodyZone == zone }.count
        }
    }
}

// MARK: - Zone Health Status

enum ZoneHealthStatus {
    case normal, abnormal, noData

    var color: Color {
        switch self {
        case .normal: return .green
        case .abnormal: return .orange
        case .noData: return .gray.opacity(0.4)
        }
    }
}

// MARK: - Body Silhouette

struct BodySilhouette: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        // 头部
        let headRadius = w * 0.18
        path.addEllipse(
            in: CGRect(
                x: w * 0.5 - headRadius,
                y: h * 0.02,
                width: headRadius * 2,
                height: headRadius * 2
            ))

        // 颈部
        path.addRect(CGRect(x: w * 0.42, y: h * 0.14, width: w * 0.16, height: h * 0.04))

        // 躯干
        path.move(to: CGPoint(x: w * 0.28, y: h * 0.18))
        path.addLine(to: CGPoint(x: w * 0.12, y: h * 0.22))
        path.addLine(to: CGPoint(x: w * 0.08, y: h * 0.48))
        path.addLine(to: CGPoint(x: w * 0.16, y: h * 0.48))
        path.addLine(to: CGPoint(x: w * 0.24, y: h * 0.26))
        path.addLine(to: CGPoint(x: w * 0.28, y: h * 0.62))
        path.addLine(to: CGPoint(x: w * 0.32, y: h * 0.98))
        path.addLine(to: CGPoint(x: w * 0.44, y: h * 0.98))
        path.addLine(to: CGPoint(x: w * 0.44, y: h * 0.64))
        path.addLine(to: CGPoint(x: w * 0.56, y: h * 0.64))
        path.addLine(to: CGPoint(x: w * 0.56, y: h * 0.98))
        path.addLine(to: CGPoint(x: w * 0.68, y: h * 0.98))
        path.addLine(to: CGPoint(x: w * 0.72, y: h * 0.62))
        path.addLine(to: CGPoint(x: w * 0.76, y: h * 0.26))
        path.addLine(to: CGPoint(x: w * 0.84, y: h * 0.48))
        path.addLine(to: CGPoint(x: w * 0.92, y: h * 0.48))
        path.addLine(to: CGPoint(x: w * 0.88, y: h * 0.22))
        path.addLine(to: CGPoint(x: w * 0.72, y: h * 0.18))
        path.closeSubpath()

        return path
    }
}

// MARK: - Region Button (第一层)

struct RegionButton: View {
    let region: BodyRegion
    let status: ZoneHealthStatus
    let indicatorCount: Int
    let bodyWidth: CGFloat
    let bodyHeight: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(status.color)
                        .frame(width: 56, height: 56)
                        .shadow(color: status.color.opacity(0.4), radius: 6)

                    Image(systemName: region.icon)
                        .font(.title2)
                        .foregroundStyle(.white)
                }

                Text(region.rawValue)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)

                if indicatorCount > 0 {
                    Text("\(indicatorCount)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
        .position(
            x: bodyWidth * 0.5,
            y: bodyHeight * region.verticalPosition
        )
    }
}

// MARK: - Zone Card (第二层)

struct ZoneCard: View {
    let zone: BodyZone
    let status: ZoneHealthStatus
    let indicatorCount: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(status.color)
                        .frame(width: 48, height: 48)

                    Image(systemName: zone.icon)
                        .font(.title3)
                        .foregroundStyle(.white)
                }

                Text(zone.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                if indicatorCount > 0 {
                    Text("\(indicatorCount) indicators")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(
                color: status == .abnormal ? status.color.opacity(0.3) : .black.opacity(0.05),
                radius: 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Summary Item

struct SummaryItem: View {
    let count: Int
    let label: String
    let color: Color
    let icon: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            Text("\(count)")
                .font(.title2)
                .fontWeight(.bold)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Legend Item

struct LegendItem: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text(label)
        }
    }
}

// MARK: - Zone Detail Sheet

struct ZoneDetailSheet: View {
    @Environment(\.dismiss) private var dismiss

    let zone: BodyZone
    let templates: [IndicatorTemplate]
    let gender: Gender

    var body: some View {
        NavigationStack {
            List {
                if templates.isEmpty {
                    ContentUnavailableView {
                        Label("No Indicators", systemImage: "doc.text")
                    } description: {
                        Text("No health indicators found for \(zone.rawValue).")
                    }
                } else {
                    Section {
                        ForEach(templates) { template in
                            ZoneIndicatorRow(template: template, gender: gender)
                        }
                    } header: {
                        Text("\(templates.count) indicator(s)")
                    }
                }
            }
            .navigationTitle(zone.rawValue)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Zone Indicator Row

struct ZoneIndicatorRow: View {
    let template: IndicatorTemplate
    let gender: Gender

    private var latestRecord: HealthRecord? { template.latestRecord }
    private var status: HealthStatus { latestRecord?.status(for: gender) ?? .unknown }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(template.name)
                        .font(.headline)
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

            Spacer()

            if let record = latestRecord {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(record.formattedValue)
                        .font(.headline)
                        .foregroundStyle(status.isAbnormal ? status.color : .primary)
                    Text(template.unit)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("No data")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

// MARK: - Extensions

extension BodyZone: Identifiable {
    var id: String { rawValue }
}

#Preview {
    BodyMapView()
        .modelContainer(
            for: [IndicatorTemplate.self, HealthRecord.self, UserProfile.self],
            inMemory: true
        )
}
