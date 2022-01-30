//
//  File.swift
//  
//
//  Created by John Davis on 11/22/20.
//

import Foundation
import Combine

public protocol DocumentQueryCoordinator {
    ///   - added: Array of URLs detected as being added to the observed directory
    ///   - updated: Array of URLs detected as being still present in the observed directory
    ///   - removed: Array of URLs detected as being removed from the observed directory
    ///   - error: Error raised when querying for updates
    typealias DocumentsUpdatedResult = Result<(added: [URL], updated: [URL], removed: [URL]), Error>

    func startQuery()
    func stopQuery()
    
    var urls: [URL] { get set }
    var documentsUpdatedPublisher: AnyPublisher<DocumentQueryCoordinator.DocumentsUpdatedResult, Never> { get }
}
