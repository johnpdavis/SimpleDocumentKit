//
//  FileMapItemBase.swift
//  
//
//  Created by John Davis on 2/4/22.
//

import Foundation

public enum FileMapItemError: Error {
    case unsupportedType
    case noFileWrapperAvailable
    case noFileDataAvailable
    case decodingReturnedNil
}

public class FileMapItemBase {
    public var filename: String

    public weak var parent: FolderMapItem? = nil
    
    var _fileWrapper: FileWrapper? = nil
    
    public var fileWrapper: FileWrapper?  {
        assertionFailure("Override in subclass")
        return nil
    }
            
    public init(filename: String) {
        self.filename = filename
    }
    
    func attachMapToExistingDocumentFileWrapper(_ fileWrapper: FileWrapper) {
        _fileWrapper = fileWrapper
    }
}
