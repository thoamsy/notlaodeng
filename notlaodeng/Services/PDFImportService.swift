//
//  PDFImportService.swift
//  notlaodeng
//
//  PDF 导入服务
//

import Foundation
import PDFKit
import UIKit
import Vision

// MARK: - PDF 导入服务

actor PDFImportService {
    static let shared = PDFImportService()

    private init() {}

    /// 从 PDF 提取文本（智能选择方法）
    func extractText(from url: URL) async throws -> String {
        // 1. 尝试直接提取文本（文本型 PDF）
        let directText = extractTextDirectly(from: url)

        // 如果直接提取的文本足够长且有意义，直接返回
        if isValidExtractedText(directText) {
            return directText
        }

        // 2. 文本提取失败或质量差，使用 OCR（扫描型 PDF）
        return try await extractTextWithOCR(from: url)
    }

    // MARK: - 直接提取文本（PDFKit）

    private func extractTextDirectly(from url: URL) -> String {
        guard let document = PDFDocument(url: url) else {
            return ""
        }

        var fullText = ""

        for pageIndex in 0..<document.pageCount {
            if let page = document.page(at: pageIndex),
               let pageText = page.string {
                fullText += pageText + "\n\n"
            }
        }

        return fullText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 检查提取的文本是否有效
    private func isValidExtractedText(_ text: String) -> Bool {
        // 文本长度至少 100 字符
        guard text.count > 100 else { return false }

        // 包含一些常见的体检报告关键词
        let keywords = ["检查", "检验", "结果", "参考", "正常", "mmol", "g/L", "U/L", "血", "尿"]
        let containsKeywords = keywords.contains { text.contains($0) }

        // 包含数字（体检报告必然有数值）
        let containsNumbers = text.range(of: #"\d+\.?\d*"#, options: .regularExpression) != nil

        return containsKeywords && containsNumbers
    }

    // MARK: - OCR 提取文本（Vision）

    private func extractTextWithOCR(from url: URL) async throws -> String {
        guard let document = PDFDocument(url: url) else {
            throw PDFImportError.invalidPDF
        }

        var allText: [String] = []

        for pageIndex in 0..<document.pageCount {
            if let page = document.page(at: pageIndex) {
                let image = renderPageToImage(page)
                if let image {
                    let pageText = try await OCRService.shared.recognizeText(from: image)
                    allText.append(pageText)
                }
            }
        }

        return allText.joined(separator: "\n\n---PAGE BREAK---\n\n")
    }

    /// 将 PDF 页面渲染为 UIImage
    private func renderPageToImage(_ page: PDFPage, scale: CGFloat = 2.0) -> UIImage? {
        let pageRect = page.bounds(for: .mediaBox)
        let size = CGSize(width: pageRect.width * scale, height: pageRect.height * scale)

        let renderer = UIGraphicsImageRenderer(size: size)

        let image = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            context.cgContext.translateBy(x: 0, y: size.height)
            context.cgContext.scaleBy(x: scale, y: -scale)

            page.draw(with: .mediaBox, to: context.cgContext)
        }

        return image
    }
}

// MARK: - PDF 导入错误

enum PDFImportError: LocalizedError {
    case invalidPDF
    case accessDenied
    case extractionFailed

    var errorDescription: String? {
        switch self {
        case .invalidPDF:
            return "Invalid or corrupted PDF file"
        case .accessDenied:
            return "Cannot access the selected file"
        case .extractionFailed:
            return "Failed to extract text from PDF"
        }
    }
}

