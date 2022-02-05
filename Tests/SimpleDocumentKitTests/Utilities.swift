//
//  File.swift
//  
//
//  Created by John Davis on 2/4/22.
//

import Foundation
import SimpleDocumentKit

enum Utilities {
    static func makeTestDocumentTmpURL() -> URL {
        let rootUrl = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString).unittest")
        
        return rootUrl
    }
    
    static func createTestDocumentInFileSystem() -> URL {
        let rootUrl = makeTestDocumentTmpURL()
        
        let imagesURL = rootUrl.appendingPathComponent("images")
        let originalImagesURL = imagesURL.appendingPathComponent("originals")
        
        let metaDataURL = rootUrl.appendingPathComponent("metaData.json")
        
        try! FileManager.default.createDirectory(at: rootUrl, withIntermediateDirectories: true)
        try! FileManager.default.createDirectory(at: imagesURL, withIntermediateDirectories: true)
        try! FileManager.default.createDirectory(at: originalImagesURL, withIntermediateDirectories: true)
        
        let data = try! JSONEncoder().encode(MockMetaData(id: "testID", name: "testName"))
        try! data.write(to: metaDataURL)
        
        return rootUrl
    }
    
    struct DocumentResultBundle {
        let composableDocument: ComposableDocument
        let metaDataFileItem: CodableFileMapItem<MockMetaData>
        let imagesFolderItem: FolderMapItem
        let originalsFolderItem: FolderMapItem
    }
    
    static func makeComposedTestDocument(at url: URL) -> DocumentResultBundle {
        let composableDoc = ComposableDocument(fileURL: url)
        
        let metaDataItem = CodableFileMapItem<MockMetaData>(filename: "metaData.json")
        let imagesFolderItem = FolderMapItem(filename: "images")
        let originalsFolder = FolderMapItem(filename: "originals")
        
        let originalsMetaDataItem = CodableFileMapItem<MockMetaData>(filename: "metaData.json")
        
        // Act
        composableDoc.mapRootItem.addChild(metaDataItem)
        composableDoc.mapRootItem.addChild(imagesFolderItem)
        imagesFolderItem.addChild(originalsFolder)
        originalsFolder.addChild(originalsMetaDataItem)
        
        return DocumentResultBundle(composableDocument: composableDoc,
                                    metaDataFileItem: metaDataItem,
                                    imagesFolderItem: imagesFolderItem,
                                    originalsFolderItem: originalsFolder)
    }
}
