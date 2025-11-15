//
//  VideoGenerator.swift
//  WellnessTank
//
//  Created by Zhuoming Li on 11/15/25.
//

import SwiftUI
import AVFoundation
import Photos
import Combine

@MainActor
class VideoGenerator: ObservableObject {
    @Published var isGenerating = false
    @Published var generationProgress: Double = 0.0
    @Published var generatedVideoURL: URL?
    @Published var error: String?
    
    func generateDayVideo(entries: [LogEntry], dateTitle: String, completion: @escaping (URL?) -> Void) {
        isGenerating = true
        generationProgress = 0.0
        error = nil
        
        Task {
            do {
                let videoURL = try await createVideoComposition(entries: entries, dateTitle: dateTitle)
                self.generatedVideoURL = videoURL
                self.isGenerating = false
                self.generationProgress = 1.0
                completion(videoURL)
            } catch {
                self.error = error.localizedDescription
                self.isGenerating = false
                completion(nil)
            }
        }
    }
    
    private func createVideoComposition(entries: [LogEntry], dateTitle: String) async throws -> URL {
        let composition = AVMutableComposition()
        
        // Video settings - Portrait orientation for phone
        let videoSize = CGSize(width: 1080, height: 1920) // 9:16 aspect ratio (portrait)
        let frameDuration = CMTime(seconds: 2.0, preferredTimescale: 600) // 2 seconds per item
        var currentTime = CMTime.zero
        
        // Create video track
        guard let videoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw NSError(domain: "VideoGenerator", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create video track"])
        }
        
        var layerInstructions: [AVMutableVideoCompositionLayerInstruction] = []
        
        // Add each entry as a frame
        for (index, entry) in entries.enumerated() {
            self.generationProgress = Double(index) / Double(entries.count) * 0.8
            
            if entry.mediaType == .photo, let image = entry.image {
                // Convert image to video clip
                let imageVideoURL = try await createVideoFromImage(
                    image: image,
                    duration: frameDuration,
                    videoSize: videoSize
                )
                
                let asset = AVAsset(url: imageVideoURL)
                guard let assetTrack = try await asset.loadTracks(withMediaType: .video).first else {
                    try? FileManager.default.removeItem(at: imageVideoURL)
                    continue
                }
                
                let timeRange = CMTimeRange(start: .zero, duration: frameDuration)
                try videoTrack.insertTimeRange(timeRange, of: assetTrack, at: currentTime)
                
                // Create layer instruction for this specific segment
                let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
                
                // Calculate transform to fill screen (aspect fill)
                let size = try await assetTrack.load(.naturalSize)
                let transform = calculateFillTransform(sourceSize: size, targetSize: videoSize)
                layerInstruction.setTransform(transform, at: currentTime)
                
                layerInstructions.append(layerInstruction)
                
                try? FileManager.default.removeItem(at: imageVideoURL)
                
            } else if entry.mediaType == .video, let mediaData = entry.mediaData {
                // Add video clip
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mp4")
                try mediaData.write(to: tempURL)
                
                let asset = AVAsset(url: tempURL)
                guard let assetTrack = try await asset.loadTracks(withMediaType: .video).first else {
                    try? FileManager.default.removeItem(at: tempURL)
                    continue
                }
                
                // Get video properties
                let size = try await assetTrack.load(.naturalSize)
                let preferredTransform = try await assetTrack.load(.preferredTransform)
                
                let sourceDuration = try await asset.load(.duration)
                let duration = min(frameDuration, sourceDuration)
                let timeRange = CMTimeRange(start: .zero, duration: duration)
                
                try videoTrack.insertTimeRange(timeRange, of: assetTrack, at: currentTime)
                
                // Create layer instruction for this specific segment
                let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
                
                // Calculate transform to fill screen (aspect fill)
                let transform = calculateFillTransform(
                    sourceSize: size,
                    targetSize: videoSize,
                    preferredTransform: preferredTransform
                )
                layerInstruction.setTransform(transform, at: currentTime)
                
                layerInstructions.append(layerInstruction)
                
                try? FileManager.default.removeItem(at: tempURL)
            }
            
            currentTime = CMTimeAdd(currentTime, frameDuration)
        }
        
        // Create video composition with instructions
        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = videoSize
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
        
        // Create one instruction covering the entire timeline
        let mainInstruction = AVMutableVideoCompositionInstruction()
        mainInstruction.timeRange = CMTimeRange(start: .zero, duration: currentTime)
        mainInstruction.layerInstructions = [layerInstructions.first].compactMap { $0 } // Use first layer instruction as base
        
        videoComposition.instructions = [mainInstruction]
        
        // Export the video
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mp4")
        
        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            throw NSError(domain: "VideoGenerator", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create export session"])
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.videoComposition = videoComposition
        
        await exportSession.export()
        
        self.generationProgress = 1.0
        
        if exportSession.status == .completed {
            return outputURL
        } else {
            throw NSError(domain: "VideoGenerator", code: 3, userInfo: [NSLocalizedDescriptionKey: "Export failed"])
        }
    }
    
    private func createVideoFromImage(image: UIImage, duration: CMTime, videoSize: CGSize) async throws -> URL {
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mp4")
        
        guard let videoWriter = try? AVAssetWriter(url: outputURL, fileType: .mp4) else {
            throw NSError(domain: "VideoGenerator", code: 4, userInfo: [NSLocalizedDescriptionKey: "Failed to create video writer"])
        }
        
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: videoSize.width,
            AVVideoHeightKey: videoSize.height
        ]
        
        let videoWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoWriterInput.expectsMediaDataInRealTime = false
        
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoWriterInput,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
                kCVPixelBufferWidthKey as String: videoSize.width,
                kCVPixelBufferHeightKey as String: videoSize.height
            ]
        )
        
        videoWriter.add(videoWriterInput)
        videoWriter.startWriting()
        videoWriter.startSession(atSourceTime: .zero)
        
        // Create pixel buffer from image (aspect fill - no black bars)
        if let pixelBuffer = createPixelBuffer(from: image, size: videoSize, aspectFill: true) {
            adaptor.append(pixelBuffer, withPresentationTime: .zero)
        }
        
        videoWriterInput.markAsFinished()
        await videoWriter.finishWriting()
        
        return outputURL
    }
    
    private func calculateFillTransform(sourceSize: CGSize, targetSize: CGSize, preferredTransform: CGAffineTransform = .identity) -> CGAffineTransform {
        // Determine actual source size considering rotation
        var actualSize = sourceSize
        let isRotated = abs(preferredTransform.b) == 1.0 || abs(preferredTransform.c) == 1.0
        if isRotated {
            actualSize = CGSize(width: sourceSize.height, height: sourceSize.width)
        }
        
        // Calculate scale to fill (not fit) - this ensures no black bars
        let scaleX = targetSize.width / actualSize.width
        let scaleY = targetSize.height / actualSize.height
        let scale = max(scaleX, scaleY) // Use max instead of min to fill
        
        // Calculate position to center the scaled content
        let scaledWidth = actualSize.width * scale
        let scaledHeight = actualSize.height * scale
        let tx = (targetSize.width - scaledWidth) / 2
        let ty = (targetSize.height - scaledHeight) / 2
        
        // Combine transforms
        var transform = preferredTransform
        transform = transform.scaledBy(x: scale, y: scale)
        
        if isRotated {
            // Adjust translation for rotated videos
            if preferredTransform.b > 0 { // 90 degrees
                transform = transform.translatedBy(x: 0, y: ty / scale)
            } else if preferredTransform.b < 0 { // -90 degrees
                transform = transform.translatedBy(x: ty / scale, y: 0)
            }
        } else {
            transform = transform.translatedBy(x: tx / scale, y: ty / scale)
        }
        
        return transform
    }
    
    private func createPixelBuffer(from image: UIImage, size: CGSize, aspectFill: Bool = true) -> CVPixelBuffer? {
        let attrs = [
            kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue!,
            kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue!,
            kCVPixelBufferWidthKey: size.width,
            kCVPixelBufferHeightKey: size.height
        ] as CFDictionary
        
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(size.width),
            Int(size.height),
            kCVPixelFormatType_32ARGB,
            attrs,
            &pixelBuffer
        )
        
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            return nil
        }
        
        CVPixelBufferLockBaseAddress(buffer, [])
        let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        )
        
        if let context = context, let cgImage = image.cgImage {
            let imageSize = image.size
            
            if aspectFill {
                // Aspect Fill - scales to fill the entire frame (may crop)
                let scaleX = size.width / imageSize.width
                let scaleY = size.height / imageSize.height
                let scale = max(scaleX, scaleY) // Use max to fill
                
                let scaledWidth = imageSize.width * scale
                let scaledHeight = imageSize.height * scale
                let x = (size.width - scaledWidth) / 2
                let y = (size.height - scaledHeight) / 2
                
                // Draw image (no black background, image fills screen)
                context.draw(cgImage, in: CGRect(x: x, y: y, width: scaledWidth, height: scaledHeight))
            } else {
                // Aspect Fit - scales to fit within frame (may have black bars)
                let scaleX = size.width / imageSize.width
                let scaleY = size.height / imageSize.height
                let scale = min(scaleX, scaleY)
                
                let scaledWidth = imageSize.width * scale
                let scaledHeight = imageSize.height * scale
                let x = (size.width - scaledWidth) / 2
                let y = (size.height - scaledHeight) / 2
                
                // Fill background
                context.setFillColor(UIColor.black.cgColor)
                context.fill(CGRect(origin: .zero, size: size))
                
                // Draw image
                context.draw(cgImage, in: CGRect(x: x, y: y, width: scaledWidth, height: scaledHeight))
            }
        }
        
        CVPixelBufferUnlockBaseAddress(buffer, [])
        return buffer
    }
    
    private func addImageToComposition(image: UIImage, to track: AVMutableCompositionTrack, at time: CMTime, duration: CMTime) async throws {
        // This is now handled by createVideoFromImage
    }
    
    private func addVideoToComposition(videoURL: URL, to track: AVMutableCompositionTrack, at time: CMTime, maxDuration: CMTime) async throws {
        // This is now handled in the main composition method
    }
    
    func saveToPhotos(videoURL: URL, completion: @escaping (Bool, Error?) -> Void) {
        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized else {
                completion(false, NSError(domain: "VideoGenerator", code: 4, userInfo: [NSLocalizedDescriptionKey: "Photo library access denied"]))
                return
            }
            
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: videoURL)
            }) { success, error in
                DispatchQueue.main.async {
                    completion(success, error)
                }
            }
        }
    }
}

