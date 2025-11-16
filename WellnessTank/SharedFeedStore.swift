//
//  SharedFeedStore.swift
//  WellnessTank
//
//  Created by Zhuoming Li on 11/16/25.
//

import Foundation
import Combine

@MainActor
final class SharedFeedStore: ObservableObject {
    @Published private(set) var entries: [SharedEntry]
    
    init(initialEntries: [SharedEntry] = []) {
        self.entries = initialEntries
    }
    
    func add(entry: SharedEntry) {
        entries.insert(entry, at: 0)
    }
}


