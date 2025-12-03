//
//  SeedData.swift
//  notlaodeng
//
//  初始化指标模板和示例数据
//

import Foundation
import SwiftData

/// 数据初始化器
enum SeedData {

    /// 初始化所有指标模板
    @MainActor
    static func seedIndicatorTemplates(modelContext: ModelContext) {
        // 检查是否已经有数据
        let descriptor = FetchDescriptor<IndicatorTemplate>()
        let count = (try? modelContext.fetchCount(descriptor)) ?? 0
        guard count == 0 else { return }

        // 创建所有指标模板
        for template in allTemplates {
            modelContext.insert(template)
        }

        try? modelContext.save()
    }

    /// 创建示例用户档案
    @MainActor
    static func createSampleUserProfile(modelContext: ModelContext) -> UserProfile {
        // 检查是否已有用户
        let descriptor = FetchDescriptor<UserProfile>()
        if let existing = try? modelContext.fetch(descriptor).first {
            return existing
        }

        // 创建新用户 (基于体检报告)
        let profile = UserProfile(
            name: "杨魁",
            birthDate: Calendar.current.date(from: DateComponents(year: 1997, month: 1, day: 1)) ?? Date(),
            gender: .male,
            height: 168,
            weight: 56.8
        )
        modelContext.insert(profile)
        try? modelContext.save()
        return profile
    }

    // MARK: - 所有指标模板

    static var allTemplates: [IndicatorTemplate] {
        routineTemplates + bloodRoutineTemplates + liverFunctionTemplates +
        lipidTemplates + kidneyFunctionTemplates + tumorMarkerTemplates +
        gastricTemplates + thyroidTemplates
    }

    // MARK: - 常规检查

    static var routineTemplates: [IndicatorTemplate] {
        [
            IndicatorTemplate(
                name: "收缩压",
                englishName: "Systolic Blood Pressure",
                abbreviation: "SBP",
                unit: "mmHg",
                bodyZone: .heart,
                category: .routine,
                description: "心脏收缩时动脉内的最高压力",
                trendPreference: .lowerBetter,
                referenceRangeMax: 120,
                referenceRangeText: "<120"
            ),
            IndicatorTemplate(
                name: "舒张压",
                englishName: "Diastolic Blood Pressure",
                abbreviation: "DBP",
                unit: "mmHg",
                bodyZone: .heart,
                category: .routine,
                description: "心脏舒张时动脉内的最低压力",
                trendPreference: .lowerBetter,
                referenceRangeMax: 80,
                referenceRangeText: "<80"
            ),
            IndicatorTemplate(
                name: "体重指数",
                englishName: "Body Mass Index",
                abbreviation: "BMI",
                unit: "kg/m²",
                bodyZone: .fullBody,
                category: .routine,
                description: "体重(kg)除以身高(m)的平方",
                trendPreference: .rangeOptimal,
                referenceRangeMin: 18.5,
                referenceRangeMax: 23.9,
                referenceRangeText: "18.5-23.9"
            ),
            IndicatorTemplate(
                name: "脉搏",
                englishName: "Pulse Rate",
                abbreviation: "PR",
                unit: "次/分",
                bodyZone: .heart,
                category: .routine,
                trendPreference: .rangeOptimal,
                referenceRangeMin: 60,
                referenceRangeMax: 100,
                referenceRangeText: "60-100"
            ),
        ]
    }

    // MARK: - 血常规

