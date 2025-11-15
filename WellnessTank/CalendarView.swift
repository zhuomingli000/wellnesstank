//
//  CalendarView.swift
//  WellnessTank
//
//  Created by Zhuoming Li on 11/15/25.
//

import SwiftUI
import SwiftData

struct CalendarView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LogEntry.timestamp, order: .reverse) private var entries: [LogEntry]
    
    @State private var selectedDate = Date()
    @State private var currentMonth = Date()
    
    private var selectedDateEntries: [LogEntry] {
        let calendar = Calendar.current
        return entries.filter { entry in
            calendar.isDate(entry.timestamp, inSameDayAs: selectedDate)
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Month Navigation
                HStack {
                    Button {
                        currentMonth = Calendar.current.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.title3)
                            .foregroundStyle(.primary)
                    }
                    
                    Spacer()
                    
                    Text(currentMonth.formatted(.dateTime.month(.wide).year()))
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Button {
                        currentMonth = Calendar.current.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.title3)
                            .foregroundStyle(.primary)
                    }
                }
                .padding()
                
                // Calendar Grid
                CalendarGridView(
                    currentMonth: currentMonth,
                    selectedDate: $selectedDate,
                    entries: entries
                )
                
                Divider()
                    .padding(.vertical)
                
                // Selected Date Details
                VStack(alignment: .leading, spacing: 16) {
                    Text(selectedDate.formatted(date: .complete, time: .omitted))
                        .font(.headline)
                    
                    if selectedDateEntries.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "calendar.badge.exclamationmark")
                                .font(.system(size: 40))
                                .foregroundStyle(.secondary)
                            Text("No activities logged on this day")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else {
                        ScrollView {
                            VStack(spacing: 12) {
                                ForEach(selectedDateEntries) { entry in
                                    NavigationLink(destination: LogEntryDetailView(entry: entry)) {
                                        CompactLogEntryRow(entry: entry)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(Color(.systemGroupedBackground))
            }
            .navigationTitle("Calendar")
        }
    }
}

struct CalendarGridView: View {
    let currentMonth: Date
    @Binding var selectedDate: Date
    let entries: [LogEntry]
    
    private let daysOfWeek = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    private let columns = Array(repeating: GridItem(.flexible()), count: 7)
    
    private var monthDays: [Date] {
        guard let monthInterval = Calendar.current.dateInterval(of: .month, for: currentMonth),
              let monthFirstWeek = Calendar.current.dateInterval(of: .weekOfMonth, for: monthInterval.start) else {
            return []
        }
        
        var dates: [Date] = []
        var date = monthFirstWeek.start
        
        while date < monthInterval.end {
            dates.append(date)
            guard let nextDate = Calendar.current.date(byAdding: .day, value: 1, to: date) else { break }
            date = nextDate
        }
        
        // Fill remaining days to complete the grid
        let remainingDays = 42 - dates.count
        for i in 0..<remainingDays {
            if let nextDate = Calendar.current.date(byAdding: .day, value: i + 1, to: dates.last!) {
                dates.append(nextDate)
            }
        }
        
        return dates
    }
    
    private func categoriesForDate(_ date: Date) -> Set<WellnessCategory> {
        let calendar = Calendar.current
        let dateEntries = entries.filter { entry in
            calendar.isDate(entry.timestamp, inSameDayAs: date)
        }
        return Set(dateEntries.map { $0.category })
    }
    
    private func isInCurrentMonth(_ date: Date) -> Bool {
        Calendar.current.isDate(date, equalTo: currentMonth, toGranularity: .month)
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Day headers
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(daysOfWeek, id: \.self) { day in
                    Text(day)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)
            
            // Calendar days
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(monthDays, id: \.self) { date in
                    CalendarDayCell(
                        date: date,
                        isSelected: Calendar.current.isDate(date, inSameDayAs: selectedDate),
                        isInCurrentMonth: isInCurrentMonth(date),
                        isToday: Calendar.current.isDateInToday(date),
                        categories: categoriesForDate(date)
                    )
                    .onTapGesture {
                        selectedDate = date
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

struct CalendarDayCell: View {
    let date: Date
    let isSelected: Bool
    let isInCurrentMonth: Bool
    let isToday: Bool
    let categories: Set<WellnessCategory>
    
    var body: some View {
        VStack(spacing: 4) {
            Text("\(Calendar.current.component(.day, from: date))")
                .font(.body)
                .fontWeight(isToday ? .bold : .regular)
                .foregroundStyle(
                    isSelected ? .white :
                    isToday ? .blue :
                    isInCurrentMonth ? .primary : .secondary
                )
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(isSelected ? Color.blue : Color.clear)
                )
                .overlay(
                    Circle()
                        .stroke(isToday && !isSelected ? Color.blue : Color.clear, lineWidth: 2)
                )
            
            // Category indicators
            HStack(spacing: 2) {
                ForEach([WellnessCategory.workout, .food, .supplements], id: \.self) { category in
                    Circle()
                        .fill(categories.contains(category) ? category.color : Color.clear)
                        .frame(width: 5, height: 5)
                }
            }
        }
        .frame(height: 50)
        .opacity(isInCurrentMonth ? 1.0 : 0.3)
    }
}

struct CompactLogEntryRow: View {
    let entry: LogEntry
    
    var body: some View {
        HStack(spacing: 12) {
            // Category Icon
            Image(systemName: entry.category.icon)
                .font(.title3)
                .foregroundStyle(entry.category.color)
                .frame(width: 40, height: 40)
                .background(entry.category.color.opacity(0.15))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.category.rawValue)
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Text(entry.activityDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                
                Text(entry.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            
            Spacer()
            
            if entry.mediaType == .video {
                Image(systemName: "video.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

#Preview {
    CalendarView()
        .modelContainer(for: LogEntry.self, inMemory: true)
}

