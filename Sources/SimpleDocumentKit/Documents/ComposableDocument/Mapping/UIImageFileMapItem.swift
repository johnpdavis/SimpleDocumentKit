//
//  File.swift
//  
//
//  Created by John Davis on 2/5/22.
//

import UIKit

public class UIImageFileMapItem: FileMapItemBase, FileContentsContaining  {
    
    public var contentCache: UIImage? = nil
    
    public func setImage(_ content: UIImage) {
        print("SETTING Image")
        contentCache = content
        contentDidChange?(self)
        _fileWrapper = nil

        updateChangeCount?(.done)
    }
    
    override public var fileWrapper: FileWrapper? {
        if let wrapper = _fileWrapper {
            return wrapper
        }
        
        // FileMapItem has not been attached to the document and is considered new.
        
        // If there's no data to write to a file, then there's no need to for a file wrapper.
        guard let data = try? encodeContent() else {
            return nil
        }
        
        let newWrapper = FileWrapper(regularFileWithContents: data)
        newWrapper.preferredFilename = filename
        _fileWrapper = newWrapper
        return newWrapper
    }
    
    public func encodeContent() throws -> Data {
        guard let contentCache = contentCache else {
            throw FileMapItemError.noContentToEncode
        }
        
        guard let data = contentCache.pngData() else {
            throw FileMapItemError.noContentToEncode
        }

        return data
    }
    
    public func decodeContent() throws -> UIImage {
        if let decodedContentCache = contentCache {
            return decodedContentCache
        }
        
        guard let wrapper = fileWrapper else {
            throw FileMapItemError.noFileWrapperAvailable
        }

        guard let data = wrapper.regularFileContents else {
            throw FileMapItemError.noFileDataAvailable
        }
        
        guard let image = UIImage(data: data) else {
            throw FileMapItemError.decodingReturnedNil
        }
        
        self.contentCache = image
        return image
    }
}
