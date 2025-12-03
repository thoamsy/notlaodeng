//
//  HealthReportParser.swift
//  notlaodeng
//
//  体检报告文本解析器
//

import Foundation

// MARK: - 解析结果

struct ParsedIndicator: Identifiable, Equatable {
  let id = UUID()
  var name: String
  var value: Double
  var unit: String
  var referenceRange: String
  var referenceMin: Double?
  var referenceMax: Double?

  // 用于匹配已有模板
  var matchedTemplateId: UUID?

  /// 根据参考范围判断是否异常
  var isAbnormal: Bool {
    // 如果有解析出的参考范围，用它来判断
    if let min = referenceMin, let max = referenceMax {
      return value < min || value > max
    }
    if let min = referenceMin {
      return value < min
    }
    if let max = referenceMax {
      return value > max
    }
    // 没有参考范围，不标记为异常
    return false
  }

  static func == (lhs: ParsedIndicator, rhs: ParsedIndicator) -> Bool {
    lhs.id == rhs.id
  }
}

struct ParsedReport {
  var indicators: [ParsedIndicator]
  var rawText: String
  var parseDate: Date

  var abnormalCount: Int {
    indicators.filter { $0.isAbnormal }.count
  }
}

// MARK: - 解析器

class HealthReportParser {

  // 常见指标名称映射（支持多种写法）
  private static let indicatorAliases: [String: String] = [
    // 血常规
    "白细胞": "白细胞计数",
    "白细胞计数": "白细胞计数",
    "WBC": "白细胞计数",
    "红细胞": "红细胞计数",
    "红细胞计数": "红细胞计数",
    "RBC": "红细胞计数",
    "血红蛋白": "血红蛋白",
    "HGB": "血红蛋白",
    "Hb": "血红蛋白",
    "血小板": "血小板计数",
    "血小板计数": "血小板计数",
    "PLT": "血小板计数",
    "中性粒细胞": "中性粒细胞绝对值",
    "中性粒细胞绝对值": "中性粒细胞绝对值",
    "GRAN#": "中性粒细胞绝对值",
    "淋巴细胞": "淋巴细胞绝对值",
    "淋巴细胞绝对值": "淋巴细胞绝对值",
    "淋巴细胞计数": "淋巴细胞绝对值",
    "LYM#": "淋巴细胞绝对值",
    "单核细胞": "单核细胞绝对值",
    "单核细胞绝对值": "单核细胞绝对值",
    "Mono#": "单核细胞绝对值",
    "嗜酸性粒细胞": "嗜酸性粒细胞绝对值",
    "嗜酸性粒细胞绝对值": "嗜酸性粒细胞绝对值",
    "Eos#": "嗜酸性粒细胞绝对值",

    // 血生化
    "空腹血糖": "空腹血糖",
    "葡萄糖": "空腹血糖",
    "GLU": "空腹血糖",
    "FBG": "空腹血糖",
    "总胆固醇": "总胆固醇",
    "TC": "总胆固醇",
    "CHO": "总胆固醇",
    "甘油三酯": "甘油三酯",
    "TG": "甘油三酯",
    "高密度脂蛋白": "高密度脂蛋白胆固醇",
    "HDL-C": "高密度脂蛋白胆固醇",
    "HDL": "高密度脂蛋白胆固醇",
    "低密度脂蛋白": "低密度脂蛋白胆固醇",
    "LDL-C": "低密度脂蛋白胆固醇",
    "LDL": "低密度脂蛋白胆固醇",
    "尿酸": "尿酸",
    "UA": "尿酸",
    "肌酐": "肌酐",
    "Cr": "肌酐",
    "CREA": "肌酐",
    "尿素氮": "尿素氮",
    "BUN": "尿素氮",
    "谷丙转氨酶": "谷丙转氨酶",
    "ALT": "谷丙转氨酶",
    "谷草转氨酶": "谷草转氨酶",
    "AST": "谷草转氨酶",

    // 血压
    "收缩压": "收缩压",
    "舒张压": "舒张压",
    "高压": "收缩压",
    "低压": "舒张压",

    // 眼压
    "眼压": "眼压",
    "眼压-右眼": "眼压-右眼",
    "眼压-左眼": "眼压-左眼",
    "右眼眼压": "眼压-右眼",
    "左眼眼压": "眼压-左眼",

    // 甲状腺
    "促甲状腺激素": "促甲状腺激素",
    "TSH": "促甲状腺激素",
    "游离T3": "游离三碘甲状腺原氨酸",
    "FT3": "游离三碘甲状腺原氨酸",
    "游离T4": "游离甲状腺素",
    "FT4": "游离甲状腺素",

    // 肿瘤标志物
    "甲胎蛋白": "甲胎蛋白",
    "AFP": "甲胎蛋白",
    "癌胚抗原": "癌胚抗原",
    "CEA": "癌胚抗原",
  ]

