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
    typealias DocumentsUpdatedResult = Result<(added: [URL], updated: [URL], removed: [URL]), Error>
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
        assertionFailure("Override In Subclass")
    }
}
