//
//  File.swift
//  
//
//  Created by John Davis on 4/22/20.
//

import Combine
import Foundation

public class DocumentQueryCoordinator {
    // MARK: Properties
    var currentQuery: NSMetadataQuery?
    var urlsReady: Bool = false
    var urls: [URL] = []

    ///   - added: Array of URLs detected as being added to the observed directory
    ///   - updated: Array of URLs detected as being still present in the observed directory
    ///   - removed: Array of URLs detected as being removed from the observed directory
    ///   - error: Error raised when querying for updates
    public typealias DocumentsUpdatedResult = Result<(added: [URL], updated: [URL], removed: [URL]), Error>
    let documentsUpdatedPublisher = PassthroughSubject<DocumentsUpdatedResult, Never>()

    let documentExtension: String
    let searchScope: Any
    
    init(searchScope: Any, documentExtension: String) {
        self.documentExtension = documentExtension
        self.searchScope = searchScope
    }
    
    public func makeDocumentQuery(searchScope: Any, documentExtension: String) -> NSMetadataQuery {
        let query = NSMetadataQuery()
        query.searchScopes = [searchScope]
        query.predicate = NSPredicate(format: "%K LIKE %@", NSMetadataItemFSNameKey, ".\(documentExtension)")
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
        processFiles()
    }

    public func processFiles() {
        guard let currentQuery = currentQuery else { return }
        
        currentQuery.disableUpdates()
        
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
        documentsUpdatedPublisher.send(result)
        
        currentQuery.enableUpdates()
    }
}
