//
//  AddLogEntryView.swift
//  WellnessTank
//
//  Created by Zhuoming Li on 11/15/25.
//

import SwiftUI
import SwiftData
import AVFoundation

struct AddLogEntryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedImage: UIImage?
    @State private var selectedVideoURL: URL?
    @State private var activityDescription: String = ""
    @State private var detectedCategory: WellnessCategory = .food
    @State private var isAnalyzing = false
    @State private var showMediaPicker = false
    @State private var showActionSheet = false
    @State private var mediaSourceType: UIImagePickerController.SourceType = .camera
    @State private var detectedActivities: [String] = []
    
    private var hasMedia: Bool {
        selectedImage != nil || selectedVideoURL != nil
    }
    
    private var isSaveDisabled: Bool {
        !hasMedia || activityDescription.isEmpty || isAnalyzing
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if let image = selectedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 300)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else if let videoURL = selectedVideoURL {
                        VideoThumbnailView(videoURL: videoURL)
                            .frame(maxHeight: 300)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 50))
                                .foregroundStyle(.gray)
                            Text("No media selected")
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 200)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    Button(action: {
                        showActionSheet = true
                    }) {
                        Label(hasMedia ? "Change Media" : "Add Media", systemImage: hasMedia ? "arrow.triangle.2.circlepath" : "plus.circle")
                            .frame(maxWidth: .infinity)
                    }
                } header: {
                    Text("Media")
                }
                
                if hasMedia {
                    Section {
                        if isAnalyzing {
                            HStack {
                                ProgressView()
                                Text("Analyzing...")
                                    .foregroundStyle(.secondary)
                                    .padding(.leading, 8)
                            }
                        } else if !activityDescription.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 8) {
                                    Image(systemName: detectedCategory.icon)
                                        .foregroundStyle(detectedCategory.color)
                                    Text(detectedCategory.rawValue)
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(detectedCategory.color)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(detectedCategory.color.opacity(0.15))
                                .clipShape(Capsule())
                                
                                Text(activityDescription)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } header: {
                        Text("AI Detection")
                    }
                }
            }
            .navigationTitle("New Log Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveEntry()
                    }
                    .disabled(isSaveDisabled)
                }
            }
            .confirmationDialog("Choose Media Source", isPresented: $showActionSheet) {
                Button("Take Photo/Video") {
                    mediaSourceType = .camera
                    showMediaPicker = true
                }
                Button("Choose from Library") {
                    mediaSourceType = .photoLibrary
                    showMediaPicker = true
                }
                Button("Cancel", role: .cancel) {}
            }
            .sheet(isPresented: $showMediaPicker) {
                MediaPicker(selectedImage: $selectedImage, selectedVideoURL: $selectedVideoURL, isPresented: $showMediaPicker, sourceType: mediaSourceType)
            }
            .onChange(of: selectedImage) { oldValue, newValue in
                if let image = newValue {
                    selectedVideoURL = nil // Clear video if image is selected
                    analyzeImage(image)
                }
            }
            .onChange(of: selectedVideoURL) { oldValue, newValue in
                if let videoURL = newValue {
                    selectedImage = nil // Clear image if video is selected
                    
                    // Trim video if needed, then analyze
                    Task {
                        let trimmedURL = await trimAndSaveVideo(videoURL: videoURL)
                        selectedVideoURL = trimmedURL
                        analyzeVideo(trimmedURL)
                    }
                }
            }
        }
    }
    
    private func analyzeImage(_ image: UIImage) {
        isAnalyzing = true
        activityDescription = ""
        detectedActivities = []
        
        // Get the main description with category
        ImageAnalyzer.shared.analyzeImage(image) { result in
            activityDescription = result.description
            detectedCategory = result.category
        }
        
        // Get additional predictions
        ImageAnalyzer.shared.analyzeImageDetailed(image) { activities in
            if activities.count > 1 {
                detectedActivities = Array(activities.dropFirst())
            }
            isAnalyzing = false
        }
    }
    
    private func analyzeVideo(_ videoURL: URL) {
        isAnalyzing = true
        activityDescription = ""
        detectedActivities = []
        
        // Get the main description from video with category
        ImageAnalyzer.shared.analyzeVideo(videoURL) { result in
            activityDescription = result.description
            detectedCategory = result.category
        }
        
        // Get additional predictions
        ImageAnalyzer.shared.analyzeVideoDetailed(videoURL) { activities in
            if activities.count > 1 {
                detectedActivities = Array(activities.dropFirst())
            }
            isAnalyzing = false
        }
    }
    
    private func saveEntry() {
        let mediaData: Data?
        let mediaType: MediaType
        
        if let image = selectedImage {
            mediaData = image.jpegData(compressionQuality: 0.8)
            mediaType = .photo
        } else if let videoURL = selectedVideoURL {
            // Video is already trimmed from onChange
            mediaData = try? Data(contentsOf: videoURL)
            mediaType = .video
        } else {
            return
        }
        
        guard let data = mediaData else { return }
        
        let entry = LogEntry(
            timestamp: Date(),
            activityDescription: activityDescription,
            mediaData: data,
            mediaType: mediaType,
            category: detectedCategory
        )
        
        modelContext.insert(entry)
        
        dismiss()
    }
    
    private func trimAndSaveVideo(videoURL: URL) async -> URL {
        let asset = AVAsset(url: videoURL)
        
        return await withCheckedContinuation { continuation in
            Task {
                let duration: Double
                do {
                    duration = try await asset.load(.duration).seconds
                } catch {
                    continuation.resume(returning: videoURL)
                    return
                }
                
                // Only trim if longer than 40 seconds
                guard duration > 40 else {
                    continuation.resume(returning: videoURL)
                    return
                }
                
                // Trim 15 seconds from start and 10 seconds from end
                let startTime = CMTime(seconds: 15, preferredTimescale: 600)
                let endTime = CMTime(seconds: duration - 10, preferredTimescale: 600)
                let timeRange = CMTimeRange(start: startTime, end: endTime)
                
                // Export trimmed video to temp location
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString + ".mp4")
                
                guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else {
                    continuation.resume(returning: videoURL)
                    return
                }
                
                exportSession.outputURL = tempURL
                exportSession.outputFileType = .mp4
                exportSession.timeRange = timeRange
                
                await exportSession.export()
                
                if exportSession.status == .completed {
                    continuation.resume(returning: tempURL)
                } else {
                    continuation.resume(returning: videoURL)
                }
            }
        }
    }
}

#Preview {
    AddLogEntryView()
        .modelContainer(for: LogEntry.self, inMemory: true)
}
