//
//  IndicatorDetailView.swift
//  notlaodeng
//
//  指标详情视图
//

import Charts
import SwiftData
import SwiftUI

struct IndicatorDetailView: View {
    @ObserveInjection var forceRedraw

    @Environment(\.modelContext) private var modelContext

    let template: IndicatorTemplate

    @State private var showingAddRecord = false

    var sortedRecords: [HealthRecord] {
        template.records.sorted { $0.testDate < $1.testDate }
    }

    var body: some View {
        List {
            // 概览
            Section {
                overviewCard
            }

            // 趋势图
            if !sortedRecords.isEmpty {
                Section("Trend") {
                    trendChart
                        .frame(height: 200)
                        .listRowInsets(EdgeInsets())
                        .padding()
                }
            }

            // 历史记录
            Section("History") {
                if sortedRecords.isEmpty {
                    Text("No records yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(sortedRecords.reversed()) { record in
                        recordRow(record)
                    }
                    .onDelete(perform: deleteRecords)
                }
            }

            // 参考信息
            Section("Reference") {
                LabeledContent("Normal Range", value: template.referenceRangeText)
                LabeledContent("Unit", value: template.unit)
                LabeledContent("Body Zone", value: template.bodyZone.rawValue)
                LabeledContent("Category", value: template.category.rawValue)

                if let description = template.indicatorDescription {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(template.name)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 16) {
                    Button {
                        withAnimation {
                            template.isFavorite.toggle()
                        }
                    } label: {
                        Image(systemName: template.isFavorite ? "star.fill" : "star")
                            .foregroundStyle(template.isFavorite ? .yellow : .secondary)
                    }

                    Button {
                        showingAddRecord = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddRecord) {
            AddRecordView(template: template)
        }
        .id(forceRedraw)
        .eraseToAnyView()
    }

    // MARK: - Overview Card

    private var overviewCard: some View {
        let record = template.latestRecord
        let status = record?.status(for: .male) ?? .unknown

        return HStack {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text("Latest Value")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if status.isAbnormal {
                        StatusPill(status: status)
                    }
                }

                if let record {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(record.formattedValue)
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(status.isAbnormal ? status.color : .primary)
                        Text(template.unit)
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }

                    Text(record.testDate.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("--")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Image(systemName: template.bodyZone.icon)
                .font(.system(size: 40))
                .foregroundStyle(
                    status.isAbnormal ? status.color.opacity(0.6) : .blue.opacity(0.6))
        }
        .padding(.vertical, 8)
    }

    // MARK: - Trend Chart

    @ViewBuilder
    private var trendChart: some View {
        Chart(sortedRecords) { record in
            LineMark(
                x: .value("Date", record.testDate),
                y: .value("Value", record.value)
            )
            .foregroundStyle(.blue)

            PointMark(
                x: .value("Date", record.testDate),
                y: .value("Value", record.value)
            )
            .foregroundStyle(.blue)

            // 参考范围区域
            if let min = template.referenceRangeMin, let max = template.referenceRangeMax {
                RectangleMark(
                    yStart: .value("Min", min),
                    yEnd: .value("Max", max)
                )
                .foregroundStyle(.green.opacity(0.1))
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading)
        }
    }

    // MARK: - Record Row

    private func recordRow(_ record: HealthRecord) -> some View {
        let status = record.status(for: .male)

        return HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(record.testDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.subheadline)

                if let note = record.note {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            HStack(spacing: 8) {
                Text("\(record.formattedValue) \(template.unit)")
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundStyle(status.isAbnormal ? status.color : .primary)

                if status.isAbnormal {
                    Image(systemName: status.icon)
                        .font(.caption)
                        .foregroundStyle(status.color)
                }
            }
        }
    }

    private func deleteRecords(at offsets: IndexSet) {
        let recordsToDelete = offsets.map { sortedRecords.reversed()[$0] }
        for record in recordsToDelete {
            modelContext.delete(record)
        }
    }
}

// MARK: - 状态药丸

struct StatusPill: View {
    let status: HealthStatus

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: status.icon)
                .font(.system(size: 10, weight: .bold))
            Text(status.shortLabel)
                .font(.caption2)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .foregroundStyle(status.color)
        .background(status.backgroundColor)
        .clipShape(Capsule())
    }
}

// MARK: - Preview

struct IndicatorDetailViewPreview: View {
    @State private var template: IndicatorTemplate?

    var body: some View {
        NavigationStack {
            Group {
                if let template {
                    IndicatorDetailView(template: template)
                } else {
                    ProgressView()
                }
            }
        }
        .task {
            template = IndicatorTemplate(
                name: "空腹血糖",
                abbreviation: "FBG",
                unit: "mmol/L",
                bodyZone: .blood,
                category: .bloodBiochemistry,
                referenceRangeMin: 3.9,
                referenceRangeMax: 6.1,
                referenceRangeText: "3.9-6.1"
            )
        }
    }
}

#Preview {
    IndicatorDetailViewPreview()
        .modelContainer(for: [IndicatorTemplate.self, HealthRecord.self], inMemory: true)
}
