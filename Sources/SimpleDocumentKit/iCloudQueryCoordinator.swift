//
//  iCloudQueryCoordinator.swift
//  DocumentKit
//
//  Created by Overview on 2/10/19.
//  Copyright © 2019 John Davis. All rights reserved.
//

import Foundation

protocol CloudQueryCoordinatorDelegate: class {
    
    /// Invoked when the URLs from the query update have been processed and stable. The iCloudURLs property of the coordinator is stable and representative of the recent query update.
    ///
    /// - Parameter queryCoordinator: Coordinator that will enable updates
    func queryCoordinatorWillEnableQueryUpdates(_ queryCoordinator: iCloudQueryCoordinator)
    
    
    /// Invoked to communicate which files have been added, updated, and removed in the recent query update
    ///
    /// - Parameters:
    ///   - queryCoordinator: Coordinator that processed the query update
    ///   - addedFiles: Array of URLs detected as being added to the iCloud directory
    ///   - updatedFiles: Array of URLs detected as being still present in the iCloud directory
    ///   - removedFiles: Array of URLs detected as being removed from the iCloud directory
    func queryCoordinator(_ queryCoordinator: iCloudQueryCoordinator, didDetectAddedFiles addedFiles: [URL], updatedFiles:[URL], removedFiles:[URL])
}

public class iCloudQueryCoordinator {
    // MARK: Properties
    var currentQuery: NSMetadataQuery?
    var iCloudURLsReady: Bool = false
    var iCloudURLs: [URL] = []
    
    weak var delegate: CloudQueryCoordinatorDelegate?
    
    public func makeDocumentQuery() -> NSMetadataQuery {
        let query = NSMetadataQuery()
        query.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
        query.predicate = NSPredicate(format: "%K LIKE %@", NSMetadataItemFSNameKey, "*.documentkit")
        
        return query
    }
    
    public func startQuery() {
        self.stopQuery()
        
        print("Starting to watch iCloud Dir")
        
        currentQuery = makeDocumentQuery()
        NotificationCenter.default.addObserver(self, selector: #selector(processiCloudFiles(_:)), name: .NSMetadataQueryDidFinishGathering, object: currentQuery)
        NotificationCenter.default.addObserver(self, selector: #selector(processiCloudFiles(_:)), name: .NSMetadataQueryDidUpdate, object: currentQuery)
        
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
    public func processiCloudFiles(_ notification: Notification) {
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
        let currentURLSet = Set(iCloudURLs)
        
        let newItems = newURLSet.filter { !currentURLSet.contains($0) }
        let removedItems = currentURLSet.filter { !newURLSet.contains($0) }
        let updatedItems = currentURLSet.filter { newURLSet.contains($0) }
        
        iCloudURLs = newlyDiscoveredURLs
        iCloudURLsReady = true
        
        delegate?.queryCoordinatorWillEnableQueryUpdates(self)
        delegate?.queryCoordinator(self, didDetectAddedFiles: Array(newItems), updatedFiles: Array(updatedItems), removedFiles: Array(removedItems))
        
        currentQuery.enableUpdates()
    }
    
    func docNameExistsIniCloudURLs(_ name: String) -> Bool {
        return !iCloudURLs.filter({ $0.lastPathComponent == name }).isEmpty
    }
}
