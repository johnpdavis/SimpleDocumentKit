//
//  File.swift
//  
//
//  Created by John Davis on 4/22/20.
//

import Combine
import Foundation

enum iCloudDocumentQueryCoordinatorError: Error {
    case queryNotConfigured
}

public class iCloudDocumentQueryCoordinator: DocumentQueryCoordinator {
    
    // MARK: Properties
    var currentQuery: NSMetadataQuery?
    var urlsReady: Bool = false
    public var urls: [URL] = []
    
    let documentsUpdatedSubject = PassthroughSubject<DocumentsUpdatedResult, Never>()
    public var documentsUpdatedPublisher: AnyPublisher<DocumentsUpdatedResult, Never> {
        return documentsUpdatedSubject.eraseToAnyPublisher()
    }
    
    let documentExtension: String
    let searchScope: Any
    
    init(searchScope: Any, documentExtension: String) {
        self.documentExtension = documentExtension
        self.searchScope = searchScope
    }
    
    func makeDocumentQuery(searchScope: Any, documentExtension: String) -> NSMetadataQuery {
        let query = NSMetadataQuery()
        query.searchScopes = [searchScope]
        query.predicate = NSPredicate(format: "%K LIKE %@", NSMetadataItemFSNameKey, "*\(documentExtension)")
        // NSPredicate(format: "%K.URLByDeletingLastPathComponent.path == %@", argumentArray: [NSMetadataItemURLKey, iCloudDocsURL.path])
        
        return query
    }

    public func startQuery() {
        self.stopQuery()
        
        print("Starting to watch \(searchScope)")
        
        currentQuery = makeDocumentQuery(searchScope: searchScope, documentExtension: documentExtension)
        NotificationCenter.default.addObserver(self, selector: #selector(onMetaDataQuery(_:)), name: .NSMetadataQueryDidFinishGathering, object: currentQuery)
        NotificationCenter.default.addObserver(self, selector: #selector(onMetaDataQuery(_:)), name: .NSMetadataQueryDidUpdate, object: currentQuery)
        
        currentQuery?.start()
    }

    public func stopQuery() {
        if let currentQuery = currentQuery {
            NotificationCenter.default.removeObserver(self, name: .NSMetadataQueryDidFinishGathering, object: currentQuery)
            NotificationCenter.default.removeObserver(self, name: .NSMetadataQueryDidUpdate, object: currentQuery)
            currentQuery.stop()
            self.currentQuery = nil
        }
    }
    
    @objc
    private func onMetaDataQuery(_ notification: Notification) {
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.2, execute: { [weak self] in
            self?.processFilesAndSend()
        })
    }

    public func processFilesAndSend() {
        do {
            let result = try processFiles()
            documentsUpdatedSubject.send(result)
        } catch {
            assertionFailure("Caught error attempting to process files: \(error)")
        }
    }

    public func processFiles() throws -> DocumentsUpdatedResult {
        guard let currentQuery = currentQuery else {
            throw iCloudDocumentQueryCoordinatorError.queryNotConfigured
        }

        currentQuery.disableUpdates()
        defer {
            currentQuery.enableUpdates()
        }
        
        let newlyDiscoveredURLs: [URL] = currentQuery.results.compactMap { result in
            guard let result = result as? NSMetadataItem,
                let url = result.value(forAttribute: NSMetadataItemURLKey) as? URL else { return nil }
            
            
            if let values = try? url.promisedItemResourceValues(forKeys: [URLResourceKey.isHiddenKey]),
                let isHidden = values.isHidden,
                !isHidden {
                return url
            }
            
            return nil
        }
        
        print("Found \(newlyDiscoveredURLs.count) URLs")
        print(newlyDiscoveredURLs)
        
        let newURLSet = Set(newlyDiscoveredURLs)
        let currentURLSet = Set(urls)
        
        let newItems = newURLSet.filter { !currentURLSet.contains($0) }
        let removedItems = currentURLSet.filter { !newURLSet.contains($0) }
        let updatedItems = currentURLSet.filter { newURLSet.contains($0) }
        
        urls = newlyDiscoveredURLs
        urlsReady = true
        
        let result: DocumentsUpdatedResult = .success((added: Array(newItems), updated: Array(updatedItems), removed: Array(removedItems)))
        return result
    }
}
