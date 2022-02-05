//
//  FolderMapItem.swift
//  
//
//  Created by John Davis on 2/4/22.
//

import Foundation

enum FolderMapItemError: Error {
    case rootDocumentFileNameNil
    case documentNotLoaded
}

public class FolderMapItem: FileMapItemBase {
    var trackedChildren: [String: FileMapItemBase] = [:]
    
    public override init(filename: String) {
        super.init(filename: filename)
    }
    
    public override var fileWrapper: FileWrapper? {
        if let fileWrapper = _fileWrapper {
            return fileWrapper
        }
        
        let newFileWrapper = FileWrapper(directoryWithFileWrappers: [:])
        newFileWrapper.preferredFilename = filename
        trackedChildren.forEach { key, child in
            if let childWrapper = child.fileWrapper {
                newFileWrapper.addFileWrapper(childWrapper)
            }
        }
        
        _fileWrapper = newFileWrapper
        return newFileWrapper
    }
    
    public func addChild(_ item: FileMapItemBase) {
        item.parent = self
        trackedChildren[item.filename] = item
    }
    
    override func attachMapToExistingDocumentFileWrapper(_ fileWrapper: FileWrapper) {
        super.attachMapToExistingDocumentFileWrapper(fileWrapper)
        
        trackedChildren.forEach { key, child in
            if let wrapper = fileWrapper.fileWrappers?[key] {
                
                if child._fileWrapper != nil {
                    assertionFailure("We are assigning a document file wrapper to an item that already has one? This is odd to me.")
                }
                
                child.attachMapToExistingDocumentFileWrapper(wrapper)
            }
        }
    }
}
