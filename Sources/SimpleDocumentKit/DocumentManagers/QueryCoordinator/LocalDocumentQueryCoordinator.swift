//
//  Created by John Davis on 11/22/20.
//

import UIKit
import Combine

public class LocalDocumentQueryCoordinator: DocumentQueryCoordinator {
    
    var urlsReady: Bool = false
    public var urls: [URL] = []
    
    let documentsUpdatedSubject = PassthroughSubject<DocumentsUpdatedResult, Never>()
    public var documentsUpdatedPublisher: AnyPublisher<DocumentsUpdatedResult, Never> {
        return documentsUpdatedSubject.eraseToAnyPublisher()
    }
    
    var dispatchObserver: DirectoryDispatchObserver

    let documentExtension: String
    let searchScope: URL
    
    init(searchScope: URL, documentExtension: String) {
        self.documentExtension = documentExtension
        self.searchScope = searchScope
        
        self.dispatchObserver = DirectoryDispatchObserver(url: searchScope)
        self.dispatchObserver.delegate = self
    }
    
    public func startQuery() {
        do {
            print("Starting to watch: \(searchScope)")
            try processFiles()
        } catch {
            assertionFailure("Caught error while processing directory:\(error)")
        }
        
        dispatchObserver.startWatching()
    }
    
    public func stopQuery() {
        dispatchObserver.stopWatching()
    }
    
    public func processFiles() throws {
        dispatchObserver.stopWatching()
        
        let newlyDiscoveredURLs = try FileManager.default.contentsOfDirectory(at: searchScope, includingPropertiesForKeys: [.nameKey],
                                                                              options: [.skipsPackageDescendants, .skipsHiddenFiles])
            .filter({ $0.pathExtension == documentExtension.trimmingCharacters(in: ".") })
        
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
        documentsUpdatedSubject.send(result)
        
        dispatchObserver.startWatching()
    }
}

extension LocalDocumentQueryCoordinator: DirectoryDispatchObserverDelegate {
    func directoryDispatchObserverDetectedChange(_ observer: DirectoryDispatchObserver) {
        do {
            try processFiles()
        } catch {
            assertionFailure("Caught error while processing directory:\(error)")
        }
    }
}
