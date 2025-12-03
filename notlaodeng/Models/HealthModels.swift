//
//  HealthModels.swift
//  notlaodeng
//
//  体检数据模型定义 - SwiftData 版本
//

import Foundation
import SwiftData
import SwiftUI

// MARK: - 核心枚举

/// 性别
enum Gender: String, Codable, CaseIterable {
    case male = "男"
    case female = "女"
}

/// 身体部位/系统
enum BodyZone: String, Codable, CaseIterable {
    case fullBody = "全身"
    case head = "头部"
    case eye = "眼科"
    case ear = "耳鼻喉"
    case oral = "口腔"
    case thyroid = "甲状腺"
    case chest = "胸部"
    case heart = "心血管"
    case lung = "肺部"
    case liver = "肝脏"
    case kidney = "肾脏"
    case digestive = "消化系统"
    case blood = "血液"
    case urinary = "泌尿系统"
    case reproductive = "生殖系统"
    case bone = "骨骼"
    case skin = "皮肤"
    case nervous = "神经系统"

    var icon: String {
        switch self {
        case .fullBody: return "figure.stand"
        case .head: return "brain.head.profile"
        case .eye: return "eye"
        case .ear: return "ear"
        case .oral: return "mouth.fill"
        case .thyroid: return "staroflife"
        case .chest: return "lungs.fill"
        case .heart: return "heart.fill"
        case .lung: return "lungs.fill"
        case .liver: return "cross.vial.fill"
        case .kidney: return "drop.halffull"
        case .digestive: return "leaf.fill"
        case .blood: return "drop.fill"
        case .urinary: return "humidity.fill"
        case .reproductive: return "person.2.fill"
        case .bone: return "figure.walk"
        case .skin: return "hand.raised.fill"
        case .nervous: return "brain"
        }
    }
}

/// 指标分类
enum IndicatorCategory: String, Codable, CaseIterable {
    case routine = "常规检查"
    case bloodRoutine = "血常规"
    case bloodBiochemistry = "血生化"
    case urineRoutine = "尿常规"
    case thyroidFunction = "甲状腺功能"
    case tumorMarker = "肿瘤标志物"
    case imaging = "影像检查"
    case electrocardiogram = "心电图"
    case vision = "视力检查"
    case hearing = "听力检查"
    case other = "其他"

    var icon: String {
        switch self {
        case .routine: return "list.clipboard"
        case .bloodRoutine: return "drop.fill"
        case .bloodBiochemistry: return "testtube.2"
        case .urineRoutine: return "humidity.fill"
        case .thyroidFunction: return "staroflife"
        case .tumorMarker: return "exclamationmark.shield.fill"
        case .imaging: return "photo.artframe"
        case .electrocardiogram: return "waveform.path.ecg"
        case .vision: return "eye"
        case .hearing: return "ear"
        case .other: return "ellipsis.circle"
        }
    }
}

/// 数据来源
enum RecordSource: String, Codable {
    case manual = "手动录入"
    case ocr = "OCR识别"
    case healthKit = "HealthKit"
    case imported = "文件导入"
}

/// 健康状态
enum HealthStatus: String, Codable, CaseIterable {
    case normal = "正常"
    case high = "偏高"
    case low = "偏低"
    case criticalHigh = "严重偏高"
    case criticalLow = "严重偏低"
    case unknown = "未知"

    /// 是否异常（非正常）
    var isAbnormal: Bool {
        self != .normal && self != .unknown
    }

    /// 是否严重异常
    var isCritical: Bool {
        self == .criticalHigh || self == .criticalLow
    }

    /// 显示图标
    var icon: String {
        switch self {
        case .normal: return "checkmark.circle.fill"
        case .high, .criticalHigh: return "arrow.up.circle.fill"
        case .low, .criticalLow: return "arrow.down.circle.fill"
        case .unknown: return "questionmark.circle.fill"
        }
    }

    /// 简短标签
    var shortLabel: String {
        switch self {
        case .normal: return "Normal"
        case .high: return "High"
        case .low: return "Low"
        case .criticalHigh: return "High!"
        case .criticalLow: return "Low!"
        case .unknown: return "N/A"
        }
    }

    /// SwiftUI 颜色
    var color: Color {
        switch self {
        case .normal: return .green
        case .high, .low: return .orange
        case .criticalHigh, .criticalLow: return .red
        case .unknown: return .gray
        }
    }

    /// 背景色（更浅）
    var backgroundColor: Color {
        color.opacity(0.15)
    }
}

