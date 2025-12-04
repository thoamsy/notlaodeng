//
//  IndicatorClassifier.swift
//  notlaodeng
//
//  指标分类器 - 根据指标名称推断 BodyZone 和 Category
//  未来可扩展为 LLM 分类
//

import Foundation

// MARK: - 分类结果

struct IndicatorClassification {
    let bodyZone: BodyZone
    let category: IndicatorCategory
    let confidence: ClassificationConfidence

    enum ClassificationConfidence {
        case high  // 精确匹配预定义模板
        case medium  // 关键词匹配
        case low  // 默认值（未能匹配）
    }
}

// MARK: - 分类器协议（为 LLM 扩展预留）

protocol IndicatorClassifying {
    func classify(name: String, unit: String) -> IndicatorClassification
}

// MARK: - 关键词分类器

class KeywordIndicatorClassifier: IndicatorClassifying {
    static let shared = KeywordIndicatorClassifier()

    private init() {}

    func classify(name: String, unit: String) -> IndicatorClassification {
        let bodyZone = inferBodyZone(from: name, unit: unit)
        let category = inferCategory(from: name, unit: unit)

        let confidence: IndicatorClassification.ClassificationConfidence =
            (bodyZone != .fullBody || category != .other) ? .medium : .low

        return IndicatorClassification(
            bodyZone: bodyZone,
            category: category,
            confidence: confidence
        )
    }

    // MARK: - Body Zone 推断

    private func inferBodyZone(from name: String, unit: String) -> BodyZone {
        let text = name.lowercased()

        // 血液相关
        if matchesAny(
            text,
            keywords: [
                "血细胞", "红细胞", "白细胞", "血小板", "血红蛋白",
                "淋巴", "粒细胞", "单核", "嗜酸", "嗜碱",
                "网织红", "血沉", "凝血", "纤维蛋白",
            ])
        {
            return .blood
        }

        // 肝脏相关
        if matchesAny(
            text,
            keywords: [
                "肝", "转氨酶", "alt", "ast", "ggt", "胆红素",
                "白蛋白", "球蛋白", "碱性磷酸酶", "alp",
                "谷丙", "谷草", "胆汁酸",
            ])
        {
            return .liver
        }

        // 肾脏相关
        if matchesAny(
            text,
            keywords: [
                "肾", "肌酐", "尿素", "尿酸", "bun", "crea",
                "胱抑素", "肾小球",
            ])
        {
            return .kidney
        }

        // 心血管相关
        if matchesAny(
            text,
            keywords: [
                "心", "血压", "收缩压", "舒张压", "脉搏",
                "心率", "心电", "心肌", "肌钙蛋白", "bnp",
                "同型半胱氨酸",
            ])
        {
            return .heart
        }

        // 甲状腺相关
        if matchesAny(
            text,
            keywords: [
                "甲状腺", "tsh", "t3", "t4", "ft3", "ft4",
                "甲功", "抗甲状腺",
            ])
        {
            return .thyroid
        }

        // 血脂（归入心血管）
        if matchesAny(
            text,
            keywords: [
                "胆固醇", "甘油三酯", "脂蛋白", "hdl", "ldl",
                "载脂蛋白", "血脂",
            ])
        {
            return .heart
        }

        // 血糖（归入全身代谢）
        if matchesAny(
            text,
            keywords: [
                "血糖", "葡萄糖", "糖化", "胰岛素", "c肽",
                "glu", "hba1c",
            ])
        {
            return .fullBody
        }

        // 消化系统
        if matchesAny(
            text,
            keywords: [
                "胃", "消化", "淀粉酶", "脂肪酶", "幽门",
                "胃蛋白酶", "胃泌素",
            ])
        {
            return .digestive
        }

        // 泌尿系统
        if matchesAny(
            text,
            keywords: [
                "尿常规", "尿蛋白", "尿糖", "尿隐血", "尿胆",
                "尿比重", "尿ph", "尿白细胞",
            ])
        {
            return .urinary
        }

        // 眼科
        if matchesAny(text, keywords: ["眼", "视力", "眼压", "裸眼", "矫正视力"]) {
            return .eye
        }

        // 耳鼻喉
        if matchesAny(text, keywords: ["听力", "耳", "鼻", "咽"]) {
            return .ear
        }

        // 口腔
        if matchesAny(text, keywords: ["口腔", "牙", "龋"]) {
            return .oral
        }

        // 肺部
        if matchesAny(text, keywords: ["肺", "肺活量", "呼吸", "fvc", "fev"]) {
            return .lung
        }

        // 骨骼
        if matchesAny(text, keywords: ["骨", "骨密度", "钙", "磷", "维生素d", "碱性磷酸酶"]) {
            return .bone
        }

        // 肿瘤标志物（归入相关器官）
        if matchesAny(text, keywords: ["afp", "甲胎蛋白"]) {
            return .liver
        }
        if matchesAny(text, keywords: ["psa", "前列腺"]) {
            return .reproductive
        }
        if matchesAny(text, keywords: ["cea", "癌胚抗原", "ca", "肿瘤标志"]) {
            return .fullBody
        }

        // 生殖系统
        if matchesAny(
            text,
            keywords: [
                "睾酮", "雌激素", "孕酮", "卵泡", "黄体",
                "精液", "前列腺",
            ])
        {
            return .reproductive
        }

        // 常规检查
        if matchesAny(text, keywords: ["身高", "体重", "bmi", "体重指数", "腰围"]) {
            return .fullBody
        }

        return .fullBody
    }

