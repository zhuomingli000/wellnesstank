//
//  MultiMediaPicker.swift
//  WellnessTank
//
//  Created by Zhuoming Li on 11/15/25.
//

import SwiftUI
import PhotosUI

struct SelectedMediaItem: Identifiable, Equatable {
    let id = UUID()
    let image: UIImage?
    let videoURL: URL?
    
    static func == (lhs: SelectedMediaItem, rhs: SelectedMediaItem) -> Bool {
        lhs.id == rhs.id
    }
}

struct MultiMediaPicker: UIViewControllerRepresentable {
    @Binding var selectedItems: [SelectedMediaItem]
    @Binding var isPresented: Bool
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.selectionLimit = 0 // 0 means unlimited
        config.filter = .any(of: [.images, .videos])
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: MultiMediaPicker
        
        init(_ parent: MultiMediaPicker) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.isPresented = false
            
            guard !results.isEmpty else { 
                print("MultiMediaPicker: No results selected")
                return 
            }
            
            print("MultiMediaPicker: Processing \(results.count) items")
            
            let group = DispatchGroup()
            var newItems: [SelectedMediaItem] = []
            let lock = NSLock()
            
            for result in results {
                // Check if it's a video
                if result.itemProvider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
                    group.enter()
                    result.itemProvider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { url, error in
                        defer { group.leave() }
                        
                        guard let url = url, error == nil else { 
                            print("MultiMediaPicker: Error loading video: \(error?.localizedDescription ?? "unknown")")
                            return 
                        }
                        
                        // Copy to temp location
                        let tempURL = FileManager.default.temporaryDirectory
                            .appendingPathComponent(UUID().uuidString + ".mov")
                        
                        do {
                            try FileManager.default.copyItem(at: url, to: tempURL)
                            let item = SelectedMediaItem(image: nil, videoURL: tempURL)
                            lock.lock()
                            newItems.append(item)
                            lock.unlock()
                            print("MultiMediaPicker: Added video item")
                        } catch {
                            print("MultiMediaPicker: Error copying video: \(error)")
                        }
                    }
                }
                // Check if it's an image
                else if result.itemProvider.canLoadObject(ofClass: UIImage.self) {
                    group.enter()
                    result.itemProvider.loadObject(ofClass: UIImage.self) { image, error in
                        defer { group.leave() }
                        
                        if let image = image as? UIImage {
                            let item = SelectedMediaItem(image: image, videoURL: nil)
                            lock.lock()
                            newItems.append(item)
                            lock.unlock()
                            print("MultiMediaPicker: Added image item")
                        } else {
                            print("MultiMediaPicker: Error loading image: \(error?.localizedDescription ?? "unknown")")
                        }
                    }
                }
            }
            
            group.notify(queue: .main) {
                print("MultiMediaPicker: Finished loading all items. Total: \(newItems.count)")
                self.parent.selectedItems = newItems
            }
        }
    }
}

