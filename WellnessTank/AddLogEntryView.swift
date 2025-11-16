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
    
    // Multi-select states only
    @State private var showMultiPicker = false
    @State private var selectedMultiItems: [SelectedMediaItem] = []
    @State private var isProcessing = false
    @State private var processingStatus = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                contentView
                
                if isProcessing {
                    processingOverlay
                }
            }
            .navigationTitle("New Log Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                cancelButton
            }
            .sheet(isPresented: $showMultiPicker) {
                MultiMediaPicker(selectedItems: $selectedMultiItems, isPresented: $showMultiPicker)
            }
            .onChange(of: showMultiPicker, handlePickerDismissal)
            .onChange(of: selectedMultiItems, handleMediaItemsChange)
        }
    }
    
    @ViewBuilder
    private var contentView: some View {
        VStack(spacing: 20) {
            if !isProcessing {
                AppLogo(size: 80)
                
                Text("Select photos and videos from your library")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .padding()
                
                selectMediaButton
            }
            
            Spacer()
        }
    }
    
    @ViewBuilder
    private var selectMediaButton: some View {
        Button(action: {
            showMultiPicker = true
        }) {
            Label("Select Media", systemImage: "photo.on.rectangle.angled")
                .font(.title3)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.accentColor)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private var processingOverlay: some View {
        Color.black.opacity(0.4)
            .ignoresSafeArea()
        
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(2)
                .tint(.white)
            
            Text(processingStatus)
                .font(.headline)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding()
                .background(Color.black.opacity(0.7))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding()
    }
    
    @ToolbarContentBuilder
    private var cancelButton: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") {
                dismiss()
            }
            .disabled(isProcessing)
        }
    }
    
    private func handlePickerDismissal(oldValue: Bool, newValue: Bool) {
        if oldValue == true && newValue == false {
            print("AddLogEntryView: Picker dismissed - showing loading UI")
            isProcessing = true
            processingStatus = "Loading selected items..."
        }
    }
    
    private func handleMediaItemsChange(oldValue: [SelectedMediaItem], newValue: [SelectedMediaItem]) {
        print("AddLogEntryView: onChange triggered. Old count: \(oldValue.count), New count: \(newValue.count)")
        
        guard !newValue.isEmpty else {
            print("AddLogEntryView: newValue is empty, returning")
            if oldValue.isEmpty && isProcessing {
                isProcessing = false
            }
            return
        }
        
        print("AddLogEntryView: Starting to process \(newValue.count) items")
        
        DispatchQueue.main.async {
            self.isProcessing = true
            self.processingStatus = "Processing \(newValue.count) items..."
        }
        
        Task {
            for (index, item) in newValue.enumerated() {
                print("AddLogEntryView: Processing item \(index + 1) of \(newValue.count)")
                await MainActor.run {
                    processingStatus = "Processing \(index + 1) of \(newValue.count)...\nTrimming, analyzing, and saving"
                }
                await processAndSaveMultiItem(item)
                print("AddLogEntryView: Finished item \(index + 1)")
            }
            
            print("AddLogEntryView: All items processed, dismissing")
            await MainActor.run {
                selectedMultiItems = []
                isProcessing = false
                dismiss()
            }
        }
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
    
    private func processAndSaveMultiItem(_ item: SelectedMediaItem) async {
        let mediaData: Data?
        let mediaType: MediaType
        var description: String = ""
        var category: WellnessCategory = .food
        
        if let image = item.image {
            // Process image
            mediaData = image.jpegData(compressionQuality: 0.8)
            mediaType = .photo
            
            // Analyze image synchronously
            await withCheckedContinuation { continuation in
                ImageAnalyzer.shared.analyzeImage(image) { result in
                    description = result.description
                    category = result.category
                    continuation.resume()
                }
            }
        } else if let videoURL = item.videoURL {
            // Trim video if needed
            let trimmedURL = await trimAndSaveVideo(videoURL: videoURL)
            
            // Process video
            mediaData = try? Data(contentsOf: trimmedURL)
            mediaType = .video
            
            // Analyze video synchronously
            await withCheckedContinuation { continuation in
                ImageAnalyzer.shared.analyzeVideo(trimmedURL) { result in
                    description = result.description
                    category = result.category
                    continuation.resume()
                }
            }
        } else {
            return
        }
        
        guard let data = mediaData, !description.isEmpty else { return }
        
        // Save entry on main actor
        await MainActor.run {
            let entry = LogEntry(
                timestamp: Date(),
                activityDescription: description,
                mediaData: data,
                mediaType: mediaType,
                category: category
            )
            modelContext.insert(entry)
        }
    }
}

#Preview {
    AddLogEntryView()
        .modelContainer(for: LogEntry.self, inMemory: true)
}
