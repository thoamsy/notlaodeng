//
//  ReportsView.swift
//  notlaodeng
//
//  体检报告列表视图
//

import SwiftData
import SwiftUI

struct ReportsView: View {
    @ObserveInjection var forceRedraw

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \HealthReport.testDate, order: .reverse) private var reports: [HealthReport]

    @State private var showingImportAlert = false
    @State private var showingScanner = false
    @State private var showingPDFImport = false
    @State private var reportToDelete: HealthReport?
    @State private var showingDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            Group {
                if reports.isEmpty {
                    emptyStateView
                } else {
                    reportsList
                }
            }
            .navigationTitle("Reports")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showingScanner = true
                        } label: {
                            Label("Scan Report", systemImage: "doc.viewfinder")
                        }

                        Button {
                            showingPDFImport = true
                        } label: {
                            Label("Import PDF", systemImage: "doc.badge.plus")
                        }

                        Divider()

                        Button {
                            showingImportAlert = true
                        } label: {
                            Label("Import Sample Data", systemImage: "square.and.arrow.down")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .alert("Import Health Data", isPresented: $showingImportAlert) {
                Button("Import") {
                    SeedData.importHealthReport_20250424(modelContext: modelContext)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Import the 2025-04-24 health checkup data?")
            }
            .fullScreenCover(isPresented: $showingScanner) {
                ScanReportView()
            }
            .fullScreenCover(isPresented: $showingPDFImport) {
                PDFImportView()
            }
            .alert(
                "Delete Report", isPresented: $showingDeleteConfirmation, presenting: reportToDelete
            ) { report in
                Button("Delete", role: .destructive) {
                    deleteReport(report)
                }
                Button("Cancel", role: .cancel) {
                    reportToDelete = nil
                }
            } message: { report in
                Text(
                    "This will also delete \(report.records.count) associated health records. This action cannot be undone."
                )
            }
        }
        .id(forceRedraw)
        .eraseToAnyView()
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("No Reports", systemImage: "doc.text")
        } description: {
            Text("Scan your health reports or import PDF files to get started.")
        } actions: {
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    Button {
                        showingScanner = true
                    } label: {
                        Label("Scan", systemImage: "doc.viewfinder")
                            .frame(minWidth: 100)
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        showingPDFImport = true
                    } label: {
                        Label("PDF", systemImage: "doc.badge.plus")
                            .frame(minWidth: 100)
                    }
                    .buttonStyle(.borderedProminent)
                }

                Button {
                    showingImportAlert = true
                } label: {
                    Label("Import Sample", systemImage: "square.and.arrow.down")
                        .frame(minWidth: 160)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    // MARK: - Reports List

    private var reportsList: some View {
        List {
            ForEach(reports) { report in
                NavigationLink {
                    ReportDetailView(report: report)
                } label: {
                    reportRow(report)
                }
            }
            .onDelete(perform: deleteReports)
        }
    }

    private func reportRow(_ report: HealthReport) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(report.name)
                .font(.headline)

            HStack {
                Label(
                    report.testDate.formatted(date: .abbreviated, time: .omitted),
                    systemImage: "calendar")

                if let labName = report.labName {
                    Label(labName, systemImage: "building.2")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            HStack {
                Text("\(report.records.count) indicators")

                let abnormalCount = report.records.filter { record in
                    record.status(for: .male).isAbnormal
                }.count

                if abnormalCount > 0 {
                    Text("•")
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text("\(abnormalCount) abnormal")
                    }
                    .foregroundStyle(.orange)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func deleteReports(at offsets: IndexSet) {
        guard let index = offsets.first else { return }
        reportToDelete = reports[index]
        showingDeleteConfirmation = true
    }

    private func deleteReport(_ report: HealthReport) {
        // 先删除关联的健康记录
        for record in report.records {
            modelContext.delete(record)
        }
        // 再删除报告本身
        modelContext.delete(report)
        try? modelContext.save()
        reportToDelete = nil
    }
}

// MARK: - Report Detail View

struct ReportDetailView: View {
    @Bindable var report: HealthReport
    @State private var showingEditSheet = false

    @Query private var profiles: [UserProfile]

    private var currentGender: Gender {
        profiles.first?.gender ?? .male
    }

    private var sortedRecords: [HealthRecord] {
        report.records.sorted { ($0.template?.name ?? "") < ($1.template?.name ?? "") }
    }

    private var abnormalRecords: [HealthRecord] {
        sortedRecords.filter { $0.status(for: currentGender).isAbnormal }
    }

    private var normalRecords: [HealthRecord] {
        sortedRecords.filter { !$0.status(for: currentGender).isAbnormal }
    }

    var body: some View {
        List {
            // 报告信息
            Section {
                LabeledContent(
                    "Date", value: report.testDate.formatted(date: .long, time: .omitted))
                if let labName = report.labName {
                    LabeledContent("Lab", value: labName)
                }
                LabeledContent("Total Indicators", value: "\(report.records.count)")
            }

            // 异常指标
            if !abnormalRecords.isEmpty {
                Section("Abnormal (\(abnormalRecords.count))") {
                    ForEach(abnormalRecords) { record in
                        RecordRowInReport(record: record, gender: currentGender)
                    }
                }
            }

            // 正常指标
            if !normalRecords.isEmpty {
                Section("Normal (\(normalRecords.count))") {
                    ForEach(normalRecords) { record in
                        RecordRowInReport(record: record, gender: currentGender)
                    }
                }
            }
        }
        .navigationTitle(report.name)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingEditSheet = true
                } label: {
                    Text("Edit")
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            EditReportSheet(report: report)
        }
    }
}

// MARK: - Edit Report Sheet

struct EditReportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var report: HealthReport

    @State private var name: String = ""
    @State private var testDate: Date = Date()
    @State private var labName: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Report Name") {
                    TextField("Name", text: $name)
                }

                Section("Test Date") {
                    DatePicker(
                        "Date",
                        selection: $testDate,
                        in: ...Date(),
                        displayedComponents: .date
                    )
                }

                Section("Lab / Hospital") {
                    TextField("Lab name (optional)", text: $labName)
                }
            }
            .navigationTitle("Edit Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                name = report.name
                testDate = report.testDate
                labName = report.labName ?? ""
            }
        }
    }

    private func saveChanges() {
        report.name = name.trimmingCharacters(in: .whitespaces)

        // 如果日期改变，同步更新所有关联记录的日期
        if report.testDate != testDate {
            report.testDate = testDate
            for record in report.records {
                record.testDate = testDate
            }
        }

        report.labName =
            labName.trimmingCharacters(in: .whitespaces).isEmpty
            ? nil
            : labName.trimmingCharacters(in: .whitespaces)
    }
}

// MARK: - Record Row in Report

struct RecordRowInReport: View {
    let record: HealthRecord
    let gender: Gender

    private var status: HealthStatus {
        record.status(for: gender)
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(record.template?.name ?? "Unknown")
                        .font(.headline)

                    if status.isAbnormal {
                        Image(systemName: status.icon)
                            .font(.caption)
                            .foregroundStyle(status.color)
                    }
                }

                if let template = record.template {
                    Text(template.referenceRangeText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(record.formattedValue)
                    .font(.headline)
                    .foregroundStyle(status.isAbnormal ? status.color : .primary)

                Text(record.template?.unit ?? "")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    ReportsView()
        .modelContainer(for: [HealthReport.self, UserProfile.self], inMemory: true)
}
