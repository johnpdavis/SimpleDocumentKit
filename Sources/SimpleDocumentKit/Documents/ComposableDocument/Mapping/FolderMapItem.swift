//
//  FolderMapItem.swift
//  
//
//  Created by John Davis on 2/4/22.
//

import UIKit

enum FolderMapItemError: Error {
    case rootDocumentFileNameNil
    case documentNotLoaded
}

public class FolderMapItem: FileMapItemBase {
    var trackedChildren: [String: FileMapItemBase] = [:]
    
    public override var updateChangeCount: ((UIDocument.ChangeKind) -> Void)? {
        didSet {
            trackedChildren.forEach { key, child in
                child.updateChangeCount = self.updateChangeCount
            }
        }
    }
    
    public override required init(filename: String) {
        super.init(filename: filename)
    }
    
    public override var fileWrapper: FileWrapper? {
        if let fileWrapper = _fileWrapper {
            
            // Make sure we associate a wrapper for all kids
            trackedChildren.forEach { key, child in
                if let childWrapper = child.fileWrapper {
                    fileWrapper.addFileWrapper(childWrapper)
                }
            }
            
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
        
        item.contentDidChange = { [weak self] changedChild in
            guard let self = self else { return }
            
            if let childWrapper = changedChild.fileWrapper {
                self.fileWrapper?.removeFileWrapper(childWrapper)
            }
            self.contentDidChange?(self)
            self.updateChangeCount?(.done)
        }
    }
    
    override func attachMapToExistingDocumentFileWrapper(_ fileWrapper: FileWrapper) {
        super.attachMapToExistingDocumentFileWrapper(fileWrapper)
        
        trackedChildren.forEach { key, child in
            if let wrapper = fileWrapper.fileWrappers?[key] {

//                if child._fileWrapper == nil {
//                    assertionFailure("We are setting over our filewrapper")
//                }

                child.attachMapToExistingDocumentFileWrapper(wrapper)
            }
        }
    }
}