  // 应该忽略的行模式
  private static let ignorePatterns: [String] = [
    #"\d{3}\*+\d+"#,  // 手机号模式 176****3916
    #"^\d{4}[-/]\d{1,2}[-/]\d{1,2}"#,  // 日期
    #"^姓名"#,
    #"^性别"#,
    #"^年龄"#,
    #"^科室"#,
    #"^医院"#,
    #"^报告"#,
    #"^检查"#,
    #"^送检"#,
  ]

  /// 解析 OCR 文本
  static func parse(_ text: String) -> ParsedReport {
    var indicators: [ParsedIndicator] = []
    var seenNames: Set<String> = []  // 去重

    let lines = text.components(separatedBy: .newlines)

    for line in lines {
      // 跳过应忽略的行
      if shouldIgnoreLine(line) { continue }

      if var indicator = parseLine(line) {
        // 去重：同名指标只保留第一个
        if !seenNames.contains(indicator.name) {
          seenNames.insert(indicator.name)

          // 解析参考范围
          parseReferenceRange(&indicator)

          indicators.append(indicator)
        }
      }
    }

    return ParsedReport(
      indicators: indicators,
      rawText: text,
      parseDate: Date()
    )
  }

  /// 检查是否应该忽略该行
  private static func shouldIgnoreLine(_ line: String) -> Bool {
    let trimmed = line.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { return true }

    for pattern in ignorePatterns {
      if let regex = try? NSRegularExpression(pattern: pattern, options: []),
        regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) != nil
      {
        return true
      }
    }