    static var bloodRoutineTemplates: [IndicatorTemplate] {
        [
            IndicatorTemplate(
                name: "白细胞计数",
                englishName: "White Blood Cell Count",
                abbreviation: "WBC",
                unit: "×10⁹/L",
                bodyZone: .blood,
                category: .bloodRoutine,
                trendPreference: .rangeOptimal,
                referenceRangeMin: 3.5,
                referenceRangeMax: 9.5,
                referenceRangeText: "3.5-9.5"
            ),
            IndicatorTemplate(
                name: "中性粒细胞绝对值",
                englishName: "Neutrophil Absolute Count",
                abbreviation: "GRAN#",
                unit: "×10⁹/L",
                bodyZone: .blood,
                category: .bloodRoutine,
                description: "白细胞的一种，参与免疫防御",
                trendPreference: .rangeOptimal,
                referenceRangeMin: 1.8,
                referenceRangeMax: 6.3,
                referenceRangeText: "1.8-6.3"
            ),
            IndicatorTemplate(
                name: "淋巴细胞绝对值",
                englishName: "Lymphocyte Absolute Count",
                abbreviation: "LYM#",
                unit: "×10⁹/L",
                bodyZone: .blood,
                category: .bloodRoutine,
                trendPreference: .rangeOptimal,
                referenceRangeMin: 1.1,
                referenceRangeMax: 3.2,
                referenceRangeText: "1.1-3.2"
            ),
            IndicatorTemplate(
                name: "红细胞计数",
                englishName: "Red Blood Cell Count",
                abbreviation: "RBC",
                unit: "×10¹²/L",
                bodyZone: .blood,
                category: .bloodRoutine,
                trendPreference: .rangeOptimal,
                referenceRangeMin: 4.3,
                referenceRangeMax: 5.8,
                referenceRangeText: "4.3-5.8",
                maleRangeMin: 4.3,
                maleRangeMax: 5.8,
                femaleRangeMin: 3.8,
                femaleRangeMax: 5.1
            ),
            IndicatorTemplate(
                name: "血红蛋白",
                englishName: "Hemoglobin",
                abbreviation: "HGB",
                unit: "g/L",
                bodyZone: .blood,
                category: .bloodRoutine,
                trendPreference: .rangeOptimal,
                referenceRangeMin: 130,
                referenceRangeMax: 175,
                referenceRangeText: "130-175",
                maleRangeMin: 130,
                maleRangeMax: 175,
                femaleRangeMin: 115,
                femaleRangeMax: 150
            ),
            IndicatorTemplate(
                name: "血小板计数",
                englishName: "Platelet Count",
                abbreviation: "PLT",
                unit: "×10⁹/L",
                bodyZone: .blood,
                category: .bloodRoutine,
                trendPreference: .rangeOptimal,
                referenceRangeMin: 125,
                referenceRangeMax: 350,
                referenceRangeText: "125-350"
            ),
        ]
    }

    // MARK: - 肝功能

    static var liverFunctionTemplates: [IndicatorTemplate] {
        [
            IndicatorTemplate(
                name: "谷丙转氨酶",
                englishName: "Alanine Aminotransferase",
                abbreviation: "ALT",
                unit: "U/L",
                bodyZone: .liver,
                category: .bloodBiochemistry,
                description: "肝细胞损伤的敏感指标",
                trendPreference: .lowerBetter,
                referenceRangeMax: 40,
                referenceRangeText: "≤40"
            ),
            IndicatorTemplate(
                name: "谷草转氨酶",
                englishName: "Aspartate Aminotransferase",
                abbreviation: "AST",
                unit: "U/L",
                bodyZone: .liver,
                category: .bloodBiochemistry,
                trendPreference: .rangeOptimal,
                referenceRangeMin: 8,
                referenceRangeMax: 40,
                referenceRangeText: "8-40"
            ),
            IndicatorTemplate(
                name: "γ-谷氨酰转肽酶",
                englishName: "Gamma-Glutamyl Transferase",
                abbreviation: "GGT",
                unit: "U/L",
                bodyZone: .liver,
                category: .bloodBiochemistry,
                description: "肝胆疾病的敏感指标",
                trendPreference: .rangeOptimal,
                referenceRangeMin: 10,
                referenceRangeMax: 60,
                referenceRangeText: "10-60"
            ),
            IndicatorTemplate(
                name: "碱性磷酸酶",
                englishName: "Alkaline Phosphatase",
                abbreviation: "ALP",
                unit: "U/L",
                bodyZone: .liver,
                category: .bloodBiochemistry,
                trendPreference: .rangeOptimal,
                referenceRangeMin: 45,
                referenceRangeMax: 125,
                referenceRangeText: "45-125"
            ),
            IndicatorTemplate(
                name: "总胆红素",
                englishName: "Total Bilirubin",
                abbreviation: "T-BIL",
                unit: "μmol/L",
                bodyZone: .liver,
                category: .bloodBiochemistry,
                trendPreference: .lowerBetter,
                referenceRangeMax: 23,
                referenceRangeText: "≤23"
            ),
            IndicatorTemplate(
                name: "血清白蛋白",
                englishName: "Serum Albumin",
                abbreviation: "ALB",
                unit: "g/L",
                bodyZone: .liver,
                category: .bloodBiochemistry,
                description: "反映肝脏合成功能",
                trendPreference: .rangeOptimal,
                referenceRangeMin: 40,
                referenceRangeMax: 55,
                referenceRangeText: "40-55"
            ),
        ]
    }

    // MARK: - 血脂

