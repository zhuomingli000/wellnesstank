//
//  LogEntryDetailView.swift
//  WellnessTank
//
//  Created by Zhuoming Li on 11/15/25.
//

import SwiftUI
import SwiftData

struct LogEntryDetailView: View {
    let entry: LogEntry
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var tempVideoURL: URL?
    @State private var showShareSheet = false
    @State private var shareSuccess = false
    @State private var showDeleteAlert = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if entry.mediaType == .photo, let image = entry.image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(radius: 5)
                } else if entry.mediaType == .video, let videoURL = tempVideoURL {
                    VideoPlayerView(videoURL: videoURL)
                        .frame(height: 300)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(radius: 5)
                }
                
                VStack(alignment: .leading, spacing: 16) {
                    // Timestamp
                    Label(entry.timestamp.formatted(date: .long, time: .shortened), systemImage: "clock")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    // Category Badge
                    HStack(spacing: 8) {
                        Image(systemName: entry.category.icon)
                            .foregroundStyle(entry.category.color)
                        Text(entry.category.rawValue)
                            .font(.headline)
                            .foregroundStyle(entry.category.color)
                        if entry.mediaType == .video {
                            Image(systemName: "video.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(entry.category.color.opacity(0.15))
                    .clipShape(Capsule())
                    
                    // Description
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Details")
                            .font(.headline)
                        Text(entry.activityDescription)
                            .font(.body)
                    }
                }
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle("Log Entry")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    shareEntry()
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
            }
            
            ToolbarItem(placement: .destructiveAction) {
                Button(role: .destructive) {
                    showDeleteAlert = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .alert("Shared Successfully", isPresented: $shareSuccess) {
            Button("OK") { }
        } message: {
            Text("Your wellness activity has been shared to the community!")
        }
        .alert("Delete Entry", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteEntry()
            }
        } message: {
            Text("Are you sure you want to delete this log entry? This action cannot be undone.")
        }
        .onAppear {
            if entry.mediaType == .video, let mediaData = entry.mediaData {
                tempVideoURL = createTempVideoURL(from: mediaData)
            }
        }
        .onDisappear {
            if let tempURL = tempVideoURL {
                try? FileManager.default.removeItem(at: tempURL)
            }
        }
    }
    
    private func createTempVideoURL(from data: Data) -> URL? {
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = UUID().uuidString + ".mp4"
        let fileURL = tempDir.appendingPathComponent(fileName)
        
        do {
            try data.write(to: fileURL)
            return fileURL
        } catch {
            print("Error creating temp video file: \(error)")
            return nil
        }
    }
    
    private func shareEntry() {
        // In a real app, this would upload to a server
        // For now, we'll just show a success message
        shareSuccess = true
    }
    
    private func deleteEntry() {
        modelContext.delete(entry)
        dismiss()
    }
}

