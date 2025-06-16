//
//  File.swift
//  
//
//  Created by John Davis on 11/22/20.
//

import Foundation
import Combine

public protocol DocumentQueryCoordinator {
    typealias DocumentsUpdatedResult = Result<(added: [URL], present: [URL], removed: [URL]), Error>

    func startQuery()
    func stopQuery()
    func processFiles() throws -> DocumentsUpdatedResult
    
    var urls: [URL] { get set }
    var documentsUpdatedPublisher: AnyPublisher<DocumentQueryCoordinator.DocumentsUpdatedResult, Never> { get }
}