/// 趋势方向偏好
enum TrendPreference: String, Codable {
    case higherBetter = "越高越好"
    case lowerBetter = "越低越好"
    case rangeOptimal = "区间最佳"
    case stable = "稳定最佳"
}

/// 血型
enum BloodType: String, Codable, CaseIterable {
    case aPositive = "A+"
    case aNegative = "A-"
    case bPositive = "B+"
    case bNegative = "B-"
    case abPositive = "AB+"
    case abNegative = "AB-"
    case oPositive = "O+"
    case oNegative = "O-"
}

// MARK: - SwiftData 模型

/// 用户档案
@Model
final class UserProfile {
    var name: String
    var birthDate: Date
    var genderRaw: String
    var bloodTypeRaw: String?
    var height: Double?
    var weight: Double?
    var medicalHistory: [String]
    var allergies: [String]
    var familyHistory: [String]
    var createdAt: Date

    var gender: Gender {
        get { Gender(rawValue: genderRaw) ?? .male }
        set { genderRaw = newValue.rawValue }
    }

    var bloodType: BloodType? {
        get { bloodTypeRaw.flatMap { BloodType(rawValue: $0) } }
        set { bloodTypeRaw = newValue?.rawValue }
    }

    var age: Int {
        Calendar.current.dateComponents([.year], from: birthDate, to: Date()).year ?? 0
    }

    var bmi: Double? {
        guard let h = height, let w = weight, h > 0 else { return nil }
        let heightInMeters = h / 100.0
        return w / (heightInMeters * heightInMeters)
    }

    init(
        name: String,
        birthDate: Date,
        gender: Gender,
        bloodType: BloodType? = nil,
        height: Double? = nil,
        weight: Double? = nil,
        medicalHistory: [String] = [],
        allergies: [String] = [],
        familyHistory: [String] = []
    ) {
        self.name = name
        self.birthDate = birthDate
        self.genderRaw = gender.rawValue
        self.bloodTypeRaw = bloodType?.rawValue
        self.height = height
        self.weight = weight
        self.medicalHistory = medicalHistory
        self.allergies = allergies
        self.familyHistory = familyHistory
        self.createdAt = Date()
    }
}

/// 体检指标模板
@Model
final class IndicatorTemplate {
    var name: String
    var englishName: String?
    var abbreviation: String?
    var unit: String
    var bodyZoneRaw: String
    var categoryRaw: String
    var indicatorDescription: String?
    var trendPreferenceRaw: String

    // 参考范围（简化版，存储为 JSON）
    var referenceRangeMin: Double?
    var referenceRangeMax: Double?
    var referenceRangeText: String
    var referenceRangeNote: String?

    // 性别特定的参考范围
    var maleRangeMin: Double?
    var maleRangeMax: Double?
    var femaleRangeMin: Double?
    var femaleRangeMax: Double?

    @Relationship(deleteRule: .cascade, inverse: \HealthRecord.template)
    var records: [HealthRecord] = []

    var bodyZone: BodyZone {
        get { BodyZone(rawValue: bodyZoneRaw) ?? .blood }
        set { bodyZoneRaw = newValue.rawValue }
    }

