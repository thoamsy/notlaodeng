//
//  ReportsView.swift
//  notlaodeng
//
//  体检报告列表视图
//

import SwiftUI
import SwiftData

struct ReportsView: View {
    @ObserveInjection var forceRedraw

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \HealthReport.testDate, order: .reverse) private var reports: [HealthReport]

    @State private var showingImportAlert = false

    var body: some View {
        NavigationStack {
            Group {
                if reports.isEmpty {
                    ContentUnavailableView {
                        Label("No Reports", systemImage: "doc.text")
                    } description: {
                        Text("Your health reports will appear here.")
                    } actions: {
                        Button("Import Sample Data") {
                            showingImportAlert = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        ForEach(reports) { report in
                            reportRow(report)
                        }
                        .onDelete(perform: deleteReports)
                    }
                }
            }
            .navigationTitle("Reports")
            .toolbar {
                if !reports.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button("Import 2025 Report") {
                                showingImportAlert = true
                            }
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .alert("Import Health Data", isPresented: $showingImportAlert) {
                Button("Import") {
                    SeedData.importHealthReport_20250424(modelContext: modelContext)
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Import the 2025-04-24 health checkup data?")
            }
        }
        .id(forceRedraw)
        .eraseToAnyView()
    }

    private func reportRow(_ report: HealthReport) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(report.name)
                .font(.headline)

            HStack {
                Label(report.testDate.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")

                if let labName = report.labName {
                    Label(labName, systemImage: "building.2")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Text("\(report.records.count) indicators")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func deleteReports(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(reports[index])
        }
    }
}

#Preview {
    ReportsView()
        .modelContainer(for: HealthReport.self, inMemory: true)
}

