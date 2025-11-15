//
//  AddLogEntryView.swift
//  WellnessTank
//
//  Created by Zhuoming Li on 11/15/25.
//

import SwiftUI
import SwiftData

struct AddLogEntryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedImage: UIImage?
    @State private var selectedVideoURL: URL?
    @State private var activityDescription: String = ""
    @State private var detectedCategory: WellnessCategory = .food
    @State private var isAnalyzing: Bool = false
    @State private var detectedActivities: [String] = []
    @State private var showMediaPicker = false
    @State private var showActionSheet = false
    @State private var mediaSourceType: UIImagePickerController.SourceType = .camera
    
    private var hasMedia: Bool {
        selectedImage != nil || selectedVideoURL != nil
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
                            Text("No photo or video selected")
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
                        Label(hasMedia ? "Change Media" : "Add Photo/Video", systemImage: "photo.on.rectangle")
                            .frame(maxWidth: .infinity)
                    }
                } header: {
                    Text("Photo or Video")
                }
                
                Section {
                    if isAnalyzing {
                        HStack {
                            ProgressView()
                            Text("Analyzing image with AI...")
                                .foregroundStyle(.secondary)
                                .padding(.leading, 8)
                        }
                    } else if !activityDescription.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            // Category Badge
                            HStack(spacing: 8) {
                                Image(systemName: detectedCategory.icon)
                                    .foregroundStyle(detectedCategory.color)
                                Text(detectedCategory.rawValue)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(detectedCategory.color)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(detectedCategory.color.opacity(0.15))
                            .clipShape(Capsule())
                            
                            // Description
                            HStack {
                                Image(systemName: "sparkles")
                                    .foregroundStyle(.blue)
                                Text(activityDescription)
                                    .font(.body)
                            }
                            
                            if !detectedActivities.isEmpty {
                                Divider()
                                Text("Other possibilities:")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                ForEach(detectedActivities.indices, id: \.self) { index in
                                    Text("• \(detectedActivities[index])")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    } else {
                        Text("Take or select a photo/video to detect activity")
                            .foregroundStyle(.secondary)
                            .font(.body)
                    }
                } header: {
                    Text("AI-Detected Activity")
                } footer: {
                    Text("Activity is automatically detected using on-device machine learning")
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
                    .disabled(!hasMedia || activityDescription.isEmpty || isAnalyzing)
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
                    selectedVideoURL = nil
                    analyzeImage(image)
                }
            }
            .onChange(of: selectedVideoURL) { oldValue, newValue in
                if let videoURL = newValue {
                    selectedImage = nil
                    analyzeVideo(videoURL)
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
            self.activityDescription = result.description
            self.detectedCategory = result.category
        }
        
        // Get additional predictions
        ImageAnalyzer.shared.analyzeImageDetailed(image) { activities in
            // Skip the first one as it's already shown as main description
            if activities.count > 1 {
                self.detectedActivities = Array(activities.dropFirst())
            }
            self.isAnalyzing = false
        }
    }
    
    private func analyzeVideo(_ videoURL: URL) {
        isAnalyzing = true
        activityDescription = ""
        detectedActivities = []
        
        // Get the main description from video with category
        ImageAnalyzer.shared.analyzeVideo(videoURL) { result in
            self.activityDescription = result.description
            self.detectedCategory = result.category
        }
        
        // Get additional predictions
        ImageAnalyzer.shared.analyzeVideoDetailed(videoURL) { activities in
            if activities.count > 1 {
                self.detectedActivities = Array(activities.dropFirst())
            }
            self.isAnalyzing = false
        }
    }
    
    private func saveEntry() {
        let mediaData: Data?
        let mediaType: MediaType
        
        if let image = selectedImage {
            mediaData = image.jpegData(compressionQuality: 0.8)
            mediaType = .photo
        } else if let videoURL = selectedVideoURL {
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
}

#Preview {
    AddLogEntryView()
        .modelContainer(for: LogEntry.self, inMemory: true)
}

