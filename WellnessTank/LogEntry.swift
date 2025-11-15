//
//  LogEntry.swift
//  WellnessTank
//
//  Created by Zhuoming Li on 11/15/25.
//

import SwiftUI
import SwiftData

enum MediaType: String, Codable {
    case photo
    case video
}

enum WellnessCategory: String, Codable, CaseIterable {
    case workout = "Workout"
    case food = "Food"
    case supplements = "Supplements"
    
    var icon: String {
        switch self {
        case .workout: return "figure.run"
        case .food: return "fork.knife"
        case .supplements: return "pill.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .workout: return .orange
        case .food: return .green
        case .supplements: return .blue
        }
    }
}

@Model
class LogEntry {
    @Attribute(.unique) var id: UUID
    var timestamp: Date
    var activityDescription: String
    @Attribute(.externalStorage) var mediaData: Data?
    var mediaTypeRaw: String = "photo" // Default value for migration
    var categoryRaw: String = "food" // Default category
    
    init(timestamp: Date = Date(), activityDescription: String, mediaData: Data?, mediaType: MediaType = .photo, category: WellnessCategory = .food) {
        self.id = UUID()
        self.timestamp = timestamp
        self.activityDescription = activityDescription
        self.mediaData = mediaData
        self.mediaTypeRaw = mediaType.rawValue
        self.categoryRaw = category.rawValue
    }
    
    var mediaType: MediaType {
        get { MediaType(rawValue: mediaTypeRaw) ?? .photo }
        set { mediaTypeRaw = newValue.rawValue }
    }
    
    var category: WellnessCategory {
        get { WellnessCategory(rawValue: categoryRaw) ?? .food }
        set { categoryRaw = newValue.rawValue }
    }
    
    var image: UIImage? {
        guard mediaType == .photo, let mediaData = mediaData else { return nil }
        return UIImage(data: mediaData)
    }
}

