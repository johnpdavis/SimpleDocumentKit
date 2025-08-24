//
//  ComposableDocumentManager.swift
//  
//
//  Created by John Davis on 2/6/22.
//

import Combine
import Foundation
import SwiftUI

enum ManagedDocumentManagerError: Error {
    case documentURLInvalid
    case unableToRetrieveURL
    case unableToSaveNewDocument
    case unableToReadMetaData
}

public typealias ManageableDocument = SmartDocument & ManageableMetaDataContaining

class ManagedDocumentsLoader<DOCUMENT: ManageableDocument> {
    func loadDocuments(from urls: [URL]) async -> [DOCUMENT] {
        return await withTaskGroup(of: DOCUMENT?.self, returning: [DOCUMENT].self) { taskGroup in
            var results: [DOCUMENT] = []
            
            for url in urls {
                _ = taskGroup.addTaskUnlessCancelled {
                    let document = await DOCUMENT(fileURL: url)
                    
                    return document
                }
            }
            
            for await loadedDocument in taskGroup {
                loadedDocument.flatMap { results.append($0) }
            }
            
            return results
        }
    }
    
    static func coordinatedDocumentOpen(at fileURL: URL) async -> DOCUMENT? {
        do {
            let document: DOCUMENT = try await withCheckedThrowingContinuation { continuation in
                let coordinator = NSFileCoordinator(filePresenter: nil)
                var coordinatorError: NSError?
                
                coordinator.coordinate(readingItemAt: fileURL, error: &coordinatorError) { [coordinatorError] newURL in
                    if let coordinatorError {
                        continuation.resume(throwing: coordinatorError)
                    }
                    
                    Task { @MainActor in
                        let document = DOCUMENT(fileURL: newURL)
                        let didOpen = await document.open()
                        if !didOpen {
                            continuation.resume(throwing: ManagedDocumentManagerError.documentURLInvalid)
                        }
                        continuation.resume(returning: document)
                    }
                }
            }
            
            return document
        } catch {
            return nil
        }
    }
}

@MainActor
public class ManagedDocumentManager<DOCUMENT: ManageableDocument>: ObservableObject {
    
    private let documentDirectoryName: String
    private let ubiquityContainerIdentifier: String
    
    public let managedDocumentDirectory: URL
    public let managedDocumentExtension: String
    
    let localDocumentManager: LocalDocumentManager
    let cloudDocumentManager: CloudDocumentManager
    
    private var localDocumentSubscriber: AnyCancellable?
    private var cloudDocumentSubscriber: AnyCancellable?
    
    @Published public var localDocuments: [DOCUMENT] = []
    @Published public var cloudDocuments: [DOCUMENT] = []
    
    @Published public var initialLocalScanComplete: Bool = false
    @Published public var initialCloudScanComplete: Bool = false
    
    private var isListeningForUpdates: Bool
    
    public init(localDocumentRoot: URL,
                documentDirectoryName: String,
                managedDocumentExtension: String,
                ubiquityContainerIdentifier: String,
                listenForFileSystemUpdates: Bool = true,
                initializeiCloudAccess: Bool = true) {
        self.documentDirectoryName = documentDirectoryName
        self.managedDocumentDirectory = localDocumentRoot.appendingPathComponent(documentDirectoryName, isDirectory: true)
        self.managedDocumentExtension = managedDocumentExtension
        self.ubiquityContainerIdentifier = ubiquityContainerIdentifier
        
        self.localDocumentManager = LocalDocumentManager(localDocumentRoot: managedDocumentDirectory,
                                                         documentExtension: managedDocumentExtension)
        self.cloudDocumentManager = CloudDocumentManager(ubiquityContainerIdentifier: ubiquityContainerIdentifier,
                                                         localDocumentRoot: managedDocumentDirectory,
                                                         documentExtension: managedDocumentExtension)
        
        self.isListeningForUpdates = listenForFileSystemUpdates
        
        if listenForFileSystemUpdates {
            initializeLocalDocManager()
            initializeCloudDocManager()
        }
        
        Task {
            if initializeiCloudAccess {
                let (success, containerURL) = await cloudDocumentManager.initializeiCloudAccess()
                print("\(success) - \(String(describing: containerURL))")
            }
        }
    }
    
