//
//  SmartDocument.swift
//  DocumentKit
//
//  Created by Overview on 2/19/19.
//  Copyright © 2019 John Davis. All rights reserved.
// Includes functionality from Apple's DocumentBrowser document sample application.
//

import Combine
#if !os(macOS)
import UIKit
#endif

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


/// Delegate to receive events related to the document's state changing.
public protocol SmartDocumentDelegate: AnyObject {
    func smartDocumentEnableEditing(_ doc: SmartDocument)
    func smartDocumentDisableEditing(_ doc: SmartDocument)
    func smartDocumentUpdatedContent(_ doc: SmartDocument)
    func smartDocumentTransferBegan(_ doc: SmartDocument)
    func smartDocumentTransferEnded(_ doc: SmartDocument)
    func smartDocumentSaveFailed(_ doc: SmartDocument)
    func smartDocumentHasConflicts(_ doc: SmartDocument)
    func smartDocumentDeletedOnOtherDevice(_ doc: SmartDocument)
}

/// Smart document registers for its parents document change events, and delegates these events via a `SmartDocumentDelegate`.
open class SmartDocument: UIDocument {
    
    /// Delegate to receive document state change callbacks
    public weak var delegate: SmartDocumentDelegate?

    private var transfering: Bool = false
    
    /// Transfer progress of Document
    public var loadProgress = Progress(totalUnitCount: 10)
    
    /// To prevent spamming of the document state if it has not changed, we maintain the previous state to compare it to.
    private var previousDocumentState: UIDocument.State = []
    
    private var cancellables = Set<AnyCancellable>()
    
    public override init(fileURL url: URL) {
        super.init(fileURL: url)
        
        NotificationCenter.default
            .publisher(for: UIDocument.stateChangedNotification)
            .receive(on: OperationQueue.main)
            .sink(receiveValue: { _ in
                Task { @MainActor in
                    self.processDocumentState(self.documentState)
                }
            })
            .store(in: &cancellables)
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
            delegate?.smartDocumentUpdatedContent(self)
        }
    }
    
    /// Convenience method to close a document.
    public func safeClose() async throws {
        if !self.documentState.contains(.closed) {
            let closeSuccess = await self.close()
            
            if closeSuccess {
                return
            }
            else {
                throw SmartDocumentError.unableToClose
            }
        } else {
            return
        }
    }
    
    /// Convenience method to force an autosave and close a document.
    ///
    /// This method will autosave the document and close it if it's open afterward
    public func autoSaveAndClose() async throws {
        let autosaveSuccess = await autosave()
        if autosaveSuccess {
            try await self.safeClose()
        } else {
            throw SmartDocumentError.unableToSave
        }
    }
    
    /// Upon being informed that our file will be deleted by a file coordinator, we need to force an autosave so the autosave engine doesnt re-write the file after its been removed.
    open override func accommodatePresentedItemDeletion() async throws {
        try await autoSaveAndClose()
        delegate?.smartDocumentDeletedOnOtherDevice(self)
    }
}

// MARK: - Private Methods

extension SmartDocument {
    
    func processDocumentState(_ documentState: UIDocument.State) {
        
        if documentState == .normal {
            print("=> Document entered normal state")
            delegate?.smartDocumentEnableEditing(self)
        }
        
        if documentState.contains(.closed) && !previousDocumentState.contains(.closed) {
            print("=> Document has closed")
            delegate?.smartDocumentDisableEditing(self)
        }
        
        if documentState.contains(.editingDisabled) && !previousDocumentState.contains(.editingDisabled) {
            print("=> Document's editing is disabled")
            delegate?.smartDocumentDisableEditing(self)
        }
        
        if documentState.contains(.inConflict) && !previousDocumentState.contains(.inConflict) {
            print("=> Document conflicts were detected")
            delegate?.smartDocumentHasConflicts(self)
        }
        
        if documentState.contains(.savingError) && !previousDocumentState.contains(.savingError) {
            print("=> Document has a saving error")
            delegate?.smartDocumentSaveFailed(self)
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
                delegate?.smartDocumentTransferEnded(self)
            }
        } else {
            // If we're not in the middle of a transfer, check to see if a transfer has started.
            if documentState.contains(.progressAvailable) {
                print("=> A transfer is in progress")
                transfering = true
                delegate?.smartDocumentTransferBegan(self)
            }
        }
    }
}
