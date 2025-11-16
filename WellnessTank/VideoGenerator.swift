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

    // Portrait 9:16
    let videoSize = CGSize(width: 1080, height: 1920)
    let imageDuration = CMTime(seconds: 2.0, preferredTimescale: 600)    // 2s per image
    let maxVideoDuration = CMTime(seconds: 5.0, preferredTimescale: 600) // max 5s per video
    var currentTime = CMTime.zero

    // Single video track
    guard let videoTrack = composition.addMutableTrack(
        withMediaType: .video,
        preferredTrackID: kCMPersistentTrackID_Invalid
    ) else {
        throw NSError(domain: "VideoGenerator",
                      code: 1,
                      userInfo: [NSLocalizedDescriptionKey: "Failed to create video track"])
    }

    // Single layer instruction for the whole track
    let trackInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)

    for (index, entry) in entries.enumerated() {
        generationProgress = Double(index) / Double(max(entries.count, 1)) * 0.8

        if entry.mediaType == .photo, let image = entry.image {
            // Normalize image -> 1080x1920 portrait clip
            let imageURL = try await createVideoFromImage(
                image: image,
                duration: imageDuration,
                videoSize: videoSize
            )

            let asset = AVAsset(url: imageURL)
            guard let assetTrack = try await asset.loadTracks(withMediaType: .video).first else {
                try? FileManager.default.removeItem(at: imageURL)
                continue
            }

            let timeRange = CMTimeRange(start: .zero, duration: imageDuration)
            try videoTrack.insertTimeRange(timeRange, of: assetTrack, at: currentTime)

            // Pre-rendered as 1080x1920, so identity transform is enough
            trackInstruction.setTransform(.identity, at: currentTime)

            currentTime = currentTime + imageDuration
            try? FileManager.default.removeItem(at: imageURL)

        } else if entry.mediaType == .video, let mediaData = entry.mediaData {
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString + ".mp4")
            try mediaData.write(to: tempURL)

            let asset = AVAsset(url: tempURL)
            guard let assetTrack = try await asset.loadTracks(withMediaType: .video).first else {
                try? FileManager.default.removeItem(at: tempURL)
                continue
            }

            let naturalSize = try await assetTrack.load(.naturalSize)
            let preferredTransform = try await assetTrack.load(.preferredTransform)
            let sourceDuration = try await asset.load(.duration)

            // Max 5 seconds per video; speed up if longer
            let targetDuration = min(maxVideoDuration, sourceDuration)
            let fullRange = CMTimeRange(start: .zero, duration: sourceDuration)

            try videoTrack.insertTimeRange(fullRange, of: assetTrack, at: currentTime)

            // Full-screen portrait, one transform per segment start
            let transform = calculateFillTransform(
                sourceSize: naturalSize,
                targetSize: videoSize,
                preferredTransform: preferredTransform
            )
            trackInstruction.setTransform(transform, at: currentTime)

            if sourceDuration > maxVideoDuration {
                // Compress time so the clip fits into 5 seconds
                videoTrack.scaleTimeRange(
                    CMTimeRange(start: currentTime, duration: sourceDuration),
                    toDuration: targetDuration
                )
            }

            currentTime = currentTime + targetDuration
            try? FileManager.default.removeItem(at: tempURL)
        }
    }

    // Video composition
    let videoComposition = AVMutableVideoComposition()
    videoComposition.renderSize = videoSize
    videoComposition.frameDuration = CMTime(value: 1, timescale: 30)

    // One instruction for the whole track
    let mainInstruction = AVMutableVideoCompositionInstruction()
    mainInstruction.timeRange = CMTimeRange(start: .zero, duration: currentTime)
    mainInstruction.layerInstructions = [trackInstruction]
    videoComposition.instructions = [mainInstruction]

    // Title overlay + simple transitions (your existing helper)
    videoComposition.animationTool = createAnimationTool(
        dateTitle: dateTitle,
        videoSize: videoSize,
        duration: currentTime,
        entryCount: entries.count,
        imageDuration: imageDuration,
        maxVideoDuration: maxVideoDuration
    )

    // Export
    let outputURL = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString + ".mp4")

    guard let exportSession = AVAssetExportSession(
        asset: composition,
        presetName: AVAssetExportPresetHighestQuality
    ) else {
        throw NSError(domain: "VideoGenerator",
                      code: 2,
                      userInfo: [NSLocalizedDescriptionKey: "Failed to create export session"])
    }

    exportSession.outputURL = outputURL
    exportSession.outputFileType = .mp4
    exportSession.videoComposition = videoComposition

    await exportSession.export()

    generationProgress = 1.0

    guard exportSession.status == .completed else {
        throw NSError(domain: "VideoGenerator",
                      code: 3,
                      userInfo: [NSLocalizedDescriptionKey: "Export failed: \(exportSession.error?.localizedDescription ?? "Unknown")"])
    }

    return outputURL
}
    
