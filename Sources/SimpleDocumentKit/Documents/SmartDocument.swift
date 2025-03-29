//
//  SmartDocument.swift
//  DocumentKit
//
//  Created by Overview on 2/19/19.
//  Copyright © 2019 John Davis. All rights reserved.
// Includes functionality from Apple's DocumentBrowser document sample application.
//

#if !os(macOS)
import UIKit
#endif
import Combine

/// Error that can be thrown by a SmartDocument Object
///
/// - unableToParseData: Thrown if the document can't parse its internal data
/// - unableToEncodeData: Thrown if the document can't encode it's new data
/// - unableToRemove: Thrown if the document fails to remove itself from the file system
public enum SmartDocumentError: Error {
    case documentNotLoaded
    case unableToParseData
    case unableToEncodeData
    case unableToSave
    case unableToClose
}

public enum SmartDocumentEvent {
    case editingEnabled
    case editingDisabled
    case documentClosed
    case contentUpdated
    case transferBegan
    case transferEnded
    case saveFailed
    case conflictsDetected
    case deletedOnOtherDevice
}


/// Smart document registers for its parents document change events, and delegates these events via a `SmartDocumentDelegate`.
open class SmartDocument: UIDocument {
    
    /// Delegate to receive document state change callbacks
    private let _documentEventSubject = PassthroughSubject<SmartDocumentEvent, Never>()
    private var documentEventPublisher: any Publisher<SmartDocumentEvent, Never> {
        _documentEventSubject.eraseToAnyPublisher()
    }

    private var docStateObserver: AnyObject?
    private var transfering: Bool = false
    
    /// Transfer progress of Document
    public var loadProgress = Progress(totalUnitCount: 10)
    
    /// To prevent spamming of the document state if it has not changed, we maintain the previous state to compare it to.
    private var previousDocumentState: UIDocument.State = []
    
    public override required init(fileURL url: URL) {
        docStateObserver = nil
        super.init(fileURL: url)
        
        docStateObserver = NotificationCenter.default.addObserver(forName: UIDocument.stateChangedNotification, object: self, queue: OperationQueue.main) { [weak self] _ in
                guard let self = self else {
                    return
                }
                
                self.processDocumentState(self.documentState)
        }
    }
    
    deinit {
        if let docObserver = docStateObserver {
            NotificationCenter.default.removeObserver(docObserver)
        }
    }
    
    // MARK: - Lifecycle
    
    /// Update the change counter by indicating the kind of change.
    ///
    /// Overrides UIDocument's change count to invoke the delegate's `smartDocumentUpdatedContent` method when the change == done
    ///
    /// - Parameter change: A constant that indicates whether a change has been made, cleared, undone, or redone. See `UIDocument.ChangeKind` for more information.
    public override func updateChangeCount(_ change: UIDocument.ChangeKind) {
        super.updateChangeCount(change)
        
        print("Change: \(change)")

        if change == .done {
            _documentEventSubject.send(.contentUpdated)
        }
    }
    
    /// Convenience method to close a document.
    public func safeClose() async throws {
        guard !documentState.contains(.closed) else {
            return
        }
        
        let closed = await self.close()
        
        if !closed {
            throw SmartDocumentError.unableToClose
        }
    }
    
    /// Convenience method to force an autosave and close a document.
    ///
    /// This method will autosave the document and close it if it's open afterward
    public func autoSaveAndClose() async throws {
        guard await autosave() else {
            throw SmartDocumentError.unableToSave
        }
        
        try await safeClose()
    }
    
    open override func accommodatePresentedItemDeletion() async throws {
        do {
            try await autoSaveAndClose()
            _documentEventSubject.send(.deletedOnOtherDevice)
        } catch {
            _documentEventSubject.send(.deletedOnOtherDevice)
            throw error
        }
    }
}

// MARK: - Private Methods

extension SmartDocument {
    
    func processDocumentState(_ documentState: UIDocument.State) {
        
        if documentState == .normal {
            print("=> Document entered normal state")
            _documentEventSubject.send(.editingEnabled)
        }
        
        if documentState.contains(.closed) && !previousDocumentState.contains(.closed) {
            print("=> Document has closed")
            _documentEventSubject.send(.documentClosed)
        }
        
        if documentState.contains(.editingDisabled) && !previousDocumentState.contains(.editingDisabled) {
            print("=> Document's editing is disabled")
            _documentEventSubject.send(.editingEnabled)
        }
        
        if documentState.contains(.inConflict) && !previousDocumentState.contains(.inConflict) {
            print("=> Document conflicts were detected")
            _documentEventSubject.send(.conflictsDetected)
        }
        
        if documentState.contains(.savingError) && !previousDocumentState.contains(.savingError) {
            print("=> Document has a saving error")
            _documentEventSubject.send(.saveFailed)
        }
        
        handleDocStateForTransfers(documentState)
        
        previousDocumentState = documentState
    }
    
    func handleDocStateForTransfers(_ documentState: UIDocument.State) {
        if transfering {
            // If we're in the middle of a transfer, check to see if the transfer has ended.
            if !documentState.contains(.progressAvailable) {
                print("=> A transfer Ended")
                transfering = false
                _documentEventSubject.send(.transferEnded)
            }
        } else {
            // If we're not in the middle of a transfer, check to see if a transfer has started.
            if documentState.contains(.progressAvailable) {
                print("=> A transfer is in progress")
                transfering = true
                _documentEventSubject.send(.transferBegan)
            }
        }
    }
    
    open override func handleError(_ error: Error, userInteractionPermitted: Bool) {
        super.handleError(error, userInteractionPermitted: userInteractionPermitted)
        
        print(error)
    }
}
