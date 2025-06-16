//
//  ManageableDocumentMetaData.swift
//  SimpleDocumentKit
//
//  Created by John Davis on 6/16/25.
//


public protocol ManageableDocumentMetaData: Identifiable {
    var id: String { get }
}

public protocol ManageableMetaDataContaining {
    associatedtype METADATA: ManageableDocumentMetaData
    var metaData: METADATA? { get }
    func initMetaDataForDocumentCreation(metaData: METADATA)
}
