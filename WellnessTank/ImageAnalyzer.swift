//
//  ImageAnalyzer.swift
//  WellnessTank
//
//  Created by Zhuoming Li on 11/15/25.
//

import UIKit
import Vision
import CoreML
import AVFoundation

struct AnalysisResult {
    let description: String
    let category: WellnessCategory
    let confidence: Float
}

class ImageAnalyzer {
    static let shared = ImageAnalyzer()
    
    private init() {}
    
    // Analyze video by extracting and analyzing a frame
    func analyzeVideo(_ videoURL: URL, completion: @escaping (AnalysisResult) -> Void) {
        Task {
            if let thumbnail = await extractVideoFrame(from: videoURL) {
                analyzeImage(thumbnail, completion: completion)
            } else {
                completion(AnalysisResult(description: "Unable to analyze video", category: .food, confidence: 0))
            }
        }
    }
    
    func analyzeVideoDetailed(_ videoURL: URL, completion: @escaping ([String]) -> Void) {
        Task {
            if let thumbnail = await extractVideoFrame(from: videoURL) {
                analyzeImageDetailed(thumbnail, completion: completion)
            } else {
                completion(["Unable to analyze video"])
            }
        }
    }
    
    private func extractVideoFrame(from url: URL) async -> UIImage? {
        let asset = AVAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        
        let time = CMTime(seconds: 1, preferredTimescale: 60)
        
        do {
            let cgImage = try await imageGenerator.image(at: time).image
            return UIImage(cgImage: cgImage)
        } catch {
            print("Error extracting video frame: \(error)")
            return nil
        }
    }
    
    func analyzeImage(_ image: UIImage, completion: @escaping (AnalysisResult) -> Void) {
        guard let ciImage = CIImage(image: image) else {
            completion(AnalysisResult(description: "Unable to analyze image", category: .food, confidence: 0))
            return
        }
        
        // Create a request handler
        let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
        
        // Create the Vision request
        let request = VNClassifyImageRequest { request, error in
            guard let results = request.results as? [VNClassificationObservation],
                  let topResult = results.first else {
                DispatchQueue.main.async {
                    completion(AnalysisResult(description: "Unable to identify activity", category: .food, confidence: 0))
                }
                return
            }
            
            // Classify into wellness category
            let category = self.classifyToWellnessCategory(results: results)
            
            // Create a natural description
            let mainActivity = topResult.identifier
            let naturalDescription = self.createNaturalDescription(from: mainActivity, confidence: topResult.confidence, category: category)
            
            DispatchQueue.main.async {
                completion(AnalysisResult(description: naturalDescription, category: category, confidence: topResult.confidence))
            }
        }
        
        // Perform the request
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                DispatchQueue.main.async {
                    completion(AnalysisResult(description: "Error analyzing image", category: .food, confidence: 0))
                }
            }
        }
    }
    
    private func classifyToWellnessCategory(results: [VNClassificationObservation]) -> WellnessCategory {
        // Get all significant results
        let significantResults = results.filter { $0.confidence >= 0.05 }
        
        var workoutScore: Float = 0
        var foodScore: Float = 0
        var supplementScore: Float = 0
        
        for result in significantResults {
            let identifier = result.identifier.lowercased()
            let confidence = result.confidence
            
            // Workout keywords
            if identifier.contains("exercise") || identifier.contains("workout") || 
               identifier.contains("gym") || identifier.contains("running") ||
               identifier.contains("yoga") || identifier.contains("fitness") ||
               identifier.contains("sport") || identifier.contains("training") ||
               identifier.contains("dumbbell") || identifier.contains("barbell") ||
               identifier.contains("treadmill") || identifier.contains("bicycle") ||
               identifier.contains("swimming") || identifier.contains("athlete") ||
               identifier.contains("jogging") || identifier.contains("weightlifting") {
                workoutScore += confidence
            }
            
            // Food keywords
            if identifier.contains("food") || identifier.contains("meal") ||
               identifier.contains("dish") || identifier.contains("plate") ||
               identifier.contains("pizza") || identifier.contains("burger") ||
               identifier.contains("salad") || identifier.contains("fruit") ||
               identifier.contains("vegetable") || identifier.contains("meat") ||
               identifier.contains("breakfast") || identifier.contains("lunch") ||
               identifier.contains("dinner") || identifier.contains("snack") ||
               identifier.contains("beverage") || identifier.contains("drink") ||
               identifier.contains("sandwich") || identifier.contains("rice") ||
               identifier.contains("pasta") || identifier.contains("bread") ||
               identifier.contains("dessert") || identifier.contains("soup") {
                foodScore += confidence
            }
            
            // Supplement keywords
            if identifier.contains("pill") || identifier.contains("tablet") ||
               identifier.contains("capsule") || identifier.contains("medicine") ||
               identifier.contains("supplement") || identifier.contains("vitamin") ||
               identifier.contains("bottle") || identifier.contains("container") ||
               identifier.contains("pharmacy") || identifier.contains("medication") {
                supplementScore += confidence
            }
        }
        
        // Determine the category with highest score
        if supplementScore > foodScore && supplementScore > workoutScore && supplementScore > 0 {
            return .supplements
        } else if workoutScore > foodScore && workoutScore > 0 {
            return .workout
        } else {
            return .food // Default to food
        }
    }
    
    private func createNaturalDescription(from identifier: String, confidence: Float, category: WellnessCategory) -> String {
        // Clean up the identifier (Vision returns comma-separated terms)
        let terms = identifier.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        let mainTerm = terms.first ?? identifier
        
        // Return description without confidence percentage
        return mainTerm.capitalized
    }
    
    
    // Get multiple predictions for more detailed analysis
    func analyzeImageDetailed(_ image: UIImage, completion: @escaping ([String]) -> Void) {
        guard let ciImage = CIImage(image: image) else {
            completion(["Unable to analyze image"])
            return
        }
        
        let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
        
        let request = VNClassifyImageRequest { request, error in
            guard let results = request.results as? [VNClassificationObservation] else {
                DispatchQueue.main.async {
                    completion(["Unable to identify activity"])
                }
                return
            }
            
            // Get top 5 results with at least 10% confidence
            let significantResults = results
                .filter { $0.confidence >= 0.1 }
                .prefix(5)
                .map { observation -> String in
                    let confidence = Int(observation.confidence * 100)
                    return "\(observation.identifier) (\(confidence)%)"
                }
            
            DispatchQueue.main.async {
                completion(Array(significantResults))
            }
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                DispatchQueue.main.async {
                    completion(["Error analyzing image"])
                }
            }
        }
    }
}

