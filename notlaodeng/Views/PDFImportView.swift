//
//  PDFImportView.swift
//  notlaodeng
//
//  PDF 导入视图
//

import SwiftData
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Document Picker

struct DocumentPicker: UIViewControllerRepresentable {
    let onPick: (URL) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.pdf])
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(
        _ uiViewController: UIDocumentPickerViewController, context: Context
    ) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick, onCancel: onCancel)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void
        let onCancel: () -> Void

        init(onPick: @escaping (URL) -> Void, onCancel: @escaping () -> Void) {
            self.onPick = onPick
            self.onCancel = onCancel
        }

        func documentPicker(
            _ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]
        ) {
            guard let url = urls.first else {
                onCancel()
                return
            }
            onPick(url)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onCancel()
        }
    }
}

// MARK: - PDF 导入入口视图

struct PDFImportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var showingPicker = true
    @State private var selectedURL: URL?
    @State private var isProcessing = false
    @State private var parsedReport: ParsedReport?
    @State private var errorMessage: String?
    @State private var extractionMethod: String = ""

    var body: some View {
        NavigationStack {
            Group {
                if isProcessing {
                    processingView
                } else if let report = parsedReport {
                    ScanResultView(
                        report: report,
                        onConfirm: { selectedIndicators, date in
                            saveIndicators(selectedIndicators, testDate: date)
                        },
                        onRescan: {
                            resetAndReselect()
                        }
                    )
                } else if let error = errorMessage {
                    errorView(error)
                } else {
                    Color.clear
                }
            }
            .navigationTitle("Import PDF")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingPicker) {
            DocumentPicker(
                onPick: { url in
                    selectedURL = url
                    showingPicker = false
                    processFile(url)
                },
                onCancel: {
                    showingPicker = false
                    dismiss()
                }
            )
        }
    }

    // MARK: - Processing View

    private var processingView: some View {
        VStack(spacing: 24) {
            ProgressView()
                .scaleEffect(1.5)

            Text("Processing PDF...")
                .font(.headline)

            if !extractionMethod.isEmpty {
                Text(extractionMethod)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let url = selectedURL {
                Text(url.lastPathComponent)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Error View

    private func errorView(_ message: String) -> some View {
        ContentUnavailableView {
            Label("Import Failed", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button("Select Another File") {
                resetAndReselect()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Actions

    private func processFile(_ url: URL) {
        isProcessing = true
        errorMessage = nil
        extractionMethod = "Analyzing PDF structure..."

        // 获取安全访问权限
        guard url.startAccessingSecurityScopedResource() else {
            errorMessage = "Cannot access the selected file. Please try again."
            isProcessing = false
            return
        }

        Task {
            defer {
                url.stopAccessingSecurityScopedResource()
            }

            do {
                await MainActor.run {
                    extractionMethod = "Extracting text..."
                }

                let text = try await PDFImportService.shared.extractText(from: url)

                await MainActor.run {
                    extractionMethod = "Parsing health data..."
                }

                let report = HealthReportParser.parse(text)

                await MainActor.run {
                    parsedReport = report
                    isProcessing = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isProcessing = false
                }
            }
        }
    }

    private func resetAndReselect() {
        selectedURL = nil
        parsedReport = nil
        errorMessage = nil
        extractionMethod = ""
        showingPicker = true
    }

    private func saveIndicators(_ indicators: [ParsedIndicator], testDate: Date) {
        guard !indicators.isEmpty else {
            dismiss()
            return
        }

        // 创建体检报告
        let report = HealthReport(
            name: "PDF Import \(testDate.formatted(date: .abbreviated, time: .omitted))",
            testDate: testDate,
            labName: nil
        )
        modelContext.insert(report)

        // 获取所有现有模板
        let descriptor = FetchDescriptor<IndicatorTemplate>()
        let templates = (try? modelContext.fetch(descriptor)) ?? []

        let classifier = KeywordIndicatorClassifier.shared

        for indicator in indicators {
            // 尝试匹配现有模板
            let matchedTemplate = templates.first { template in
                template.name == indicator.name || template.englishName == indicator.name
                    || template.abbreviation == indicator.name
            }

            let template: IndicatorTemplate
            if let existing = matchedTemplate {
                template = existing
            } else {
                // 使用分类器推断 bodyZone 和 category
                let classification = classifier.classify(
                    name: indicator.name,
                    unit: indicator.unit
                )

                // 创建新模板
                template = IndicatorTemplate(
                    name: indicator.name,
                    unit: indicator.unit,
                    bodyZone: classification.bodyZone,
                    category: classification.category,
                    referenceRangeMin: indicator.referenceMin,
                    referenceRangeMax: indicator.referenceMax,
                    referenceRangeText: indicator.referenceRange.isEmpty
                        ? "-" : indicator.referenceRange
                )
                modelContext.insert(template)
            }

            // 创建健康记录
            let record = HealthRecord(
                value: indicator.value,
                testDate: testDate,
                source: .imported,
                template: template,
                report: report
            )
            modelContext.insert(record)
        }

        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Preview

#Preview {
    PDFImportView()
}
