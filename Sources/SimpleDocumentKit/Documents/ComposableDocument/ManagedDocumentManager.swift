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
}

public typealias ManageableDocument = SmartDocument & ManageableMetaDataContaining

class ManagedDocumentLoader<DOCUMENT: ManageableDocument>: AsyncSequence, AsyncIteratorProtocol {
    typealias LoadedManagedDocument = (document: DOCUMENT, id: String, name: String)
    typealias Element = LoadedManagedDocument
    
    private var documentURLs: [URL] = []
    
    init(documentURLs: [URL]) {
        self.documentURLs = documentURLs
    }
    
    func next() async -> LoadedManagedDocument? {
        await getNextDocument()
    }
    
    func makeAsyncIterator() -> some ManagedDocumentLoader {
        self
    }
    
    private func getNextDocument() async -> LoadedManagedDocument? {
        guard let nextURL = documentURLs.popLast() else { return nil }
        
        let document = await DOCUMENT(fileURL: nextURL)
        await document.open()
        guard let metaData = document.metaData else { return nil }
        await document.close()
        
        return (document: document, id: metaData.id, name: metaData.name)
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
    
    public var localIDToDoc: [String: DOCUMENT] = [:]
    public var cloudIDToDoc: [String: DOCUMENT] = [:]
    
    @Published var localDocuments: [DOCUMENT] = []
    @Published var cloudDocuments: [DOCUMENT] = []
    
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
        
        if initializeiCloudAccess {
            cloudDocumentManager.initializeiCloudAccess { success, containerURL in
                print("\(success) - \(String(describing: containerURL))")
            }
        }
    }
    
//    public func documentForID(_ id: String) -> DOCUMENT? {
//        return nil
//    }
//
//    public func removeDocument(_ document: DOCUMENT, completion: ((Bool) -> Void)?) {
//        if localDocuments.contains(document) {
//
//        }
//
//        if cloudDocuments.contains(document) {
//
//        }
//    }
    
    private func initializeCloudDocManager() {
        cloudDocumentSubscriber = self.cloudDocumentManager.documentsUpdatedPublisher
            .debounce(for: 0.2, scheduler: DispatchQueue.main)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] result in
                Task { [weak self] in
                    print("Received Cloud result: \(result)")
                    await self?.processCloudResult(result)
                }
            }
        
        cloudDocumentManager.startQueryingDocuments()
    }
    
    private func initializeLocalDocManager() {
        localDocumentSubscriber = localDocumentManager.documentsUpdatedPublisher
            .debounce(for: 0.2, scheduler: DispatchQueue.main)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] result in
                Task { [weak self] in
                    print("Received Cloud result: \(result)")
                    await self?.processLocalResult(result)
                }
            }
        
        localDocumentManager.startQueryingDocuments()
    }
    
    func processLocalResult(_ result: Result<(added: [URL], updated: [URL], removed: [URL]), Error>) async {
        do {
            async let (map, list) = try ManagedDocumentManager.processResult(result)
            localIDToDoc = try await map
            localDocuments = try await list
        } catch {
            print("processing failed: \(error)")
        }
    }
    
    func processCloudResult(_ result: Result<(added: [URL], updated: [URL], removed: [URL]), Error>) async {
        do {
            let (map, list) = try await ManagedDocumentManager.processResult(result)
            cloudIDToDoc = map
            cloudDocuments = list
        } catch {
            print("processing failed: \(error)")
        }
    }


    static func processResult(_ result: Result<(added: [URL], updated: [URL], removed: [URL]), Error>) async throws -> ([String: DOCUMENT], [DOCUMENT]) {
        switch result {
        case .failure(let error):
            print("Received Document Failure: \(error)")
            throw error
        case .success(let docURLs):
            print("Received Document URLs - \(docURLs.added.count) Added -  \(docURLs.updated.count) updated -  \(docURLs.removed.count) Removed")
            var newUUIDMap: [String: DOCUMENT] = [:]

            let addedDocsLoader = ManagedDocumentLoader<DOCUMENT>(documentURLs: docURLs.added)
            let updatedDocsLoader = ManagedDocumentLoader<DOCUMENT>(documentURLs: docURLs.updated)
            
            func processLoader(_ loader: ManagedDocumentLoader<DOCUMENT>) async {
                for await loadedDoc in loader {
                    newUUIDMap["\(loadedDoc.id)"] = loadedDoc.document
                }
            }
            await processLoader(addedDocsLoader)
            await processLoader(updatedDocsLoader)
            
            let documents = Array(newUUIDMap.values)
            let sortedDocuments = documents.sorted {
                guard let firstName = $0.metaData?.name,
                      let secondName = $1.metaData?.name else {
                    return false
                }
                
                return firstName.localizedCaseInsensitiveCompare(secondName) == .orderedAscending
            }
            
            return (newUUIDMap, sortedDocuments)
        }
    }
    
    /// URL for document with provided name.
    ///
    /// - Parameter name: Name of document with extension
    /// - Returns: returns URL of document, or nil, if it could not be found or created
    func urlForDocument(name: String) -> URL? {
        if ICloudDefaults.standard.iCloudOn {
            return cloudDocumentManager.iCloudURLForDocument(filename: name)
        } else {
            return managedDocumentDirectory.appendingPathComponent(name)
        }
    }
    
    /// Will attempt to return a Document with the provided name. This method will look in the designated storage area, iCloud or Local, depending on the app's settings. If the file does not exist, it will be created.
    ///
    /// - Parameters:
    ///   - name: Name of package with extension
    public func document(name: String, metaData: DOCUMENT.METADATA) async throws -> DOCUMENT { //} completion:((DOCUMENT?) -> ())?) {
        // If the file doesnt exist, make it. Otherwise return it.
        guard let url = urlForDocument(name: name) else { throw ManagedDocumentManagerError.unableToRetrieveURL }

        if documentExistsWithName(name) {
            return DOCUMENT(fileURL: url)
        } else {
            let document = DOCUMENT(fileURL: url)

            if await document.save(to: url, for: .forCreating) {
                return document
            } else {
                print("FAILED TO SAVE FILE")
                throw ManagedDocumentManagerError.unableToSaveNewDocument
            }
        }
    }
    
    /// Will change document name by invoking move
    ///
    /// - Parameters:
    ///   - document: Document to move to newly named URL
    ///   - name: New name of document including extension
    ///   - completion: Completion closure to be invoked when rename is complete. Will be invoked on main queue
    public func renameDocument(document: UIDocument, name: String) async throws {
        guard name != document.fileURL.lastPathComponent else {
            throw ManagedDocumentManagerError.documentURLInvalid
        }

        guard let newURL = urlForDocument(name: name) else {
            throw ManagedDocumentManagerError.unableToRetrieveURL
        }

        let originalURL = document.fileURL

        print("Invoking Move \(originalURL) \n=>\n\(newURL)")
        try await FileManager.default.moveUbiquitousItem(at: originalURL, to: newURL)
    }
    
    /// Will create the full document URL by invoking `urlForDocument(name:)` and ask NSFileManager if the URL exists.
    ///
    /// - Parameter name: Full name of document including extension.
    /// - Returns: True of document exists. Otherwise false.
    func documentExistsWithName(_ name: String) -> Bool {
        guard let fullFileURL = urlForDocument(name: name) else { fatalError("Cannot construct full Document file URL") }
        
        return FileManager.default.fileExists(atPath:fullFileURL.path)
    }
}