    static var lipidTemplates: [IndicatorTemplate] {
        [
            IndicatorTemplate(
                name: "总胆固醇",
                englishName: "Total Cholesterol",
                abbreviation: "TC",
                unit: "mmol/L",
                bodyZone: .blood,
                category: .bloodBiochemistry,
                trendPreference: .lowerBetter,
                referenceRangeMax: 5.2,
                referenceRangeText: "≤5.2"
            ),
            IndicatorTemplate(
                name: "甘油三酯",
                englishName: "Triglycerides",
                abbreviation: "TG",
                unit: "mmol/L",
                bodyZone: .blood,
                category: .bloodBiochemistry,
                trendPreference: .lowerBetter,
                referenceRangeMax: 1.7,
                referenceRangeText: "≤1.7"
            ),
            IndicatorTemplate(
                name: "高密度脂蛋白胆固醇",
                englishName: "HDL Cholesterol",
                abbreviation: "HDL-C",
                unit: "mmol/L",
                bodyZone: .blood,
                category: .bloodBiochemistry,
                description: "好胆固醇，越高越好",
                trendPreference: .higherBetter,
                referenceRangeMin: 1.04,
                referenceRangeText: "≥1.04"
            ),
            IndicatorTemplate(
                name: "低密度脂蛋白胆固醇",
                englishName: "LDL Cholesterol",
                abbreviation: "LDL-C",
                unit: "mmol/L",
                bodyZone: .blood,
                category: .bloodBiochemistry,
                description: "坏胆固醇，越低越好",
                trendPreference: .lowerBetter,
                referenceRangeMax: 3.64,
                referenceRangeText: "≤3.64"
            ),
        ]
    }

    // MARK: - 肾功能

    static var kidneyFunctionTemplates: [IndicatorTemplate] {
        [
            IndicatorTemplate(
                name: "血清肌酐",
                englishName: "Serum Creatinine",
                abbreviation: "CR",
                unit: "μmol/L",
                bodyZone: .kidney,
                category: .bloodBiochemistry,
                description: "反映肾小球滤过功能",
                trendPreference: .rangeOptimal,
                referenceRangeMin: 57,
                referenceRangeMax: 97,
                referenceRangeText: "57-97",
                maleRangeMin: 57,
                maleRangeMax: 97,
                femaleRangeMin: 41,
                femaleRangeMax: 73
            ),
            IndicatorTemplate(
                name: "血清尿素",
                englishName: "Blood Urea Nitrogen",
                abbreviation: "BUN",
                unit: "mmol/L",
                bodyZone: .kidney,
                category: .bloodBiochemistry,
                trendPreference: .rangeOptimal,
                referenceRangeMin: 3.1,
                referenceRangeMax: 8.0,
                referenceRangeText: "3.1-8.0"
            ),
            IndicatorTemplate(
                name: "血清尿酸",
                englishName: "Serum Uric Acid",
                abbreviation: "UA",
                unit: "μmol/L",
                bodyZone: .kidney,
                category: .bloodBiochemistry,
                description: "嘌呤代谢产物，过高可致痛风",
                trendPreference: .lowerBetter,
                referenceRangeMax: 428,
                referenceRangeText: "≤428",
                maleRangeMax: 428,
                femaleRangeMax: 357
            ),
        ]
    }

    // MARK: - 肿瘤标志物

    static var tumorMarkerTemplates: [IndicatorTemplate] {
        [
            IndicatorTemplate(
                name: "甲胎蛋白",
                englishName: "Alpha-Fetoprotein",
                abbreviation: "AFP",
                unit: "ng/mL",
                bodyZone: .liver,
                category: .tumorMarker,
                description: "原发性肝癌的重要标志物",
                trendPreference: .lowerBetter,
                referenceRangeMax: 20,
                referenceRangeText: "≤20"
            ),
            IndicatorTemplate(
                name: "总前列腺特异性抗原",
                englishName: "Total Prostate-Specific Antigen",
                abbreviation: "t-PSA",
                unit: "ng/mL",
                bodyZone: .reproductive,
                category: .tumorMarker,
                description: "前列腺癌筛查指标（男性）",
                trendPreference: .lowerBetter,
                referenceRangeMax: 4,
                referenceRangeText: "≤4"
            ),
            IndicatorTemplate(
                name: "糖链抗原19-9",
                englishName: "Carbohydrate Antigen 19-9",
                abbreviation: "CA19-9",
                unit: "U/mL",
                bodyZone: .digestive,
                category: .tumorMarker,
                description: "消化道肿瘤标志物",
                trendPreference: .lowerBetter,
                referenceRangeMax: 37,
                referenceRangeText: "≤37"
            ),
        ]
    }

    // MARK: - 胃功能

