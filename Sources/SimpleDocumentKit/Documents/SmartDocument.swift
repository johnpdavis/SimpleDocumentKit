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

    private var docStateObserver: AnyObject?
    private var transfering: Bool = false
    
    /// Transfer progress of Document
    public var loadProgress = Progress(totalUnitCount: 10)
    
    /// To prevent spamming of the document state if it has not changed, we maintain the previous state to compare it to.
    private var previousDocumentState: UIDocument.State = []
    
    public override init(fileURL url: URL) {
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
            delegate?.smartDocumentUpdatedContent(self)
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
            self.delegate?.smartDocumentDeletedOnOtherDevice(self)
        } catch {
            self.delegate?.smartDocumentDeletedOnOtherDevice(self)
            throw error
        }
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
    
    open override func handleError(_ error: Error, userInteractionPermitted: Bool) {
        super.handleError(error, userInteractionPermitted: userInteractionPermitted)
        
        print(error)
    }
}
