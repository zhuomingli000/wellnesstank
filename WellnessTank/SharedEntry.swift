//
//  SharedEntry.swift
//  WellnessTank
//
//  Created by Zhuoming Li on 11/15/25.
//

import SwiftUI

struct SharedEntry: Identifiable {
    let id: UUID
    let username: String
    let userAvatar: String
    let timestamp: Date
    let activityDescription: String
    let category: WellnessCategory
    let imageName: String? // For demo purposes
    let likes: Int
    
    static func mockEntries() -> [SharedEntry] {
        [
            SharedEntry(
                id: UUID(),
                username: "fitness_jane",
                userAvatar: "👩‍🦰",
                timestamp: Date().addingTimeInterval(-3600),
                activityDescription: "Morning workout session (95%)",
                category: .workout,
                imageName: nil,
                likes: 24
            ),
            SharedEntry(
                id: UUID(),
                username: "healthy_mike",
                userAvatar: "👨",
                timestamp: Date().addingTimeInterval(-7200),
                activityDescription: "Acai bowl (88%)",
                category: .food,
                imageName: nil,
                likes: 42
            ),
            SharedEntry(
                id: UUID(),
                username: "wellness_coach",
                userAvatar: "👩‍⚕️",
                timestamp: Date().addingTimeInterval(-10800),
                activityDescription: "Daily vitamins (92%)",
                category: .supplements,
                imageName: nil,
                likes: 18
            ),
            SharedEntry(
                id: UUID(),
                username: "yoga_guru",
                userAvatar: "🧘‍♀️",
                timestamp: Date().addingTimeInterval(-14400),
                activityDescription: "Yoga practice (90%)",
                category: .workout,
                imageName: nil,
                likes: 56
            ),
            SharedEntry(
                id: UUID(),
                username: "meal_prep_pro",
                userAvatar: "👨‍🍳",
                timestamp: Date().addingTimeInterval(-18000),
                activityDescription: "Grilled chicken salad (87%)",
                category: .food,
                imageName: nil,
                likes: 31
            )
        ]
    }
}

