//
//  VideoPlayerView.swift
//  WellnessTank
//
//  Created by Zhuoming Li on 11/15/25.
//

import SwiftUI
import AVKit

struct VideoPlayerView: View {
    let videoURL: URL
    @State private var player: AVPlayer?
    
    var body: some View {
        VideoPlayer(player: player)
            .onAppear {
                player = AVPlayer(url: videoURL)
            }
            .onDisappear {
                player?.pause()
                player = nil
            }
    }
}

struct VideoThumbnailView: View {
    let videoURL: URL
    @State private var thumbnail: UIImage?
    
    var body: some View {
        Group {
            if let thumbnail = thumbnail {
                ZStack {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                    
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.white)
                        .shadow(radius: 5)
                }
            } else {
                ZStack {
                    Color(.systemGray5)
                    ProgressView()
                }
            }
        }
        .onAppear {
            generateThumbnail()
        }
    }
    
    private func generateThumbnail() {
        let asset = AVAsset(url: videoURL)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        
        let time = CMTime(seconds: 1, preferredTimescale: 60)
        
        Task {
            do {
                let cgImage = try await imageGenerator.image(at: time).image
                await MainActor.run {
                    thumbnail = UIImage(cgImage: cgImage)
                }
            } catch {
                print("Error generating thumbnail: \(error)")
            }
        }
    }
}

