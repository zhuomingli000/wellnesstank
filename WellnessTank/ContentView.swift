//
//  ContentView.swift
//  WellnessTank
//
//  Created by Zhuoming Li on 11/15/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LogEntry.timestamp, order: .reverse) private var entries: [LogEntry]
    @State private var showingAddEntry = false
    
    // Group entries by date
    private var groupedEntries: [(String, [LogEntry])] {
        let grouped = Dictionary(grouping: entries) { entry -> String in
            let calendar = Calendar.current
            let dateComponents = calendar.dateComponents([.year, .month, .day], from: entry.timestamp)
            guard let date = calendar.date(from: dateComponents) else {
                return ""
            }
            
            // Format for display and sorting
            if calendar.isDateInToday(date) {
                return "Today"
            } else if calendar.isDateInYesterday(date) {
                return "Yesterday"
            } else {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .none
                return formatter.string(from: date)
            }
        }
        
        // Sort sections by date (most recent first)
        return grouped.sorted { first, second in
            if first.key == "Today" { return true }
            if second.key == "Today" { return false }
            if first.key == "Yesterday" { return true }
            if second.key == "Yesterday" { return false }
            
            // Compare by first entry's timestamp
            guard let firstDate = first.value.first?.timestamp,
                  let secondDate = second.value.first?.timestamp else {
                return false
            }
            return firstDate > secondDate
        }
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if entries.isEmpty {
                    emptyStateView
                } else {
                    logEntriesList
                }
            }
            .navigationTitle("Daily Log")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddEntry = true
                    } label: {
                        Label("Add Entry", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddEntry) {
                AddLogEntryView()
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 70))
                .foregroundStyle(.gray)
            
            Text("No Log Entries Yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                Text("Take a photo or video and AI will automatically detect what you're doing")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.caption)
                    Text("Powered by on-device machine learning")
                        .font(.caption)
                }
                .foregroundStyle(.blue)
            }
            .padding(.horizontal, 40)
            
            Button {
                showingAddEntry = true
            } label: {
                Label("Add Your First Entry", systemImage: "plus.circle.fill")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .padding(.top)
        }
    }
    
    private var logEntriesList: some View {
        List {
            ForEach(groupedEntries, id: \.0) { section in
                Section {
                    ForEach(section.1) { entry in
                        NavigationLink(destination: LogEntryDetailView(entry: entry)) {
                            LogEntryRow(entry: entry)
                        }
                    }
                    .onDelete { offsets in
                        deleteEntries(in: section.1, at: offsets)
                    }
                } header: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(section.0)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .textCase(nil)
                        
                        // Category checkboxes
                        CategoryCheckboxes(entries: section.1)
                        
                        // Compile My Day button
                        ShareDayButton(dateTitle: section.0, entries: section.1)
                    }
                }
            }
        }
    }
    
    private func deleteEntries(in section: [LogEntry], at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(section[index])
        }
    }
}

struct ShareDayButton: View {
    let dateTitle: String
    let entries: [LogEntry]
    @State private var showingShareDay = false
    
    var body: some View {
        Button {
            showingShareDay = true
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "video.badge.plus")
                    .font(.caption)
                Text("Compile My Day")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.blue)
            .clipShape(Capsule())
        }
        .sheet(isPresented: $showingShareDay) {
            ShareDayView(dateTitle: dateTitle, entries: entries)
        }
    }
}

struct CategoryCheckboxes: View {
    let entries: [LogEntry]
    
    private var hasWorkout: Bool {
        entries.contains { $0.category == .workout }
    }
    
    private var hasFood: Bool {
        entries.contains { $0.category == .food }
    }
    
    private var hasSupplements: Bool {
        entries.contains { $0.category == .supplements }
    }
    
    var body: some View {
        HStack(spacing: 16) {
            CategoryCheckbox(
                category: .workout,
                isChecked: hasWorkout
            )
            
            CategoryCheckbox(
                category: .food,
                isChecked: hasFood
            )
            
            CategoryCheckbox(
                category: .supplements,
                isChecked: hasSupplements
            )
        }
        .padding(.top, 4)
    }
}

struct CategoryCheckbox: View {
    let category: WellnessCategory
    let isChecked: Bool
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: isChecked ? "checkmark.square.fill" : "square")
                .foregroundStyle(isChecked ? category.color : .secondary)
                .font(.body)
            
            HStack(spacing: 4) {
                Image(systemName: category.icon)
                    .font(.caption)
                Text(category.rawValue)
                    .font(.caption)
            }
            .foregroundStyle(isChecked ? category.color : .secondary)
        }
    }
}

struct LogEntryRow: View {
    let entry: LogEntry
    
    var body: some View {
        HStack(spacing: 12) {
            if entry.mediaType == .photo, let image = entry.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else if entry.mediaType == .video, let mediaData = entry.mediaData {
                // Create temporary URL for video thumbnail
                if let tempURL = createTempVideoURL(from: mediaData) {
                    VideoThumbnailView(videoURL: tempURL)
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    videoPlaceholder
                }
            } else {
                mediaPlaceholder
            }
            
            VStack(alignment: .leading, spacing: 6) {
                // Category as main title
                HStack(spacing: 8) {
                    Image(systemName: entry.category.icon)
                        .font(.body)
                        .foregroundStyle(entry.category.color)
                    
                    Text(entry.category.rawValue)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    if entry.mediaType == .video {
                        Image(systemName: "video.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                // Timestamp as subtitle
                Text(entry.timestamp.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var videoPlaceholder: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color(.systemGray5))
            .frame(width: 80, height: 80)
            .overlay {
                Image(systemName: "video")
                    .foregroundStyle(.gray)
            }
    }
    
    private var mediaPlaceholder: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color(.systemGray5))
            .frame(width: 80, height: 80)
            .overlay {
                Image(systemName: "photo")
                    .foregroundStyle(.gray)
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
}

#Preview {
    ContentView()
        .modelContainer(for: LogEntry.self, inMemory: true)
}
