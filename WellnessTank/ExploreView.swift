//
//  ExploreView.swift
//  WellnessTank
//
//  Created by Zhuoming Li on 11/15/25.
//

import SwiftUI

struct ExploreView: View {
    @State private var sharedEntries = SharedEntry.mockEntries()
    @State private var selectedCategory: WellnessCategory? = nil
    
    var filteredEntries: [SharedEntry] {
        if let category = selectedCategory {
            return sharedEntries.filter { $0.category == category }
        }
        return sharedEntries
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Category Filter
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            FilterChip(
                                title: "All",
                                icon: "sparkles",
                                color: .blue,
                                isSelected: selectedCategory == nil
                            ) {
                                selectedCategory = nil
                            }
                            
                            ForEach(WellnessCategory.allCases, id: \.self) { category in
                                FilterChip(
                                    title: category.rawValue,
                                    icon: category.icon,
                                    color: category.color,
                                    isSelected: selectedCategory == category
                                ) {
                                    selectedCategory = category
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 12)
                    }
                    .background(Color(.systemBackground))
                    
                    Divider()
                    
                    // Shared Entries Feed
                    LazyVStack(spacing: 16) {
                        ForEach(filteredEntries) { entry in
                            SharedEntryCard(entry: entry)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Explore")
            .refreshable {
                // In a real app, this would fetch from server
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }
}

struct FilterChip: View {
    let title: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isSelected ? color : Color(.systemGray6))
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(Capsule())
        }
    }
}

struct SharedEntryCard: View {
    let entry: SharedEntry
    @State private var isLiked = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // User Info Header
            HStack(spacing: 12) {
                Text(entry.userAvatar)
                    .font(.title2)
                    .frame(width: 40, height: 40)
                    .background(Color(.systemGray6))
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.username)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text(entry.timestamp.formatted(.relative(presentation: .named)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
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
            
            // Image Placeholder
            RoundedRectangle(cornerRadius: 12)
                .fill(LinearGradient(
                    colors: [entry.category.color.opacity(0.3), entry.category.color.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(height: 200)
                .overlay {
                    VStack {
                        Image(systemName: entry.category.icon)
                            .font(.system(size: 50))
                            .foregroundStyle(entry.category.color.opacity(0.5))
                        Text(entry.activityDescription)
                            .font(.headline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }
            
            // Activity Description
            Text(entry.activityDescription)
                .font(.body)
            
            // Actions
            HStack(spacing: 20) {
                Button {
                    isLiked.toggle()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .foregroundStyle(isLiked ? .red : .secondary)
                        Text("\(entry.likes + (isLiked ? 1 : 0))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Button {
                    // Comment action
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "bubble.right")
                        Text("Comment")
                            .font(.subheadline)
                    }
                    .foregroundStyle(.secondary)
                }
                
                Spacer()
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
}

