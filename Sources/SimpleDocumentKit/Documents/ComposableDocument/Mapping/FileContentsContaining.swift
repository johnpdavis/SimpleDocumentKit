//
//  FileContentsContaining.swift
//  
//
//  Created by John Davis on 2/4/22.
//

import Foundation

public protocol FileContentsContaining: AnyObject {
    associatedtype FCC_CONTENT
    
    var contentCache: FCC_CONTENT? { get set }
    
    func encodeContent() throws -> Data
    func decodeContent() throws -> FCC_CONTENT
}
