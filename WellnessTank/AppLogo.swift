//
//  AppLogo.swift
//  WellnessTank
//
//  Created by Zhuoming Li on 11/16/25.
//

import SwiftUI

struct AppLogo: View {
    var size: CGFloat = 60
    
    var body: some View {
        ZStack {
            // Background circle with gradient
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.3, green: 0.7, blue: 0.9),
                            Color(red: 0.2, green: 0.5, blue: 0.8)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
            
            // Water drop / wellness symbol
            ZStack {
                // Main drop shape
                Image(systemName: "drop.fill")
                    .font(.system(size: size * 0.45))
                    .foregroundStyle(.white)
                
                // Heart inside the drop
                Image(systemName: "heart.fill")
                    .font(.system(size: size * 0.2))
                    .foregroundStyle(Color(red: 0.2, green: 0.5, blue: 0.8))
                    .offset(y: size * 0.05)
            }
        }
        .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
    }
}

struct AppLogoWithText: View {
    var size: CGFloat = 60
    
    var body: some View {
        HStack(spacing: 12) {
            AppLogo(size: size)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("WellnessTank")
                    .font(.system(size: size * 0.35, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color(red: 0.3, green: 0.7, blue: 0.9),
                                Color(red: 0.2, green: 0.5, blue: 0.8)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                Text("Your Wellness Journey")
                    .font(.system(size: size * 0.18))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview("Logo Only") {
    VStack(spacing: 40) {
        AppLogo(size: 100)
        AppLogo(size: 60)
        AppLogo(size: 40)
    }
    .padding()
}

#Preview("Logo with Text") {
    VStack(spacing: 40) {
        AppLogoWithText(size: 80)
        AppLogoWithText(size: 60)
        AppLogoWithText(size: 40)
    }
    .padding()
}

