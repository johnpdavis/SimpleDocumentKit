//
//  FileMapItemTests.swift
//  
//
//  Created by John Davis on 2/3/22.
//

import XCTest
@testable import SimpleDocumentKit

class FileMapItemTests: XCTestCase {
    func testHierachyTracking() throws {
        // Arrange
        let rootItem = FolderMapItem(filename: "/root/Document")
        
        let metaDataItem = CodableFileMapItem<MockMetaData>(filename: "metaData.json")
        let subFolder = FolderMapItem(filename: "images")
        
        let subsubFolder1 = FolderMapItem(filename: "originals")
        let subsubFolder2 = FolderMapItem(filename: "medium")
        
        // Act
        rootItem.addChild(metaDataItem)
        rootItem.addChild(subFolder)
        subFolder.addChild(subsubFolder1)
        subFolder.addChild(subsubFolder2)
        
        // Assert
        XCTAssertTrue(metaDataItem.parent === rootItem)
        XCTAssertTrue(subFolder.parent === rootItem)
        
        XCTAssertTrue(subsubFolder1.parent === subFolder)
        XCTAssertTrue(subsubFolder2.parent === subFolder)
        
        XCTAssertNotNil(rootItem.trackedChildren["metaData.json"])
        XCTAssertNotNil(rootItem.trackedChildren["images"])
        XCTAssertNotNil(subFolder.trackedChildren["originals"])
        XCTAssertNotNil(subFolder.trackedChildren["medium"])
    }
    
    func testContentRetention() throws {
        let mock = MockMetaData(id: "ID", name: "NAME")
        let metaDataItem = CodableFileMapItem<MockMetaData>(filename: "metaData.json")
        metaDataItem.setContent(mock)
        
        let data = try! metaDataItem.encodeContent()
        
        let manuallyDecoded = try! JSONDecoder().decode(MockMetaData.self, from: data)
        XCTAssertEqual(mock, manuallyDecoded)
        
        let internallyDecodedFromCache: MockMetaData = try! metaDataItem.decodeContent()
        XCTAssertEqual(mock, internallyDecodedFromCache)
    }
    
//    func testURLGeneration() throws {
//        // Arrange
//        let rootItem = FolderMapItem(filename: "/root/Document")
//
//        let metaDataItem = FileMapItem(filename: "metaData.json")
//        let subFolder = FolderMapItem(filename: "images")
//
//        let subsubFolder1 = FolderMapItem(filename: "originals")
//
//        // Act
//        rootItem.addChild(metaDataItem)
//        rootItem.addChild(subFolder)
//        subFolder.addChild(subsubFolder1)
//
//        let rootURL = rootItem.url
//        let metadataURL = metaDataItem.url
//
//        let subFolderURL = subFolder.url
//        let subsubFolder1URL = subsubFolder1.url
//
//        // Assert
//        XCTAssertEqual(rootURL.path, "/root/Document")
//        XCTAssertEqual(metadataURL.path, "/root/Document/metaData.json")
//        XCTAssertEqual(subFolderURL.path, "/root/Document/images")
//        XCTAssertEqual(subsubFolder1URL.path, "/root/Document/images/originals")
//    }
    
    func testTestDocumentCreation() throws {
        let testDocURL = Utilities.createTestDocumentInFileSystem()
        
        let children = try FileManager.default.contentsOfDirectory(at: testDocURL, includingPropertiesForKeys: nil, options: [])
        
        XCTAssertTrue(children.contains { $0.lastPathComponent == "images" })
        XCTAssertTrue(children.contains { $0.lastPathComponent == "metaData.json" })
        
        let imagesChild = children.first { $0.lastPathComponent == "images" }!
        
        let grandChildren = try FileManager.default.contentsOfDirectory(at: imagesChild, includingPropertiesForKeys: nil, options: [])
        XCTAssertTrue(grandChildren.contains { $0.lastPathComponent == "originals" })
    }
    
    func testFileMapItemFileWrapper() throws {
        let rootItem = RootMapItem.default
        let metaDataItem = CodableFileMapItem<MockMetaData>(filename: "metaData.json")
        let subFolder = FolderMapItem(filename: "images")
        
        let subsubFolder1 = FolderMapItem(filename: "originals")
        
        // Act
        rootItem.addChild(metaDataItem)
        rootItem.addChild(subFolder)
        subFolder.addChild(subsubFolder1)
    
        // Assert
        XCTAssertNotNil(rootItem.trackedChildren["metaData.json"])
        let autoMetaDataItem = rootItem.trackedChildren["metaData.json"]
        
//        let autoMetaData: MockMetaData = try autoMetaDataItem!.deco
        
//        let metaData: MockMetaData = try metaDataItem.decodeContent()
//        XCTAssertEqual(metaData.id, "testID")
//        XCTAssertEqual(metaData.name, "testName")
        
    }
}
