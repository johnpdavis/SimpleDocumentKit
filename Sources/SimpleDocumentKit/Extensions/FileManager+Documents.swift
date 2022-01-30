//
//  FileManager+Documents.swift
//  DocumentKit
//
//  Created by Overview on 3/6/19.
//  Copyright © 2019 John Davis. All rights reserved.
//

import Foundation
#if !os(macOS)
import UIKit
#endif

extension FileManager {
    
}

// MARK: - Coordinated Document Removal
// Note: These methods could be static but are not. This is to support FileManager's delegate being invoked for the wrapped FileManager calls like `removeFile` if the developer chose to use a non-default FileManager
extension FileManager {
    
    /// Attempt to remove Document via URL. Document will be closed if it's open. If close fails removal will not be attempted.
    ///
    /// - Parameters:
    ///   - document: Document to optionally close and attempt to delete
    public func removeDocument(_ document: UIDocument) async throws {
        print("removeDocument - State: \(await document.documentStateString)")
        
        let documentClosed = await document.documentState.contains(.closed)
        if !documentClosed  {
            // If document is not closed. Close it first.
            let success = await document.close()
            
            // If we try to close, and fail, we want to throw an error and not attmept deletion.
            if !success {
                throw SmartDocumentError.unableToClose
            }
        }
        
        try await removeFile(at: document.fileURL)
    }
    
    
    /// Attempts to remove file at URL by wrapping the removal in an NSFileCoordinator with options .forDeleting. Will not attempt to close the file. This should be done before invoking this method.
    ///
    /// - Parameters:
    ///   - URL: URL of file to attempt removal of
    ///   - completion: Completion block to be invoked after removal completes or fails. Will be invoked on main queue.
    func removeFile(at url: URL) async throws {
        func coordinateRemovalOfFile(URL: URL) async throws {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) -> Void in
                let coordinator = NSFileCoordinator(filePresenter: nil)
                coordinator.coordinate(writingItemAt: URL, options: .forDeleting, error: nil) { URL in
                    do {
                        try FileManager.default.removeItem(at: URL)
                        continuation.resume()
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
        
        try await coordinateRemovalOfFile(URL: url)
    }
}

// MARK: - Coordinated URL Move
// Note: These methods could be static but are not. This is to support FileManager's delegate being invoked for the wrapped FileManager calls like `moveItem` if the developer chose to use a non-default FileManager
extension FileManager {
    /// Attempt to move a Ubiquitous file from one url to another. This method will inform and use an NSFileCoordinator of the move.
    ///
    /// - Parameters:
    ///   - currentURL: Current location of file to move
    ///   - newURL: New location to move file to
    ///   - completion: Completion block to invoke when file move is complete. Will be invoked on the main thread.
    public func moveUbiquitousItem(at currentURL: URL, to newURL: URL) async throws {
        
        func coordinateMoveFile(at currentURL: URL, to newURL: URL) async throws {
            var error: NSError? = nil
            let coordinator = NSFileCoordinator(filePresenter: nil)
            
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                coordinator.coordinate(writingItemAt: currentURL, options: .forMoving, writingItemAt: newURL, options: .forReplacing, error: &error) { [weak self, error] currentURL, newURL in
                    guard let self = self else { return }
                    if let error = error {
                        print("Error with coordinator: \(error)")
                        continuation.resume(throwing: error)
                    }
                    
                    do {
                        coordinator.item(at: currentURL, willMoveTo: newURL)
                        try self.moveItem(at: currentURL, to: newURL)
                        coordinator.item(at: currentURL, didMoveTo: newURL)
                        continuation.resume()
                    } catch {
                        print("Failed to move file: \(error.localizedDescription)")
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
        
        try await coordinateMoveFile(at: currentURL, to: newURL)
    }
}