    private func initializeCloudDocManager() {
        cloudDocumentSubscriber = self.cloudDocumentManager.documentsUpdatedPublisher
            .debounce(for: 0.2, scheduler: DispatchQueue.main)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] result in
                print("Received Cloud result: \(result)")
                self?.processCloudResult(result)
                self?.initialCloudScanComplete = true
            }
        
        cloudDocumentManager.startQueryingDocuments()
    }
    
    private func initializeLocalDocManager() {
        localDocumentSubscriber = localDocumentManager.documentsUpdatedPublisher
            .debounce(for: 0.2, scheduler: DispatchQueue.main)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] result in
                print("Received Local result: \(result)")
                self?.processLocalResult(result)
                self?.initialLocalScanComplete = true
            }
        
        localDocumentManager.startQueryingDocuments()
    }
    
    public func scaniCloudOptIn(promptForOptIn:@escaping (() -> ())) async {
        await cloudDocumentManager.scaniCloudOptIn(promptForOptIn: promptForOptIn)
    }
    
    func processLocalResult(_ result: DocumentQueryCoordinator.DocumentsUpdatedResult) {
        do {
            let list = try ManagedDocumentManager.processResult(result, currentResults: localDocuments)
            localDocuments = list
        } catch {
            print("processing failed: \(error)")
        }
    }
    
    func processCloudResult(_ result: DocumentQueryCoordinator.DocumentsUpdatedResult) {
        do {
            let list = try ManagedDocumentManager.processResult(result, currentResults: cloudDocuments)
            cloudDocuments = list
        } catch {
            print("processing failed: \(error)")
        }
    }

    static func processResult(_ result: DocumentQueryCoordinator.DocumentsUpdatedResult, currentResults: [DOCUMENT]) throws -> [DOCUMENT] {
        switch result {
        case .failure(let error):
            print("Received Document Failure: \(error)")
            throw error
        case .success(let docURLs):
            print("Received Document URLs - \(docURLs.added.count) Added -  \(docURLs.present.count) present -  \(docURLs.removed.count) Removed")
            
            // Initialed with currently known state
            var newURLsToDocs:[URL: DOCUMENT] = currentResults.reduce(into: [:]) { result, new in
                result[new.fileURL] = new
            }
            
            // Remove the removed docs from the current dictionary
            docURLs.removed.forEach { newURLsToDocs.removeValue(forKey: $0) }
            
            // Add the added URLS if they are not present
            docURLs.added.forEach { addedURL in
                if newURLsToDocs[addedURL] == nil {
                    newURLsToDocs[addedURL] = DOCUMENT(fileURL: addedURL)
                }
            }
            
            // Add the present URLs if they are not already present
            docURLs.present.forEach { presentURL in
                if newURLsToDocs[presentURL] == nil {
                    newURLsToDocs[presentURL] = DOCUMENT(fileURL: presentURL)
                }
            }
            
            let documents = Array(newURLsToDocs.values)
            let sortedDocuments = documents.sorted {
                let firstName = $0.fileURL.lastPathComponent
                let secondName = $1.fileURL.lastPathComponent
                return firstName.localizedCaseInsensitiveCompare(secondName) == .orderedAscending
            }
            
            return sortedDocuments
        }
    }
    
    /// URL for document with provided name.
    ///
    /// - Parameter name: Name of document with extension
    /// - Returns: returns URL of document, or nil, if it could not be found or created
    public func urlForDocument(name: String) -> URL? {
        if ICloudDefaults.standard.iCloudOn {
            return cloudDocumentManager.iCloudURLForDocument(filename: name)
        } else {
            return managedDocumentDirectory.appendingPathComponent(name)
        }
    }
    
    func dedupedFileName(basename: String, increment: Int, ext: String) -> String {
        let fullName = if increment > 0 {
            "\(basename) \(increment)"
        } else {
            basename
        }
        
        return [fullName, ext].joined(separator: ".")
    }
    
    /// Will attempt to return a Document with the provided name. This method will look in the designated storage area, iCloud or Local, depending on the app's settings. If the file does not exist, it will be created.
    ///
    /// - Parameters:
    ///   - name: Name of package with extension
    public func createDocument(fileName_base: String, metaData: DOCUMENT.METADATA) async throws -> DOCUMENT {
        var baseNameIncrement: Int = 0
        var newDocumentName: String!
        while newDocumentName == nil {
            let newName = dedupedFileName(basename: fileName_base, increment: baseNameIncrement, ext: managedDocumentExtension)
            if documentExistsWithName(newName) {
                baseNameIncrement += 1
            } else {
                newDocumentName = newName
            }
        }
        
        guard let url = urlForDocument(name: newDocumentName) else { throw ManagedDocumentManagerError.unableToRetrieveURL }
        let document = DOCUMENT(fileURL: url)
        document.initMetaDataForDocumentCreation(metaData: metaData)
        if await document.save(to: url, for: .forCreating) {
            await document.close()
            return document
        } else {
            print("FAILED TO SAVE FILE")
            await document.close()
            throw ManagedDocumentManagerError.unableToSaveNewDocument
        }
    }
    
    /// Will change document name by invoking move
    ///
    /// - Parameters:
    ///   - document: Document to move to newly named URL
    ///   - name: New name of document including extension
    public func renameDocument(document: DOCUMENT, name: String) async throws {
        try await document.autoSaveAndClose()
        
        guard name != document.fileURL.lastPathComponent else {
            // Can't rename to same name
            throw ManagedDocumentManagerError.documentURLInvalid
        }
        
        guard !documentExistsWithName(name) else {
            throw ManagedDocumentManagerError.documentURLInvalid
        }

        guard let newURL = urlForDocument(name: name) else {
            throw ManagedDocumentManagerError.unableToRetrieveURL
        }
  
        try await FileManager.moveUbiquitousItem(at: document.fileURL, to: newURL)
    }
    
    
    public nonisolated func removeDocument(_ document: DOCUMENT) async throws {
        try await document.autoSaveAndClose()
        let fileURL = await document.fileURL
        
        let _: Void = try await withCheckedThrowingContinuation { continuation in
            let coordinator = NSFileCoordinator(filePresenter: document)
            var coordinatorError: NSError?
            coordinator.coordinate(writingItemAt: fileURL, options: .forDeleting, error: &coordinatorError) { [coordinatorError] url in
                if let coordinatorError {
                    continuation.resume(throwing: coordinatorError)
                    return
                }
                
                do {
                    try FileManager.default.removeItem(at: url)
                } catch {
                    continuation.resume(throwing: error)
                    return
                }
                
                continuation.resume(returning: ())
            }
        }
    }
    
    /// Will create the full document URL by invoking `urlForDocument(name:)` and ask NSFileManager if the URL exists.
    ///
    /// - Parameter name: Full name of document including extension.
    /// - Returns: True of document exists. Otherwise false.
    public func documentExistsWithName(_ name: String) -> Bool {
        guard let fullFileURL = urlForDocument(name: name) else { fatalError("Cannot construct full Document file URL") }
        
        return FileManager.default.fileExists(atPath:fullFileURL.path)
    }
    
    public func documentForURL(_ url: URL) -> DOCUMENT? {
        // Initialed with currently known state
        let localDocs:[URL: DOCUMENT] = localDocuments.reduce(into: [:]) { result, new in
            result[new.fileURL] = new
        }
        
        let cloudDocs:[URL: DOCUMENT] = cloudDocuments.reduce(into: [:]) { result, new in
            result[new.fileURL] = new
        }
        
        return localDocs[url] ?? cloudDocs[url]
    }
}