    var category: IndicatorCategory {
        get { IndicatorCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    var trendPreference: TrendPreference {
        get { TrendPreference(rawValue: trendPreferenceRaw) ?? .rangeOptimal }
        set { trendPreferenceRaw = newValue.rawValue }
    }

    init(
        name: String,
        englishName: String? = nil,
        abbreviation: String? = nil,
        unit: String,
        bodyZone: BodyZone,
        category: IndicatorCategory,
        description: String? = nil,
        trendPreference: TrendPreference = .rangeOptimal,
        referenceRangeMin: Double? = nil,
        referenceRangeMax: Double? = nil,
        referenceRangeText: String,
        referenceRangeNote: String? = nil,
        maleRangeMin: Double? = nil,
        maleRangeMax: Double? = nil,
        femaleRangeMin: Double? = nil,
        femaleRangeMax: Double? = nil
    ) {
        self.name = name
        self.englishName = englishName
        self.abbreviation = abbreviation
        self.unit = unit
        self.bodyZoneRaw = bodyZone.rawValue
        self.categoryRaw = category.rawValue
        self.indicatorDescription = description
        self.trendPreferenceRaw = trendPreference.rawValue
        self.referenceRangeMin = referenceRangeMin
        self.referenceRangeMax = referenceRangeMax
        self.referenceRangeText = referenceRangeText
        self.referenceRangeNote = referenceRangeNote
        self.maleRangeMin = maleRangeMin
        self.maleRangeMax = maleRangeMax
        self.femaleRangeMin = femaleRangeMin
        self.femaleRangeMax = femaleRangeMax
    }

    /// 获取适用于特定性别的参考范围
    func getReferenceRange(for gender: Gender) -> (min: Double?, max: Double?) {
        switch gender {
        case .male:
            if maleRangeMin != nil || maleRangeMax != nil {
                return (maleRangeMin, maleRangeMax)
            }
        case .female:
            if femaleRangeMin != nil || femaleRangeMax != nil {
                return (femaleRangeMin, femaleRangeMax)
            }
        }
        return (referenceRangeMin, referenceRangeMax)
    }

    /// 判断值是否在参考范围内
    func isInRange(_ value: Double, gender: Gender) -> Bool {
        let range = getReferenceRange(for: gender)
        let aboveMin = range.min.map { value >= $0 } ?? true
        let belowMax = range.max.map { value <= $0 } ?? true
        return aboveMin && belowMax
    }

    /// 获取最新记录
    var latestRecord: HealthRecord? {
        records.sorted { $0.testDate > $1.testDate }.first
    }
}

/// 体检记录
@Model
final class HealthRecord {
    var value: Double
    var testDate: Date
    var createdAt: Date
    var sourceRaw: String
    var note: String?
    var labName: String?

    var template: IndicatorTemplate?
    var report: HealthReport?

    var source: RecordSource {
        get { RecordSource(rawValue: sourceRaw) ?? .manual }
        set { sourceRaw = newValue.rawValue }
    }

    init(
        value: Double,
        testDate: Date,
        source: RecordSource = .manual,
        note: String? = nil,
        labName: String? = nil,
        template: IndicatorTemplate? = nil,
        report: HealthReport? = nil
    ) {
        self.value = value
        self.testDate = testDate
        self.createdAt = Date()
        self.sourceRaw = source.rawValue
        self.note = note
        self.labName = labName
        self.template = template
        self.report = report
    }

    /// 判断健康状态
    func status(for gender: Gender) -> HealthStatus {
        guard let template = template else { return .unknown }

        let range = template.getReferenceRange(for: gender)

        // 检查是否在范围内
        if template.isInRange(value, gender: gender) {
            return .normal
        }

        // 判断是偏高还是偏低
        let isHigh: Bool
        if let max = range.max, value > max {
            isHigh = true
        } else if let min = range.min, value < min {
            isHigh = false
        } else {
            // 单边界情况
            if range.max != nil {
                isHigh = true
            } else {
                isHigh = false
            }
        }

        // 计算偏离程度来判断是否严重
        let deviation = calculateDeviation(range: range)
        let isCritical = deviation > 0.2  // 偏离超过 20% 为严重

        if isHigh {
            return isCritical ? .criticalHigh : .high
        } else {
            return isCritical ? .criticalLow : .low
        }
    }

    /// 计算偏离程度
    private func calculateDeviation(range: (min: Double?, max: Double?)) -> Double {
        // 双边界情况
        if let min = range.min, let max = range.max, max > min {
            let rangeWidth = max - min
            if value < min {
                return (min - value) / rangeWidth
            } else if value > max {
                return (value - max) / rangeWidth
            }
            return 0
        }

        // 单边界情况：使用参考值的百分比
        if let max = range.max, value > max {
            return (value - max) / max
        }
        if let min = range.min, value < min {
            return (min - value) / min
        }

        return 0
    }

    /// 格式化显示值
    var formattedValue: String {
        if value == value.rounded() {
            return String(format: "%.0f", value)
        } else {
            return String(format: "%.2f", value)
        }
    }
}

/// 体检报告
@Model
final class HealthReport {
    var name: String
    var testDate: Date
    var labName: String?
    var note: String?
    var createdAt: Date

    @Relationship(deleteRule: .nullify, inverse: \HealthRecord.report)
    var records: [HealthRecord] = []

    init(
        name: String,
        testDate: Date,
        labName: String? = nil,
        note: String? = nil
    ) {
        self.name = name
        self.testDate = testDate
        self.labName = labName
        self.note = note
        self.createdAt = Date()
    }

    /// 报告中的异常指标数量
    var abnormalCount: Int {
        // 需要传入用户性别来计算
        0
    }
}
