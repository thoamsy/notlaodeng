//
//  OCRService.swift
//  notlaodeng
//
//  OCR 文字识别服务
//

import Foundation
import Vision
import UIKit

// MARK: - OCR 服务

actor OCRService {
    static let shared = OCRService()

    private init() {}

    /// 识别图片中的文字
    func recognizeText(from image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else {
            throw OCRError.invalidImage
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: "")
                    return
                }

                let text = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }.joined(separator: "\n")

                continuation.resume(returning: text)
            }

            // 配置识别参数
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en-US"]
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    /// 识别多张图片
    func recognizeText(from images: [UIImage]) async throws -> String {
        var allText: [String] = []

        for image in images {
            let text = try await recognizeText(from: image)
            allText.append(text)
        }

        return allText.joined(separator: "\n\n---PAGE BREAK---\n\n")
    }
}

// MARK: - OCR 错误

enum OCRError: LocalizedError {
    case invalidImage
    case recognitionFailed
    case parsingFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Invalid image format"
        case .recognitionFailed:
            return "Text recognition failed"
        case .parsingFailed(let reason):
            return "Failed to parse health data: \(reason)"
        }
    }
}