private func createVideoFromImage(image: UIImage, duration: CMTime, videoSize: CGSize) async throws -> URL {
    let outputURL = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString + ".mp4")

    guard let videoWriter = try? AVAssetWriter(url: outputURL, fileType: .mp4) else {
        throw NSError(
            domain: "VideoGenerator",
            code: 4,
            userInfo: [NSLocalizedDescriptionKey: "Failed to create video writer"]
        )
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

    // One pixel buffer we’ll reuse for all frames (aspect-fill, no black bars)
    guard let pixelBuffer = createPixelBuffer(from: image, size: videoSize, aspectFill: true) else {
        throw NSError(
            domain: "VideoGenerator",
            code: 5,
            userInfo: [NSLocalizedDescriptionKey: "Failed to create pixel buffer from image"]
        )
    }

    let frameDuration = CMTime(value: 1, timescale: 30) // 30 FPS
    let totalFrames = max(1, Int(CMTimeGetSeconds(duration) * 30))

    var frameIndex = 0
    while frameIndex < totalFrames {
        let presentationTime = CMTimeMultiply(frameDuration, multiplier: Int32(frameIndex))

        // Wait until the writer is ready
        while !videoWriterInput.isReadyForMoreMediaData {
            try await Task.sleep(nanoseconds: 1_000_000) // 1 ms
        }

        adaptor.append(pixelBuffer, withPresentationTime: presentationTime)
        frameIndex += 1
    }

    videoWriterInput.markAsFinished()
    await videoWriter.finishWriting()

    return outputURL
}
    
    private func calculateFillTransform(sourceSize: CGSize, targetSize: CGSize, preferredTransform: CGAffineTransform = .identity) -> CGAffineTransform {
        // Get the actual dimensions after considering rotation
        var actualSize = sourceSize
        let rotation = atan2(preferredTransform.b, preferredTransform.a)
        let isRotated = abs(rotation) > 0.1 // Check if rotated (90, -90, or 180 degrees)
        
        if abs(rotation - .pi/2) < 0.1 || abs(rotation + .pi/2) < 0.1 {
            // 90 or -90 degrees rotation
            actualSize = CGSize(width: sourceSize.height, height: sourceSize.width)
        }
        
        // Calculate scale to FILL the screen (not fit)
        let scaleX = targetSize.width / actualSize.width
        let scaleY = targetSize.height / actualSize.height
        let scale = max(scaleX, scaleY) // Use max to ensure full coverage
        
        // Calculate centered position
        let scaledWidth = actualSize.width * scale
        let scaledHeight = actualSize.height * scale
        let offsetX = (targetSize.width - scaledWidth) / 2
        let offsetY = (targetSize.height - scaledHeight) / 2
        
        // Build transform: first apply original rotation, then scale, then translate
        var transform = CGAffineTransform.identity
        
        if abs(rotation - .pi/2) < 0.1 {
            // 90 degrees clockwise
            transform = transform.translatedBy(x: targetSize.width, y: 0)
            transform = transform.rotated(by: .pi/2)
            transform = transform.scaledBy(x: scale, y: scale)
            transform = transform.translatedBy(x: offsetY / scale, y: -offsetX / scale)
        } else if abs(rotation + .pi/2) < 0.1 {
            // 90 degrees counter-clockwise
            transform = transform.translatedBy(x: 0, y: targetSize.height)
            transform = transform.rotated(by: -.pi/2)
            transform = transform.scaledBy(x: scale, y: scale)
            transform = transform.translatedBy(x: -offsetY / scale, y: offsetX / scale)
        } else if abs(rotation - .pi) < 0.1 || abs(rotation + .pi) < 0.1 {
            // 180 degrees
            transform = transform.translatedBy(x: targetSize.width, y: targetSize.height)
            transform = transform.rotated(by: .pi)
            transform = transform.scaledBy(x: scale, y: scale)
            transform = transform.translatedBy(x: -offsetX / scale, y: -offsetY / scale)
        } else {
            // No rotation or identity
            transform = transform.scaledBy(x: scale, y: scale)
            transform = transform.translatedBy(x: offsetX / scale, y: offsetY / scale)
        }
        
        return transform
    }
    
    private func createAnimationTool(dateTitle: String, videoSize: CGSize, duration: CMTime, entryCount: Int, imageDuration: CMTime, maxVideoDuration: CMTime) -> AVVideoCompositionCoreAnimationTool {
        // Create parent layer
        let parentLayer = CALayer()
        parentLayer.frame = CGRect(origin: .zero, size: videoSize)
        parentLayer.isGeometryFlipped = true // Flip to match video coordinate system
        
        // Create video layer - this is where the actual video will be rendered
        let videoLayer = CALayer()
        videoLayer.frame = CGRect(origin: .zero, size: videoSize)
        
        // Create date title overlay at the top
        let titleLayer = CATextLayer()
        titleLayer.string = dateTitle
        titleLayer.fontSize = 80
        titleLayer.font = UIFont.boldSystemFont(ofSize: 80)
        titleLayer.alignmentMode = .center
        titleLayer.foregroundColor = UIColor.white.cgColor
        titleLayer.contentsScale = 2.0 // For better text rendering
        
        // Add shadow for better readability
        titleLayer.shadowColor = UIColor.black.cgColor
        titleLayer.shadowOpacity = 0.9
        titleLayer.shadowOffset = CGSize(width: 0, height: 4)
        titleLayer.shadowRadius = 10
        
        // Position at top with padding (accounting for flipped coordinates)
        let titleHeight: CGFloat = 120
        titleLayer.frame = CGRect(
            x: 100,
            y: 100,
            width: videoSize.width - 200,
            height: titleHeight
        )
        
        // Add fade in animation for title
        let fadeInAnimation = CABasicAnimation(keyPath: "opacity")
        fadeInAnimation.fromValue = 0
        fadeInAnimation.toValue = 1
        fadeInAnimation.duration = 0.5
        fadeInAnimation.beginTime = AVCoreAnimationBeginTimeAtZero
        fadeInAnimation.fillMode = .forwards
        fadeInAnimation.isRemovedOnCompletion = false
        titleLayer.add(fadeInAnimation, forKey: "fadeIn")
        
        // Add transition effects between clips
        var currentTime: Double = 0
        for i in 0..<entryCount {
            let clipDuration = CMTimeGetSeconds(imageDuration) // Simplified - use image duration for now
            
            if i < entryCount - 1 {
                // Add fade transition at the end of each clip
                let transitionLayer = CALayer()
                transitionLayer.frame = CGRect(origin: .zero, size: videoSize)
                transitionLayer.backgroundColor = UIColor.black.cgColor
                transitionLayer.opacity = 0
                
                let fadeAnimation = CAKeyframeAnimation(keyPath: "opacity")
                fadeAnimation.values = [0, 0.3, 0]
                fadeAnimation.keyTimes = [0, 0.5, 1.0]
                fadeAnimation.duration = 0.6
                fadeAnimation.beginTime = AVCoreAnimationBeginTimeAtZero + currentTime + clipDuration - 0.3
                fadeAnimation.fillMode = .forwards
                fadeAnimation.isRemovedOnCompletion = false
                
                transitionLayer.add(fadeAnimation, forKey: "transition_\(i)")
                parentLayer.addSublayer(transitionLayer)
            }
            
            currentTime += clipDuration
        }
        
        // Add layers: video first (bottom), then transitions, then title (top)
        parentLayer.addSublayer(videoLayer)
        parentLayer.addSublayer(titleLayer)
        
        return AVVideoCompositionCoreAnimationTool(
            postProcessingAsVideoLayer: videoLayer,
            in: parentLayer
        )
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
        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        ) else {
            CVPixelBufferUnlockBaseAddress(buffer, [])
            return nil
        }

        // Use UIKit to handle orientation and cropping
        UIGraphicsBeginImageContextWithOptions(size, true, 1.0)
        let imageSize = image.size
        let scaleX = size.width / imageSize.width
        let scaleY = size.height / imageSize.height
        let scale = aspectFill ? max(scaleX, scaleY) : min(scaleX, scaleY)
        let scaledWidth = imageSize.width * scale
        let scaledHeight = imageSize.height * scale
        let x = (size.width - scaledWidth) / 2
        let y = (size.height - scaledHeight) / 2

        // Background
        UIColor.black.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))

        // Draw oriented image; UIKit applies orientation correctly
        image.draw(in: CGRect(x: x, y: y, width: scaledWidth, height: scaledHeight))

        let fittedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        if let cg = fittedImage?.cgImage {
            context.draw(cg, in: CGRect(origin: .zero, size: size))
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

