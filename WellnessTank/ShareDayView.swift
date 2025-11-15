//
//  ShareDayView.swift
//  WellnessTank
//
//  Created by Zhuoming Li on 11/15/25.
//

import SwiftUI
import AVKit

struct ShareDayView: View {
    let dateTitle: String
    let entries: [LogEntry]
    @StateObject private var videoGenerator = VideoGenerator()
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingSaveOptions = false
    @State private var player: AVPlayer?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if videoGenerator.isGenerating {
                    VStack(spacing: 16) {
                        ProgressView(value: videoGenerator.generationProgress) {
                            Text("Generating your day video...")
                                .font(.headline)
                        }
                        .progressViewStyle(.linear)
                        .padding()
                        
                        Text("\(Int(videoGenerator.generationProgress * 100))%")
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    .padding()
                } else if let videoURL = videoGenerator.generatedVideoURL {
                    VStack(spacing: 20) {
                        // Video Preview
                        if let player = player {
                            VideoPlayer(player: player)
                                .frame(height: 500)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .shadow(radius: 10)
                                .padding()
                                .onAppear {
                                    player.play()
                                }
                                .onDisappear {
                                    player.pause()
                                }
                        }
                        
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.green)
                        
                        Text("Video Generated!")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Preview your \(dateTitle.lowercased()) wellness highlights above.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        VStack(spacing: 12) {
                            Button {
                                saveToPhotos(videoURL: videoURL)
                            } label: {
                                Label("Save to Photos", systemImage: "square.and.arrow.down")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundStyle(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            
                            Button {
                                shareToFeed()
                            } label: {
                                Label("Share to Feed", systemImage: "globe")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.green)
                                    .foregroundStyle(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                        .padding()
                    }
                } else {
                    VStack(spacing: 20) {
                        Image(systemName: "video.badge.plus")
                            .font(.system(size: 60))
                            .foregroundStyle(.blue)
                        
                        Text("Share My Day")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("Create a 10-second video compilation of your \(dateTitle.lowercased()) wellness activities with background music.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        // Preview of activities
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Activities to include:")
                                .font(.headline)
                            
                            ForEach(entries.prefix(3)) { entry in
                                HStack(spacing: 8) {
                                    Image(systemName: entry.category.icon)
                                        .foregroundStyle(entry.category.color)
                                    Text(entry.category.rawValue)
                                        .font(.subheadline)
                                    Spacer()
                                }
                            }
                            
                            if entries.count > 3 {
                                Text("+ \(entries.count - 3) more")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding()
                        
                        Button {
                            generateVideo()
                        } label: {
                            Label("Generate Video", systemImage: "play.circle.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .padding()
                    }
                }
                
                if let error = videoGenerator.error {
                    Text("Error: \(error)")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding()
                }
            }
            .navigationTitle("Share My Day")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        player?.pause()
                        dismiss()
                    }
                }
            }
            .alert("Saved!", isPresented: $showingSaveOptions) {
                Button("OK") { }
            } message: {
                Text("Your video has been saved to Photos!")
            }
            .onChange(of: videoGenerator.generatedVideoURL) { oldValue, newValue in
                if let url = newValue {
                    player = AVPlayer(url: url)
                }
            }
        }
    }
    
    private func generateVideo() {
        videoGenerator.generateDayVideo(entries: entries, dateTitle: dateTitle) { url in
            // Video generation completed
        }
    }
    
    private func saveToPhotos(videoURL: URL) {
        videoGenerator.saveToPhotos(videoURL: videoURL) { success, error in
            if success {
                showingSaveOptions = true
            }
        }
    }
    
    private func shareToFeed() {
        // In a real app, this would upload to the server
        dismiss()
    }
}

#Preview {
    ShareDayView(dateTitle: "Today", entries: [])
}

