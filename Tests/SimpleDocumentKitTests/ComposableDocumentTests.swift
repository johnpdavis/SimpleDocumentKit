import XCTest
@testable import SimpleDocumentKit

final class ComposableDocumentTests: XCTestCase {
    
    @MainActor
    func testComposableDocumentLoad() async throws {
        let testDocURL = Utilities.createTestDocumentInFileSystem()
        let composableDoc = ComposableDocument(fileURL: testDocURL)
        
        await composableDoc.open()
        
        XCTAssertNotNil(composableDoc.mapRootItem.fileWrapper)
        XCTAssertNotNil(composableDoc.mapRootItem.fileWrapper?.fileWrappers)
        XCTAssertNotNil(composableDoc.mapRootItem.fileWrapper?.fileWrappers?["metaData.json"])
        XCTAssertNotNil(composableDoc.mapRootItem.fileWrapper?.fileWrappers?["images"])
        XCTAssertNotNil(composableDoc.mapRootItem.fileWrapper?.fileWrappers?["images"]?.fileWrappers)
        XCTAssertNotNil(composableDoc.mapRootItem.fileWrapper?.fileWrappers?["images"]?.fileWrappers?["originals"])
        XCTAssertNil(composableDoc.mapRootItem.fileWrapper?.fileWrappers?["images"]?.fileWrappers?["birds"])
    }
    
    @MainActor
    func testMapAssociation() async throws {
        // Arrange
        let testDocURL = Utilities.createTestDocumentInFileSystem()
        let composableDoc = ComposableDocument(fileURL: testDocURL)
        
        let metaDataItem = CodableFileMapItem<MockMetaData>(filename: "metaData.json")
        let imagesFolderItem = FolderMapItem(filename: "images")
        let originalsFolder = FolderMapItem(filename: "originals")
        
        // Act
        composableDoc.mapRootItem.addChild(metaDataItem)
        composableDoc.mapRootItem.addChild(imagesFolderItem)
        imagesFolderItem.addChild(originalsFolder)
        
        await composableDoc.open()
        
        //Assert
        XCTAssertEqual(2, composableDoc.mapRootItem.trackedChildren.count)
        
        let imagesItemChildInMap = composableDoc.mapRootItem.trackedChildren["images"] as! FolderMapItem
        XCTAssertEqual(1, imagesItemChildInMap.trackedChildren.count)
        
        XCTAssertNotNil(metaDataItem._fileWrapper)
        XCTAssertNotNil(imagesFolderItem._fileWrapper)
        XCTAssertNotNil(originalsFolder._fileWrapper)
    }
    
    @MainActor
    func testTestDocumentDecode() async throws {
        let testDocURL = Utilities.createTestDocumentInFileSystem()
        let docSetup = Utilities.makeComposedTestDocument(at: testDocURL)
        
        let composableDocument = docSetup.composableDocument
        let metaDataItem = docSetup.metaDataFileItem
        
        await composableDocument.open()
        
        let mockData = try metaDataItem.decodeContent()
        XCTAssertEqual(mockData.name, "testName")
        XCTAssertEqual(mockData.id, "testID")
    }
    
    @MainActor
    func testEmptyDocumentInitialSave() async throws {
        let testDocURL = Utilities.createTestDocumentTmpURL()
        print(testDocURL)
        
        let docSetup = Utilities.makeComposedTestDocument(at: testDocURL)
        
        let composableDocument = docSetup.composableDocument
        let metaDataItem = docSetup.metaDataFileItem
        
        await composableDocument.open()
        
        // Document should NOT YET exist in the file system structure.
        XCTAssertFalse(FileManager.default.fileExists(atPath: testDocURL.path))
        
        // Metadata of a freshly opened NEW document? Should fail to decode since there should be no data
        XCTAssertNotNil(metaDataItem.fileWrapper)
        XCTAssertThrowsError(try metaDataItem.decodeContent())
        
        composableDocument.updateChangeCount(.done)
        
        try await composableDocument.autoSaveAndClose()
        
        // Document should now exist in the folder structure.
        XCTAssertTrue(FileManager.default.fileExists(atPath: testDocURL.path))
        
        let imagesURL = testDocURL.appendingPathComponent("images", isDirectory: true)
        XCTAssertTrue(FileManager.default.fileExists(atPath: imagesURL.path))
        
        let originalsURL = imagesURL.appendingPathComponent("originals", isDirectory: true)
        XCTAssertTrue(FileManager.default.fileExists(atPath: originalsURL.path))
    }
    
    @MainActor
    func testEmptyDocumentSaveWithMetaData() async throws {
        let testDocURL = Utilities.createTestDocumentTmpURL()
        let docSetup = Utilities.makeComposedTestDocument(at: testDocURL)
        
        let composableDocument = docSetup.composableDocument
        let metaDataItem = docSetup.metaDataFileItem
        
        await composableDocument.open()
        
        // Metadata of a freshly opened NEW document? Should fail to decode since there should be no data
        XCTAssertNotNil(metaDataItem.fileWrapper)
        XCTAssertThrowsError(try metaDataItem.decodeContent())
        
        let mockData = MockMetaData(id: "TestID", name: "TestName")
        try metaDataItem.setContent(mockData)
        
        // the newly set content SHOULD be accessible in the content cache directly, AND by the decode method's upfront check.
        XCTAssertEqual(metaDataItem.contentCache, mockData)
        XCTAssertEqual(try metaDataItem.decodeContent(), mockData)
    }
}
