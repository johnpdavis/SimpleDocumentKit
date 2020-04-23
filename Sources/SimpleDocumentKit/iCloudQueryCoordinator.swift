//
//  iCloudQueryCoordinator.swift
//  DocumentKit
//
//  Created by Overview on 2/10/19.
//  Copyright © 2019 John Davis. All rights reserved.
//

import Foundation

public class iCloudDocumentQueryCoordinator: DocumentQueryCoordinator {
    init(documentExtension: String) {
        super.init(searchScope: NSMetadataQueryUbiquitousDocumentsScope, documentExtension: documentExtension)
    }
    
    override public func processFiles() {
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
