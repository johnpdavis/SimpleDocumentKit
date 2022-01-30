  
//
//  Created by John Davis on 4/22/20.
//

import Combine
import Foundation

public class BaseDocumentManager {
    let localDocumentRoot: URL
    let coordinator: DocumentQueryCoordinator
    
    public var documentsUpdatedPublisher: AnyPublisher<DocumentQueryCoordinator.DocumentsUpdatedResult, Never> {
        coordinator.documentsUpdatedPublisher.eraseToAnyPublisher()
    }
    
    public init(localDocumentRoot: URL, coordinator: DocumentQueryCoordinator) {
        self.localDocumentRoot = localDocumentRoot
        self.coordinator = coordinator
    }
    
    public func startQueryingDocuments() {
        self.coordinator.startQuery()
    }
}
