//
//  MainTabView.swift
//  WellnessTank
//
//  Created by Zhuoming Li on 11/15/25.
//

import SwiftUI
import SwiftData

struct MainTabView: View {
    @StateObject private var feedStore = SharedFeedStore()
    
    var body: some View {
        TabView {
            ContentView()
                .tabItem {
                    Label("Daily Log", systemImage: "book.fill")
                }
            
            CalendarView()
                .tabItem {
                    Label("Calendar", systemImage: "calendar")
                }
            
            ExploreView()
                .tabItem {
                    Label("Explore", systemImage: "globe")
                }
        }
        .environmentObject(feedStore)
    }
}

#Preview {
    MainTabView()
        .modelContainer(for: LogEntry.self, inMemory: true)
        .environmentObject(SharedFeedStore())
}


