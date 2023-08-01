//
//  File.swift
//  
//
//  Created by John Davis on 2/6/22.
//

import Foundation

public protocol Nameable {
    var name: String { get }
}

public protocol ManageableDocumentMetaData: Identifiable, Nameable {
    var id: String { get }
}

public protocol ManageableMetaDataContaining {
    associatedtype METADATA: ManageableDocumentMetaData
    var metaData: METADATA? { get set }
}

public protocol ResettableDocument {
    func resetComposableMap()
}
