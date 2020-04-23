//
//  JsonPackageDocument.swift
//  DocumentKit
//
//  Created by Overview on 3/2/19.
//  Copyright © 2019 John Davis. All rights reserved.
//

#if !os(macOS)
import UIKit
#endif

public typealias JsonDocData = Codable & Equatable & Defaultable & NamedPackageDocContents

public class JsonPackageDocument<JSONROOT: JsonDocData, MDATAROOT: JsonDocData>: PackageDocument<JSONROOT, MDATAROOT> {
    
    // MARK: Properties
    
    /// JSON Flavored variable that wraps the documentdata variable
    public var root: JSONROOT {
        get {
            return documentData
        }
        
        set {
            documentData = newValue
        }
    }
    
    /// JSON Flavored variable that wraps the metaData variable
    public var metaDataRoot: MDATAROOT {
        get {
            return metaData
        }
        
        set {
            metaData = newValue
        }
    }
    
    // Initialization
    public override init(fileURL url: URL) {
        super.init(fileURL: url)
    }
    
    // MARK: PackageDocument Overrides
    /// Encodes package data for `PackageDocument` with a JSONEncoder
    override public func encodePackageData<T: Encodable>(_ data: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        return try encoder.encode(data)
    }
    
    /// Dencodes package data for `PackageDocument` with a JSONDecoder. Will return nil if an object cannot be decoded. 
    override public func decodePackageDataFrom<T: Decodable>(_ fileWrapper: FileWrapper?, key: String) -> T? {
        guard let subWrapper = fileWrapper?.fileWrappers?[key] else {
            print("Unable to find internal file wrapper for key:\(key)")
            return nil
        }
        
        guard let data = subWrapper.regularFileContents else {
            print("Unable to get data of internal file wrapper for key:\(key)")
            return nil
        }
        
        let decoded = try? JSONDecoder().decode(T.self, from: data)
        return decoded
    }
}

// MARK: - Contents logging
extension JsonPackageDocument {
    public var packageContentsText: String {
        let version = NSFileVersion.currentVersionOfItem(at: fileURL)
        
        print("File: \(fileURL.lastPathComponent)  State: \(documentStateString)  Version: \(String(describing: version?.modificationDate))")
        
        if documentState.contains(.normal) {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            if let metaData = try? encoder.encode(metaDataRoot),
                let data = try? encoder.encode(root){
                let dataString = String(data: data, encoding: .utf8) ?? "nil"
                let mdataString = String(data: metaData, encoding: .utf8) ?? "nil"
                return "\(mdataString)\n========\n\(dataString)"
            }
        }
        
        return "Package cannot be read."
    }
}