    static var gastricTemplates: [IndicatorTemplate] {
        [
            IndicatorTemplate(
                name: "胃蛋白酶原Ⅰ",
                englishName: "Pepsinogen I",
                abbreviation: "PGⅠ",
                unit: "ng/mL",
                bodyZone: .digestive,
                category: .bloodBiochemistry,
                description: "反映胃底腺细胞功能，用于胃癌筛查",
                trendPreference: .higherBetter,
                referenceRangeMin: 70,
                referenceRangeText: "≥70"
            ),
            IndicatorTemplate(
                name: "胃蛋白酶原Ⅱ",
                englishName: "Pepsinogen II",
                abbreviation: "PGⅡ",
                unit: "ng/mL",
                bodyZone: .digestive,
                category: .bloodBiochemistry,
                trendPreference: .rangeOptimal,
                referenceRangeMax: 15,
                referenceRangeText: "≤15"
            ),
        ]
    }

    // MARK: - 甲状腺功能

    static var thyroidTemplates: [IndicatorTemplate] {
        [
            IndicatorTemplate(
                name: "促甲状腺激素",
                englishName: "Thyroid Stimulating Hormone",
                abbreviation: "TSH",
                unit: "mIU/L",
                bodyZone: .thyroid,
                category: .thyroidFunction,
                trendPreference: .rangeOptimal,
                referenceRangeMin: 0.27,
                referenceRangeMax: 4.2,
                referenceRangeText: "0.27-4.2"
            ),
            IndicatorTemplate(
                name: "游离甲状腺素",
                englishName: "Free Thyroxine",
                abbreviation: "FT4",
                unit: "pmol/L",
                bodyZone: .thyroid,
                category: .thyroidFunction,
                trendPreference: .rangeOptimal,
                referenceRangeMin: 12,
                referenceRangeMax: 22,
                referenceRangeText: "12-22"
            ),
            IndicatorTemplate(
                name: "游离三碘甲状腺原氨酸",
                englishName: "Free Triiodothyronine",
                abbreviation: "FT3",
                unit: "pmol/L",
                bodyZone: .thyroid,
                category: .thyroidFunction,
                trendPreference: .rangeOptimal,
                referenceRangeMin: 3.1,
                referenceRangeMax: 6.8,
                referenceRangeText: "3.1-6.8"
            ),
        ]
    }
}

// MARK: - 用户体检记录数据 (2025-04-24)

extension SeedData {

    /// 导入 2025年4月24日 体检数据
    @MainActor
    static func importHealthReport_20250424(modelContext: ModelContext) {
        let testDate = Calendar.current.date(from: DateComponents(year: 2025, month: 4, day: 24)) ?? Date()

        // 创建体检报告
        let report = HealthReport(
            name: "2025年度体检",
            testDate: testDate,
            labName: "上海美阳门诊部"
        )
        modelContext.insert(report)

        // 获取所有模板
        let descriptor = FetchDescriptor<IndicatorTemplate>()
        guard let templates = try? modelContext.fetch(descriptor) else { return }

        // 指标数据映射 (指标名称 -> 数值)
        let recordData: [(name: String, value: Double)] = [
            // 常规检查
            ("收缩压", 121),
            ("舒张压", 72),
            ("体重指数", 20.1),
            ("脉搏", 67),

            // 血常规
            ("白细胞计数", 4.43),
            ("中性粒细胞绝对值", 1.79),
            ("淋巴细胞绝对值", 2.20),

            // 肝功能
            ("谷丙转氨酶", 13.9),
            ("谷草转氨酶", 16.3),
            ("γ-谷氨酰转肽酶", 12.4),
            ("碱性磷酸酶", 43.2),
            ("总胆红素", 8.5),
            ("血清白蛋白", 49.8),

            // 血脂
            ("总胆固醇", 4.50),
            ("甘油三酯", 0.54),
            ("高密度脂蛋白胆固醇", 1.54),
            ("低密度脂蛋白胆固醇", 2.44),

            // 肾功能
            ("血清肌酐", 79.2),
            ("血清尿素", 3.33),

            // 肿瘤标志物
            ("甲胎蛋白", 8.28),
            ("总前列腺特异性抗原", 1.034),

            // 胃功能
            ("胃蛋白酶原Ⅰ", 61.84),
        ]

        // 创建记录
        for (name, value) in recordData {
            if let template = templates.first(where: { $0.name == name }) {
                let record = HealthRecord(
                    value: value,
                    testDate: testDate,
                    source: .manual,
                    labName: "上海美阳门诊部",
                    template: template,
                    report: report
                )
                modelContext.insert(record)
            }
        }

        try? modelContext.save()
    }
}

