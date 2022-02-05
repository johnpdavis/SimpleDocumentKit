//
//  ComposableDocument.swift
//  
//
//  Created by John Davis on 2/2/22.
//

import UIKit


public struct FolderIdentifier: Hashable {
    public let rawValue: String
}

public struct FileIdentifier: Hashable {
    static public let metaData = FileIdentifier(rawValue: "com.johndavis.simpledocumentkit.cdoc.metadata")
    public let rawValue: String
}

public typealias Archivable = NSCoding & NSObject

public class RootMapItem: FolderMapItem {
    public static var `default`: RootMapItem {
        RootMapItem(filename: "ROOT_ITEM_SHOULD_NOT_USE_FILENAME")
    }
}

// MARK: - ComposableDocumentError
/// Errors thrown from the `ComposableDocument` class
enum ComposableDocumentError: Error {
    case documentNotLoaded
    case mapNotConfigured
    case documentNotFileWrapperBased
}

// MARK: - ComposableDocument
open class ComposableDocument: SmartDocument {
    // MARK: - Internal Types

    // MARK: - Internal Content Tracking
    public var mapRootItem = RootMapItem.default
    
    // MARK: - Initialization
    public override init(fileURL url: URL) {
        super.init(fileURL: url)
    }
    
    // MARK: - Public Document Interface
    open override func contents(forType typeName: String) throws -> Any {
        print("Contents for type: \(typeName)")
        
        guard let fileWrapper = mapRootItem.fileWrapper else {
            throw ComposableDocumentError.mapNotConfigured
        }
        
        return fileWrapper
    }
    
    open override func load(fromContents contents: Any, ofType typeName: String?) throws {
        print("loading contents of type: \(typeName ?? "NIL")")
        guard let wrapper = contents as? FileWrapper else {
            throw ComposableDocumentError.documentNotFileWrapperBased
        }
        
        attachFileWrapper(wrapper, to: mapRootItem)
    }
    
    private func attachFileWrapper(_ fileWrapper: FileWrapper, to rootItem: RootMapItem) {
        rootItem.attachMapToExistingDocumentFileWrapper(fileWrapper)
    }
}

enum DocumentRegistrarError: Error {
    case unableToDecode
}
