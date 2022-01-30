//
//  PackageDocument.swift
//  DocumentKit
//
//  Created by Overview on 3/2/19.
//  Copyright © 2019 John Davis. All rights reserved.
//

#if !os(macOS)
import UIKit
#endif

public protocol NamedPackageDocContents {
    static var packageDocContentsName: String { get }
}

public typealias PackageDocContents = Codable & Defaultable & Equatable & NamedPackageDocContents

public class PackageDocument<DATATYPE: PackageDocContents, MDATATYPE: PackageDocContents>: SmartDocument {
    
    // MARK: - Properties
    
    private let dataFilename = DATATYPE.packageDocContentsName
    private let metaDataFilename = MDATATYPE.packageDocContentsName
    
    private var privateDocumentData: DATATYPE?
    public func getDocumentData() throws -> DATATYPE  {
        guard let fileWrapper = fileWrapper else {
            throw SmartDocumentError.documentNotLoaded
        }
        
        if let data = privateDocumentData {
            return data
        }
        
        guard let newDocumentData: DATATYPE = decodePackageDataFrom(fileWrapper, key:dataFilename) else {
            throw SmartDocumentError.unableToParseData
        }
        
        privateDocumentData = newDocumentData
        return newDocumentData
    }
    
    public func setDocumentData(_ newValue: DATATYPE) {
        privateDocumentData = newValue
        updateChangeCount(.done)
    }

    private var privateMetaData: MDATATYPE?
    public func getMetaData() throws -> MDATATYPE  {
        guard let fileWrapper = fileWrapper else {
            throw SmartDocumentError.documentNotLoaded
        }
        
        if let data = privateMetaData {
            return data
        }
        
        guard let loadedMetaData: MDATATYPE = decodePackageDataFrom(fileWrapper, key:metaDataFilename) else {
            throw SmartDocumentError.unableToParseData
        }
        
        privateMetaData = loadedMetaData
        return loadedMetaData
    }
    
    public func setMetaData(_ newValue: MDATATYPE) {
        privateMetaData = newValue
        updateChangeCount(.done)
    }
    
    var fileWrapper: FileWrapper?
    
    // MARK: - Initialization
    
    public override init(fileURL url: URL) {
        super.init(fileURL: url)
    }
    
    // MARK: - Encoding
    
    
    /// Override this method to specify how the document's data is encoded.
    /// DO NOT INVOKE SUPER
    /// - Parameter data: Encodable item to be encoded
    /// - Returns: Encoded data
    /// - Throws: Marked as throws so overrides can throw encoding errors
    public func encodePackageData<T: Encodable>(_ data: T) throws -> Data {
        fatalError("Override in subclass")
    }
    
    /// Optional override point to sepcialize the encoding of the package meta data.
    /// Unless overriden this method will invoke `encodePackageData`
    /// If overridden, DO NOT INVOKE SUPER
    ///
    /// - Parameter data: Data to encode. Must confirm to `Encodable`
    /// - Returns: Encoded Data
    /// - Throws: By default this method forwards errors thrown by the default `encodePackageData` implementation
    public func encodePackageMetaData<T: Encodable>(_ data: T) throws -> Data {
        return try encodePackageData(data)
    }
    
    public override func contents(forType typeName: String) throws -> Any {
        print("Contents For Type: \(typeName)")
        
        var wrappers:[String: FileWrapper] = [:]
        wrappers[dataFilename] = FileWrapper(regularFileWithContents: try encodePackageData(try getDocumentData()))
        wrappers[metaDataFilename] = FileWrapper(regularFileWithContents: try encodePackageMetaData(try getMetaData()))
        
        return FileWrapper.init(directoryWithFileWrappers: wrappers)
    }
    
    // MARK: - Decoding
    
    
    /// Override point for decoding file wrapper from package contents into an object
    ///
    /// - Parameters:
    ///   - fileWrapper: Document's main file wrapper
    ///   - key: Key of sub-filewrapper to decode
    /// - Returns: Decoded object, or nil if an object could not be decoded
    public func decodePackageDataFrom<T: Decodable>(_ fileWrapper: FileWrapper?, key: String) -> T? {
        fatalError("Override in subclass")
    }
    
    public override func load(fromContents contents: Any, ofType typeName: String?) throws {
        guard let wrapper = contents as? FileWrapper else {
            throw SmartDocumentError.unableToParseData
        }
        
        //Docdata and metadata will be lazy loaded
        self.privateDocumentData = nil
        self.privateMetaData = nil
        self.fileWrapper = wrapper
    }
}