    return false
  }

  /// 解析单行文本
  private static func parseLine(_ line: String) -> ParsedIndicator? {
    let trimmed = line.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { return nil }

    // 先尝试已知指标名匹配
    if let indicator = parseKnownIndicator(trimmed) { return indicator }

    // 尝试通用模式
    if let indicator = parseGenericPattern(trimmed) { return indicator }

    return nil
  }

  /// 匹配已知指标名
  private static func parseKnownIndicator(_ line: String) -> ParsedIndicator? {
    // 遍历所有已知指标名，看是否出现在行首
    for (alias, standardName) in indicatorAliases {
      // 检查行是否以这个指标名开头
      if line.hasPrefix(alias) || line.contains(alias) {
        // 尝试从行中提取数值
        if let (value, unit, refRange) = extractValueFromLine(line, afterIndicator: alias) {
          return ParsedIndicator(
            name: standardName,
            value: value,
            unit: unit,
            referenceRange: refRange
          )
        }
      }
    }
    return nil
  }

  /// 从行中提取数值（在指标名之后）
  private static func extractValueFromLine(_ line: String, afterIndicator indicator: String) -> (
    Double, String, String
  )? {
    // 找到指标名后的部分
    guard let range = line.range(of: indicator) else { return nil }
    let remaining = String(line[range.upperBound...]).trimmingCharacters(in: .whitespaces)

    // 提取第一个数值
    let valuePattern = #"^[^\d]*?(\d+\.?\d*)"#
    guard let valueRegex = try? NSRegularExpression(pattern: valuePattern, options: []),
      let valueMatch = valueRegex.firstMatch(
        in: remaining, range: NSRange(remaining.startIndex..., in: remaining)),
      let valueRange = Range(valueMatch.range(at: 1), in: remaining),
      let value = Double(remaining[valueRange])
    else {
      return nil
    }

    // 提取单位（数值后的字母）
    let afterValue = String(remaining[valueRange.upperBound...]).trimmingCharacters(
      in: .whitespaces)
    let unitPattern = #"^([a-zA-Z/%μ\*\^\d]+(?:/[a-zA-Z\d]+)?)"#
    var unit = ""
    if let unitRegex = try? NSRegularExpression(pattern: unitPattern, options: []),
      let unitMatch = unitRegex.firstMatch(
        in: afterValue, range: NSRange(afterValue.startIndex..., in: afterValue)),
      let unitRange = Range(unitMatch.range(at: 1), in: afterValue)
    {
      unit = String(afterValue[unitRange])
    }

    // 提取参考范围（数字-数字 或 数字~数字）
    let refPattern = #"(\d+\.?\d*)\s*[-~]\s*(\d+\.?\d*)"#
    var refRange = ""
    if let refRegex = try? NSRegularExpression(pattern: refPattern, options: []),
      let refMatch = refRegex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
      let fullRange = Range(refMatch.range, in: line)
    {
      refRange = String(line[fullRange])
    }

    return (value, unit, refRange)
  }

  /// 通用解析模式
  private static func parseGenericPattern(_ line: String) -> ParsedIndicator? {
    // 模式: 中文名 英文缩写 数值 单位 参考范围
    // 例如: 白细胞计数 WBC 5.00 10^9/L 4-10
    let pattern =
      #"^([\u4e00-\u9fa5]+(?:[-][\u4e00-\u9fa5]+)?)\s*([A-Za-z#]+)?\s*(\d+\.?\d*)\s*([a-zA-Z/%μ\*\^\d]+(?:/[a-zA-Z\d]+)?)?\s*([\d\.\-\~]+)?"#

    guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
      let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line))
    else {
      return nil
    }

    // 中文名
    guard let nameRange = Range(match.range(at: 1), in: line) else { return nil }
    var name = String(line[nameRange]).trimmingCharacters(in: .whitespaces)

    // 英文缩写（可选）
    if match.range(at: 2).location != NSNotFound,
      let abbrRange = Range(match.range(at: 2), in: line)
    {
      let abbr = String(line[abbrRange])
      // 如果缩写是已知的，用它来匹配标准名
      if let standardName = indicatorAliases[abbr] {
        name = standardName
      }
    }

    // 数值
    guard match.range(at: 3).location != NSNotFound,
      let valueRange = Range(match.range(at: 3), in: line),
      let value = Double(line[valueRange])
    else {
      return nil
    }

    // 单位（可选）
    var unit = ""
    if match.range(at: 4).location != NSNotFound,
      let unitRange = Range(match.range(at: 4), in: line)
    {
      unit = String(line[unitRange])
    }

    // 参考范围（可选）
    var refRange = ""
    if match.range(at: 5).location != NSNotFound,
      let refRangeRange = Range(match.range(at: 5), in: line)
    {
      refRange = String(line[refRangeRange])
    }

    // 用标准名替换
    let standardName = indicatorAliases[name] ?? name

    return ParsedIndicator(
      name: standardName,
      value: value,
      unit: unit,
      referenceRange: refRange
    )
  }

  /// 解析参考范围为数值
  private static func parseReferenceRange(_ indicator: inout ParsedIndicator) {
    let ref = indicator.referenceRange
    guard !ref.isEmpty else { return }

    // 模式1: min-max 或 min~max
    let rangePattern = #"(\d+\.?\d*)\s*[-~]\s*(\d+\.?\d*)"#
    if let regex = try? NSRegularExpression(pattern: rangePattern, options: []),
      let match = regex.firstMatch(in: ref, range: NSRange(ref.startIndex..., in: ref))
    {
      if let minRange = Range(match.range(at: 1), in: ref),
        let maxRange = Range(match.range(at: 2), in: ref)
      {
        indicator.referenceMin = Double(ref[minRange])
        indicator.referenceMax = Double(ref[maxRange])
        return
      }
    }

    // 模式2: <max
    let lessThanPattern = #"<\s*(\d+\.?\d*)"#
    if let regex = try? NSRegularExpression(pattern: lessThanPattern, options: []),
      let match = regex.firstMatch(in: ref, range: NSRange(ref.startIndex..., in: ref)),
      let maxRange = Range(match.range(at: 1), in: ref)
    {
      indicator.referenceMax = Double(ref[maxRange])
      return
    }

    // 模式3: >min
    let greaterThanPattern = #">\s*(\d+\.?\d*)"#
    if let regex = try? NSRegularExpression(pattern: greaterThanPattern, options: []),
      let match = regex.firstMatch(in: ref, range: NSRange(ref.startIndex..., in: ref)),
      let minRange = Range(match.range(at: 1), in: ref)
    {
      indicator.referenceMin = Double(ref[minRange])
      return
    }
  }
}
