//
//  DynamicFolderMapItemTests.swift
//  
//
//  Created by John Davis on 2/5/22.
//

import XCTest
@testable import SimpleDocumentKit

class DynamicFolderMapItemTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    let blue = UIImage(named: "blue", in: .module, with: nil)!
    let green = UIImage(named: "green", in: .module, with: nil)!
    let purple = UIImage(named: "purple", in: .module, with: nil)!
    let red = UIImage(named: "red", in: .module, with: nil)!
    let yellow = UIImage(named: "yellow", in: .module, with: nil)!
    
    @MainActor
    func testDynamicFolderMapItem() async throws {
        let tmpURL = Utilities.makeTestDocumentTmpURL()
        try FileManager.default.createDirectory(at: tmpURL, withIntermediateDirectories: false, attributes: nil)
        let folderMapTestWrapper = try FileWrapper(url: tmpURL, options: .immediate)
        
        let folderItem = DynamicFolderMapItem(filename: "test?", supportedUntrackedTypes: [.png: UIImageFileMapItem.self])
        folderItem.attachMapToExistingDocumentFileWrapper(folderMapTestWrapper)
        
        
        folderItem.untrackedChildren = [red, green, blue, yellow, purple].imageFileMapItems
        let folderFileWrapper = folderItem.fileWrapper
        
        XCTAssertEqual(folderFileWrapper?.fileWrappers?.count, 5)
        
        folderItem.untrackedChildren = [red].imageFileMapItems
        let folderFileWrapper2 = folderItem.fileWrapper
        XCTAssertEqual(folderFileWrapper2?.fileWrappers?.count, 1)
    }
    
    func testDynamicFolderWithUntrackedImagesAndTrackedMetaData() async throws {
        // Arrange
        let tmpURL = Utilities.makeTestDocumentTmpURL()
        try FileManager.default.createDirectory(at: tmpURL, withIntermediateDirectories: false, attributes: nil)
        let folderMapTestWrapper = try FileWrapper(url: tmpURL, options: .immediate)
        
        let folderItem = DynamicFolderMapItem(filename: "test?", supportedUntrackedTypes: [.png: UIImageFileMapItem.self])
        let metaDataItem = CodableFileMapItem<MockMetaData>(filename: "metaData.json")
        folderItem.addChild(metaDataItem)
        
        folderItem.attachMapToExistingDocumentFileWrapper(folderMapTestWrapper)
        
        // Act
        let mockMetaData = MockMetaData(id: "ID", name: "Test")
        metaDataItem.setContent(mockMetaData)
        folderItem.untrackedChildren = [red, green, blue, yellow, purple].imageFileMapItems
        
        let folderFileWrapper = folderItem.fileWrapper
        
        // Assert
        XCTAssertEqual(folderFileWrapper?.fileWrappers?.count, 6)
        
        // Act
        folderItem.untrackedChildren = [red].imageFileMapItems
        let folderFileWrapper2 = folderItem.fileWrapper
        
        // Assert
        XCTAssertEqual(folderFileWrapper2?.fileWrappers?.count, 2)
    }
    
    func testDynamicFolderWithUntrackedImagesAndTrackedMetaDataWrites() async throws {
        // Arrange
        let tmpURL = Utilities.makeTestDocumentTmpURL()
        try FileManager.default.createDirectory(at: tmpURL, withIntermediateDirectories: false, attributes: nil)
        let folderMapTestWrapper = try FileWrapper(url: tmpURL, options: .immediate)
        
        let folderItem = DynamicFolderMapItem(filename: "test?", supportedUntrackedTypes: [.png: UIImageFileMapItem.self])
        let metaDataItem = CodableFileMapItem<MockMetaData>(filename: "metaData.json")
        folderItem.addChild(metaDataItem)
        
        folderItem.attachMapToExistingDocumentFileWrapper(folderMapTestWrapper)
        
        // Act
        let mockMetaData = MockMetaData(id: "ID", name: "Test")
        metaDataItem.setContent(mockMetaData)
        folderItem.untrackedChildren = [red, green, blue, yellow, purple].imageFileMapItems
        
        let folderFileWrapper = folderItem.fileWrapper
        try folderFileWrapper?.write(to: tmpURL, options: .atomic, originalContentsURL: nil)
        
        let relativeChildURLs = try FileManager.default.contentsOfDirectory(at: tmpURL, includingPropertiesForKeys: nil, options: .producesRelativePathURLs)
     
        // Assert
        XCTAssertEqual(relativeChildURLs.count, 6)
        
        let folderWrapperForReading = try FileWrapper(url: tmpURL, options: .immediate)
        
        let folderItemForReading = DynamicFolderMapItem(filename: "test?", supportedUntrackedTypes: [.png: UIImageFileMapItem.self])
        let metaDataItemForReading = CodableFileMapItem<MockMetaData>(filename: "metaData.json")
        folderItemForReading.addChild(metaDataItemForReading)
        
        folderItemForReading.attachMapToExistingDocumentFileWrapper(folderWrapperForReading)
        
        let metaDataForReading = try metaDataItemForReading.decodeContent()
        XCTAssertEqual(metaDataForReading, mockMetaData)
        
        let untrackedChildImageItemsForReading = folderItemForReading.untrackedChildren.compactMap { $0 as? UIImageFileMapItem }
        XCTAssertEqual(untrackedChildImageItemsForReading.count, 5)
        
        let decodedImages = try untrackedChildImageItemsForReading.map { child in
            try child.decodeContent()
        }
        
        XCTAssertEqual(decodedImages.count, 5)
    }
}

extension Array where Element == UIImage {
    var imageFileMapItems: [UIImageFileMapItem] {
        return self.map {
            let item = UIImageFileMapItem(filename: "\(UUID().uuidString).png")
            item.contentCache = $0
            return item
        }
    }
}
