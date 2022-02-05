//
//  CodableFileMapItem.swift
//  
//
//  Created by John Davis on 2/4/22.
//

import Foundation

public class CodableFileMapItem<CONTENT: Codable>: FileMapItemBase, FileContentsContaining {
    
    override var _fileWrapper: FileWrapper? {
        didSet {
            print("CODABLE FILE WRAPPER SET TO: \(_fileWrapper)")
            if _fileWrapper != nil {
                print("File wrapper set to non nil")
            }
        }
    }
    
    public var contentCache: CONTENT? = nil
    
    public func setContent(_ content: CONTENT) {
        print("SETTING CONTENT")
        contentCache = content
        contentDidChange?(self)
        _fileWrapper = nil

        updateChangeCount?(.done)
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
            throw FileMapItemError.noContentToEncode
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(contentCache)
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
        
        let decoded = try JSONDecoder().decode(CONTENT.self, from: data)
        return decoded
    }
}
