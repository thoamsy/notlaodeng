//
//  DocumentScannerView.swift
//  notlaodeng
//
//  文档扫描视图 (VisionKit)
//

import SwiftData
import SwiftUI
import VisionKit

// MARK: - 文档扫描器

struct DocumentScannerView: UIViewControllerRepresentable {
  let onScanComplete: ([UIImage]) -> Void
  let onCancel: () -> Void

  func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
    let scanner = VNDocumentCameraViewController()
    scanner.delegate = context.coordinator
    return scanner
  }

  func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context)
  {}

  func makeCoordinator() -> Coordinator {
    Coordinator(onScanComplete: onScanComplete, onCancel: onCancel)
  }

  class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
    let onScanComplete: ([UIImage]) -> Void
    let onCancel: () -> Void

    init(onScanComplete: @escaping ([UIImage]) -> Void, onCancel: @escaping () -> Void) {
      self.onScanComplete = onScanComplete
      self.onCancel = onCancel
    }

    func documentCameraViewController(
      _ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan
    ) {
      var images: [UIImage] = []
      for i in 0..<scan.pageCount {
        images.append(scan.imageOfPage(at: i))
      }
      controller.dismiss(animated: true) {
        self.onScanComplete(images)
      }
    }

    func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
      controller.dismiss(animated: true) {
        self.onCancel()
      }
    }

    func documentCameraViewController(
      _ controller: VNDocumentCameraViewController, didFailWithError error: Error
    ) {
      controller.dismiss(animated: true) {
        self.onCancel()
      }
    }
  }
}

// MARK: - 扫描入口视图

struct ScanReportView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext

  @State private var showingScanner = true
  @State private var scannedImages: [UIImage] = []
  @State private var isProcessing = false
  @State private var parsedReport: ParsedReport?
  @State private var errorMessage: String?

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
              resetAndRescan()
            }
          )
        } else if let error = errorMessage {
          errorView(error)
        } else {
          Color.clear
        }
      }
      .navigationTitle("Scan Report")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button("Cancel") {
            dismiss()
          }
        }
      }
    }
    .fullScreenCover(isPresented: $showingScanner) {
      DocumentScannerView(
        onScanComplete: { images in
          scannedImages = images
          showingScanner = false
          processImages()
        },
        onCancel: {
          showingScanner = false
          dismiss()
        }
      )
      .ignoresSafeArea()
    }
  }

  // MARK: - Processing View

  private var processingView: some View {
    VStack(spacing: 24) {
      ProgressView()
        .scaleEffect(1.5)

      Text("Recognizing text...")
        .font(.headline)

      Text("Scanning \(scannedImages.count) page(s)")
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }
  }

  // MARK: - Error View

  private func errorView(_ message: String) -> some View {
    ContentUnavailableView {
      Label("Recognition Failed", systemImage: "exclamationmark.triangle")
    } description: {
      Text(message)
    } actions: {
      Button("Try Again") {
        resetAndRescan()
      }
      .buttonStyle(.borderedProminent)
    }
  }

  // MARK: - Actions

  private func processImages() {
    isProcessing = true
    errorMessage = nil

    Task {
      do {
        let text = try await OCRService.shared.recognizeText(from: scannedImages)
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

  private func resetAndRescan() {
    scannedImages = []
    parsedReport = nil
    errorMessage = nil
    showingScanner = true
  }

  private func saveIndicators(_ indicators: [ParsedIndicator], testDate: Date) {
    guard !indicators.isEmpty else {
      dismiss()
      return
    }

    // 创建体检报告
    let report = HealthReport(
      name: "Scanned Report \(testDate.formatted(date: .abbreviated, time: .omitted))",
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
          referenceRangeText: indicator.referenceRange.isEmpty ? "-" : indicator.referenceRange
        )
        modelContext.insert(template)
      }

      // 创建健康记录
      let record = HealthRecord(
        value: indicator.value,
        testDate: testDate,
        source: .ocr,
        template: template,
        report: report
      )
      modelContext.insert(record)
    }

    try? modelContext.save()
    dismiss()
  }
}

// MARK: - 扫描结果视图

struct ScanResultView: View {
  let report: ParsedReport
  let onConfirm: ([ParsedIndicator], Date) -> Void
  let onRescan: () -> Void

  @State private var selectedIndicators: Set<UUID> = []
  @State private var editingIndicator: ParsedIndicator?
  @State private var showingRawText = false
  @State private var reportDate: Date = Date()

  var body: some View {
    VStack(spacing: 0) {
      // 统计信息
      statsHeader

      // 指标列表
      List {
        // 日期选择
        Section("Report Date") {
          DatePicker(
            "Test Date",
            selection: $reportDate,
            in: ...Date(),
            displayedComponents: .date
          )
        }

        if report.indicators.isEmpty {
          noIndicatorsView
        } else {
          indicatorsList
        }

        // 原始文本（导航到新页面，避免卡顿）
        Section {
          Button {
            showingRawText = true
          } label: {
            HStack {
              Label("Raw OCR Text", systemImage: "doc.text")
              Spacer()
              Text("\(report.rawText.count) chars")
                .font(.caption)
                .foregroundStyle(.tertiary)
              Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
            }
          }
          .foregroundStyle(.primary)
        }
      }

      // 底部操作栏
      bottomBar
    }
    .onAppear {
      // 默认选中所有指标
      selectedIndicators = Set(report.indicators.map { $0.id })
    }
    .sheet(isPresented: $showingRawText) {
      RawTextView(text: report.rawText)
    }
  }

