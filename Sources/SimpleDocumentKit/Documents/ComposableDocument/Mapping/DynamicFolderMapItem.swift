//
//  File.swift
//  
//
//  Created by John Davis on 2/5/22.
//

import Foundation
import UniformTypeIdentifiers

typealias ContentsFileMapItem = FileMapItemBase & FileContentsContaining

/// DynamicFolderMapItem can maintain a list of trackedChildren like a normal FolderMapItem can, but supports reading existing image files
public class DynamicFolderMapItem: FolderMapItem {
    var untrackedChildren: [FileMapItemBase] = [] {
        willSet {
            untrackedChildren.forEach { child in
                if let trackedWrapper = _fileWrapper?.fileWrappers?[child.filename] {
                    _fileWrapper?.removeFileWrapper(trackedWrapper)
                }
            }
        }
        
        didSet {
            untrackedChildren.forEach { child in
                if let childWrapper = child._fileWrapper {
                    _fileWrapper?.addFileWrapper(childWrapper)
                }
            }
        }
    }
    
    var supportedUntrackedTypes: [UTType: FileMapItemBase.Type] = [:]
    
    public init(filename: String, supportedUntrackedTypes: [UTType: FileMapItemBase.Type]) {
        self.supportedUntrackedTypes = supportedUntrackedTypes
        super.init(filename: filename)
    }
    
    public override required init(filename: String) {
        fatalError("Not supported for dynamic folders.")
    }
    
    public override var fileWrapper: FileWrapper? {
        let selfWrapper = super.fileWrapper
        
        untrackedChildren.forEach { child in
            if let childWrapper = child.fileWrapper {
                selfWrapper?.addFileWrapper(childWrapper)
            }
        }
        
        return super.fileWrapper
    }
    
    override func attachMapToExistingDocumentFileWrapper(_ fileWrapper: FileWrapper) {
        super.attachMapToExistingDocumentFileWrapper(fileWrapper)
        
        let untrackedWrappers = fileWrapper.fileWrappers?.filter { possibleUntrackedWrapper in
            let currentlyTracked = trackedChildren.contains(where: { $0.key == possibleUntrackedWrapper.key })
            return !currentlyTracked
        }
        
        untrackedWrappers?.forEach { key, untrackedWrapper in
            guard let fileName = untrackedWrapper.filename else {
                assertionFailure("Wrapper without filename?")
                return
            }
            
            let urlFileName = URL(fileURLWithPath: fileName)
            let fileExtension = urlFileName.pathExtension
            
            guard let type = UTType(filenameExtension: fileExtension) else {
                print("Invalid file extension: \(fileExtension)")
                return
            }
            
            let supportedTypeThatUntrackedFileConformsTo = supportedUntrackedTypes.keys.first { $0.conforms(to: type) }
            guard let supportedTypeThatUntrackedFileConformsTo = supportedTypeThatUntrackedFileConformsTo else {
                print("Unsupported type: \(type)")
                return
            }

            guard let untrackedItemType = supportedUntrackedTypes[supportedTypeThatUntrackedFileConformsTo] else {
                print("Unable to find item type for \(supportedTypeThatUntrackedFileConformsTo)")
                return
            }
            
            let untrackedItem = untrackedItemType.init(filename: fileName)
            untrackedItem.attachMapToExistingDocumentFileWrapper(untrackedWrapper)
            untrackedChildren.append(untrackedItem)
        }
    }
}
