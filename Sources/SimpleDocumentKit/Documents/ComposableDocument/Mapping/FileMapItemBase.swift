//
//  FileMapItemBase.swift
//  
//
//  Created by John Davis on 2/4/22.
//

import UIKit

public enum FileMapItemError: Error {
    case unsupportedType
    case noFileWrapperAvailable
    case noFileDataAvailable
    case decodingReturnedNil
    case noContentToEncode
}

public class FileMapItemBase {
    public var filename: String
    
    // This closure is populated with the document is attached to the map
    public var updateChangeCount: ((UIDocument.ChangeKind) -> Void)?
    public var contentDidChange: ((FileMapItemBase) -> Void)?
    
    public weak var parent: FolderMapItem? = nil
    
    var _fileWrapper: FileWrapper? = nil
    
    public var fileWrapper: FileWrapper?  {
        assertionFailure("Override in subclass")
        return nil
    }
            
    required public init(filename: String) {
        self.filename = filename
    }
    
    func attachMapToExistingDocumentFileWrapper(_ fileWrapper: FileWrapper) {
        _fileWrapper = fileWrapper
    }
}
