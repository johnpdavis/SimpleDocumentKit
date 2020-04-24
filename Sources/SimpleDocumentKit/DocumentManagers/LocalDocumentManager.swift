//
//  File.swift
//  
//
//  Created by John Davis on 4/22/20.
//

import Foundation

public class LocalDocumentManager: BaseDocumentManager {
    public init(localDocumentRoot: URL, documentExtension: String) {
        let coordinator = DocumentQueryCoordinator(searchScope: localDocumentRoot as NSURL, documentExtension: documentExtension)
        super.init(localDocumentRoot: localDocumentRoot, coordinator: coordinator)
    }
    
    public func localURLForDocument(filename: String) -> URL? {
        return localDocumentRoot.appendingPathComponent(filename)
    }
}
