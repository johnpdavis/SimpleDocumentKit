//
//  FileMapItemError.swift
//  SimpleDocumentKit
//
//  Created by John Davis on 6/16/25.
//

public enum FileMapItemError: Error {
    case unsupportedType
    case noFileWrapperAvailable
    case noFileDataAvailable
    case decodingReturnedNil
    case noContentToEncode
}
