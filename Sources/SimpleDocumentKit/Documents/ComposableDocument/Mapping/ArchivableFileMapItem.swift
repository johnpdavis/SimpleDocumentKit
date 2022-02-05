//
//  ArchivableFileMapItem.swift
//  
//
//  Created by John Davis on 2/4/22.
//

import Foundation

public class ArchivableFileMapItem<CONTENT: Archivable>: FileMapItemBase, FileContentsContaining {
    public var contentCache: CONTENT? = nil
    
    public func setContent(_ content: CONTENT) {
        contentCache = content
        _fileWrapper = nil
    }
    
    public override var fileWrapper: FileWrapper? {
        get {
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
    }
    
    public func encodeContent() throws -> Data {
        guard let contentCache = contentCache else {
            throw FileMapItemError.noFileDataAvailable
        }

        let data = try NSKeyedArchiver.archivedData(withRootObject: contentCache, requiringSecureCoding: true)
        return data
    }
    
    public func decodeContent() throws -> CONTENT {
        if let decodedContentCache = contentCache {
            return decodedContentCache
        }

        guard let wrapper = fileWrapper else {
            throw FileMapItemError.noFileWrapperAvailable
        }

        guard let data = wrapper.regularFileContents else {
            throw FileMapItemError.noFileDataAvailable
        }

        guard let decoded = try NSKeyedUnarchiver.unarchivedObject(ofClass: CONTENT.self, from: data) else {
            throw FileMapItemError.decodingReturnedNil
        }

        return decoded
    }
}
