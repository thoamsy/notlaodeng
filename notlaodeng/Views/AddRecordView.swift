//
//  AddRecordView.swift
//  notlaodeng
//
//  添加记录视图
//

import SwiftData
import SwiftUI

struct AddRecordView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext

  let template: IndicatorTemplate

  @State private var value: String = ""
  @State private var testDate: Date = Date()
  @State private var note: String = ""
  @State private var labName: String = ""

  var isValidValue: Bool {
    Double(value) != nil
  }

  var body: some View {
    NavigationStack {
      Form {
        Section {
          HStack {
            Text(template.name)
              .font(.headline)
            Spacer()
            Text(template.unit)
              .foregroundStyle(.secondary)
          }
        }

        Section("Value") {
          HStack {
            TextField("Enter value", text: $value)
              .keyboardType(.decimalPad)
              .font(.title2)

            Text(template.unit)
              .foregroundStyle(.secondary)
          }

          Text("Reference: \(template.referenceRangeText)")
            .font(.caption)
            .foregroundStyle(.secondary)
        }

        Section("Date") {
          DatePicker("Test Date", selection: $testDate, displayedComponents: .date)
        }

        Section("Optional") {
          TextField("Lab/Hospital Name", text: $labName)
          TextField("Note", text: $note, axis: .vertical)
            .lineLimit(3...6)
        }
      }
      .navigationTitle("Add Record")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            dismiss()
          }
        }

        ToolbarItem(placement: .confirmationAction) {
          Button("Save") {
            saveRecord()
          }
          .disabled(!isValidValue)
        }
      }
    }
  }

  private func saveRecord() {
    guard let numericValue = Double(value) else { return }

    let record = HealthRecord(
      value: numericValue,
      testDate: testDate,
      source: .manual,
      note: note.isEmpty ? nil : note,
      labName: labName.isEmpty ? nil : labName,
      template: template
    )

    modelContext.insert(record)
    dismiss()
  }
}

// MARK: - Preview

struct AddRecordViewPreview: View {
  @State private var template: IndicatorTemplate?

  var body: some View {
    Group {
      if let template {
        AddRecordView(template: template)
      } else {
        ProgressView()
      }
    }
    .task {
      template = IndicatorTemplate(
        name: "空腹血糖",
        unit: "mmol/L",
        bodyZone: .blood,
        category: .bloodBiochemistry,
        referenceRangeText: "3.9-6.1"
      )
    }
  }
}

#Preview {
  AddRecordViewPreview()
    .modelContainer(for: [IndicatorTemplate.self, HealthRecord.self], inMemory: true)
}