  // MARK: - Stats Header

  private var statsHeader: some View {
    HStack(spacing: 20) {
      StatCard(
        title: "Found",
        value: "\(report.indicators.count)",
        icon: "doc.text.magnifyingglass",
        color: .blue
      )

      StatCard(
        title: "Abnormal",
        value: "\(report.abnormalCount)",
        icon: "exclamationmark.triangle.fill",
        color: report.abnormalCount > 0 ? .orange : .green
      )

      StatCard(
        title: "Selected",
        value: "\(selectedIndicators.count)",
        icon: "checkmark.circle.fill",
        color: .green
      )
    }
    .padding()
    .background(Color(.systemGroupedBackground))
  }

  // MARK: - Indicators List

  private var indicatorsList: some View {
    Section("Recognized Indicators") {
      ForEach(report.indicators) { indicator in
        IndicatorResultRow(
          indicator: indicator,
          isSelected: selectedIndicators.contains(indicator.id),
          onToggle: {
            if selectedIndicators.contains(indicator.id) {
              selectedIndicators.remove(indicator.id)
            } else {
              selectedIndicators.insert(indicator.id)
            }
          }
        )
      }
    }
  }

  private var noIndicatorsView: some View {
    Section {
      VStack(spacing: 12) {
        Image(systemName: "doc.text.magnifyingglass")
          .font(.largeTitle)
          .foregroundStyle(.secondary)

        Text("No indicators recognized")
          .font(.headline)

        Text("Try scanning a clearer image or adjust the camera angle.")
          .font(.caption)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 40)
    }
  }

  // MARK: - Bottom Bar

  private var bottomBar: some View {
    HStack(spacing: 16) {
      Button {
        onRescan()
      } label: {
        Label("Rescan", systemImage: "camera")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.bordered)

      Button {
        let selected = report.indicators.filter { selectedIndicators.contains($0.id) }
        onConfirm(selected, reportDate)
      } label: {
        Label("Import \(selectedIndicators.count)", systemImage: "square.and.arrow.down")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.borderedProminent)
      .disabled(selectedIndicators.isEmpty)
    }
    .padding()
    .background(.ultraThinMaterial)
  }
}

// MARK: - Stat Card

struct StatCard: View {
  let title: String
  let value: String
  let icon: String
  let color: Color

  var body: some View {
    VStack(spacing: 8) {
      Image(systemName: icon)
        .font(.title2)
        .foregroundStyle(color)

      Text(value)
        .font(.title2)
        .fontWeight(.bold)

      Text(title)
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 12)
    .background(color.opacity(0.1))
    .clipShape(RoundedRectangle(cornerRadius: 12))
  }
}

// MARK: - Indicator Result Row

struct IndicatorResultRow: View {
  let indicator: ParsedIndicator
  let isSelected: Bool
  let onToggle: () -> Void

  var body: some View {
    Button(action: onToggle) {
      HStack(spacing: 12) {
        // 选择状态
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
          .font(.title3)
          .foregroundStyle(isSelected ? .blue : .secondary)

        // 指标信息
        VStack(alignment: .leading, spacing: 4) {
          HStack {
            Text(indicator.name)
              .font(.headline)
              .foregroundStyle(.primary)

            if indicator.isAbnormal {
              Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.orange)
            }
          }

          if !indicator.referenceRange.isEmpty {
            Text("Reference: \(indicator.referenceRange)")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }

        Spacer()

        // 数值
        VStack(alignment: .trailing, spacing: 2) {
          Text(String(format: "%.2f", indicator.value))
            .font(.headline)
            .foregroundStyle(indicator.isAbnormal ? .orange : .primary)

          Text(indicator.unit)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
      .padding(.vertical, 4)
    }
    .buttonStyle(.plain)
  }
}

// MARK: - Raw Text View

struct RawTextView: View {
  @Environment(\.dismiss) private var dismiss
  let text: String

  var body: some View {
    NavigationStack {
      ScrollView {
        Text(text)
          .font(.system(.caption, design: .monospaced))
          .foregroundStyle(.secondary)
          .padding()
          .frame(maxWidth: .infinity, alignment: .leading)
          .textSelection(.enabled)
      }
      .navigationTitle("Raw OCR Text")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Done") {
            dismiss()
          }
        }

        ToolbarItem(placement: .topBarLeading) {
          ShareLink(item: text) {
            Image(systemName: "square.and.arrow.up")
          }
        }
      }
    }
  }
}

// MARK: - Preview

#Preview {
  ScanReportView()
}