    // MARK: - Category 推断

    private func inferCategory(from name: String, unit: String) -> IndicatorCategory {
        let text = name.lowercased()

        // 血常规
        if matchesAny(
            text,
            keywords: [
                "血细胞", "红细胞", "白细胞", "血小板", "血红蛋白",
                "淋巴", "粒细胞", "单核", "嗜酸", "嗜碱",
                "网织红", "血沉", "rbc", "wbc", "hgb", "plt",
            ])
        {
            return .bloodRoutine
        }

        // 尿常规
        if matchesAny(
            text,
            keywords: [
                "尿常规", "尿蛋白", "尿糖", "尿隐血", "尿胆",
                "尿比重", "尿ph", "尿白细胞", "尿红细胞",
            ])
        {
            return .urineRoutine
        }

        // 肝功能
        if matchesAny(
            text,
            keywords: [
                "转氨酶", "alt", "ast", "ggt", "胆红素",
                "白蛋白", "球蛋白", "碱性磷酸酶", "alp",
                "谷丙", "谷草", "胆汁酸", "肝功",
            ])
        {
            return .bloodBiochemistry
        }

        // 肾功能
        if matchesAny(text, keywords: ["肌酐", "尿素", "尿酸", "bun", "肾功"]) {
            return .bloodBiochemistry
        }

        // 血脂
        if matchesAny(text, keywords: ["胆固醇", "甘油三酯", "脂蛋白", "hdl", "ldl", "血脂"]) {
            return .bloodBiochemistry
        }

        // 甲状腺
        if matchesAny(text, keywords: ["甲状腺", "tsh", "t3", "t4", "ft3", "ft4", "甲功"]) {
            return .thyroidFunction
        }

        // 肿瘤标志物
        if matchesAny(
            text,
            keywords: [
                "afp", "甲胎蛋白", "cea", "癌胚抗原", "ca",
                "psa", "前列腺特异", "肿瘤标志",
            ])
        {
            return .tumorMarker
        }

        // 常规检查
        if matchesAny(text, keywords: ["身高", "体重", "bmi", "血压", "脉搏", "心率"]) {
            return .routine
        }

        // 视力
        if matchesAny(text, keywords: ["视力", "眼压"]) {
            return .vision
        }

        // 听力
        if matchesAny(text, keywords: ["听力"]) {
            return .hearing
        }

        // 心电图
        if matchesAny(text, keywords: ["心电", "ecg"]) {
            return .electrocardiogram
        }

        return .other
    }

    // MARK: - Helper

    private func matchesAny(_ text: String, keywords: [String]) -> Bool {
        keywords.contains { text.contains($0.lowercased()) }
    }
}

// MARK: - 未来 LLM 分类器（占位）

/*
class LLMIndicatorClassifier: IndicatorClassifying {
    func classify(name: String, unit: String) async -> IndicatorClassification {
        // TODO: 调用 LLM API 进行分类
        // 可以结合 KeywordIndicatorClassifier 作为 fallback
    }
}
*/
