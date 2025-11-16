//
//  ExploreView.swift
//  WellnessTank
//
//  Created by Zhuoming Li on 11/15/25.
//

import SwiftUI
import AVKit

struct ExploreView: View {
    @EnvironmentObject private var feedStore: SharedFeedStore
    
    var myCompiledVideos: [SharedEntry] {
        // Only show entries with videos (compiled videos)
        feedStore.entries.filter { $0.videoURL != nil }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                if myCompiledVideos.isEmpty {
                    VStack(spacing: 20) {
                        AppLogo(size: 100)
                        
                        Text("No Compiled Videos Yet")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Tap 'Compile My Day' to create your first video compilation")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                } else {
                    LazyVStack(spacing: 16) {
                        ForEach(myCompiledVideos) { entry in
                            CompiledVideoCard(entry: entry)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Journey")
        }
    }
}

struct CompiledVideoCard: View {
    let entry: SharedEntry
    @State private var player: AVPlayer?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Date Header
            HStack {
                Text(entry.timestamp.formatted(date: .abbreviated, time: .omitted))
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                // Category Badge
                HStack(spacing: 4) {
                    Image(systemName: entry.category.icon)
                        .font(.caption2)
                    Text(entry.category.rawValue)
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundStyle(entry.category.color)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(entry.category.color.opacity(0.15))
                .clipShape(Capsule())
            }
            
            // Video Player
            if let videoURL = entry.videoURL {
                VideoPlayer(player: player)
                    .frame(height: 400)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(radius: 4)
                    .onAppear {
                        if player == nil {
                            player = AVPlayer(url: videoURL)
                        }
                    }
                    .onDisappear {
                        player?.pause()
                        player = nil
                    }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

#Preview {
    ExploreView()
        .environmentObject(SharedFeedStore())
}

