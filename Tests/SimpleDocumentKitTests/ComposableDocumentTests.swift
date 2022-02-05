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
        let testDocURL = Utilities.makeTestDocumentTmpURL()
        print(testDocURL)
        
        let docSetup = Utilities.makeComposedTestDocument(at: testDocURL)
        
        let composableDocument = docSetup.composableDocument
        let metaDataItem = docSetup.metaDataFileItem
        
        // Document should NOT YET exist in the file system structure.
        XCTAssertFalse(FileManager.default.fileExists(atPath: testDocURL.path))
        
        // Metadata of a freshly opened NEW document? Should fail to decode since there should be no data
        XCTAssertNil(metaDataItem.fileWrapper)
        XCTAssertThrowsError(try metaDataItem.decodeContent())
        
        // Save the document
        await composableDocument.save(to: testDocURL, for: .forCreating)
        
        // Document should now exist in the folder structure.
        XCTAssertTrue(FileManager.default.fileExists(atPath: testDocURL.path))
        
        let imagesURL = testDocURL.appendingPathComponent("images", isDirectory: true)
        XCTAssertTrue(FileManager.default.fileExists(atPath: imagesURL.path))
        
        let originalsURL = imagesURL.appendingPathComponent("originals", isDirectory: true)
        XCTAssertTrue(FileManager.default.fileExists(atPath: originalsURL.path))
    }
    
    @MainActor
    func testEmptyDocumentAutoSaveWithMetaData() async throws {
        let testDocURL = Utilities.makeTestDocumentTmpURL()
        print(testDocURL)
        let docSetup = Utilities.makeComposedTestDocument(at: testDocURL)
        
        let composableDocument = docSetup.composableDocument
        let metaDataItem = docSetup.metaDataFileItem
        
        await composableDocument.save(to: testDocURL, for: .forCreating)
        
        // Metadata of a freshly opened NEW document? Should fail to decode since there should be no data
        XCTAssertNil(metaDataItem._fileWrapper)
        XCTAssertThrowsError(try metaDataItem.decodeContent())
        
        await composableDocument.open()
        
        let mockData = MockMetaData(id: "TestID", name: "TestName")
        metaDataItem.setContent(mockData)

        // the newly set content SHOULD be accessible in the content cache directly, AND by the decode method's upfront check.
        XCTAssertEqual(metaDataItem.contentCache, mockData)
        XCTAssertEqual(try! metaDataItem.decodeContent(), mockData)

        try await composableDocument.autoSaveAndClose()

        let metaDataURL = testDocURL.appendingPathComponent("metaData.json", isDirectory: false)
        XCTAssertTrue(FileManager.default.fileExists(atPath: metaDataURL.path))

        let data = try Data(contentsOf: metaDataURL)
        let metaDataFromFileSystem = try JSONDecoder().decode(MockMetaData.self, from: data)

        XCTAssertEqual(mockData, metaDataFromFileSystem)
    }
    
    @MainActor
    func testDocumentAutoSaveWithMetaDataOverwrite() async throws {
        let testDocURL = Utilities.makeTestDocumentTmpURL()
        let docSetup = Utilities.makeComposedTestDocument(at: testDocURL)
        
        let composableDocument = docSetup.composableDocument
        let metaDataItem = docSetup.metaDataFileItem
        
        await composableDocument.save(to: testDocURL, for: .forCreating)
        await composableDocument.open()
        
        // FIRST POPULATION OF META DATA:
        let mockData = MockMetaData(id: "TestID", name: "TestName")
        metaDataItem.setContent(mockData)
        
        await composableDocument.autosave()
        
        let metaDataURL = testDocURL.appendingPathComponent("metaData.json", isDirectory: false)
        XCTAssertTrue(FileManager.default.fileExists(atPath: metaDataURL.path))
        let data = try Data(contentsOf: metaDataURL)
        let metaDataFromFileSystem = try JSONDecoder().decode(MockMetaData.self, from: data)
        XCTAssertEqual(mockData, metaDataFromFileSystem)
        
        // SECOND POPULATION OF META DATA:
        let mockData2 = MockMetaData(id: "TestID2", name: "TestName2")
        metaDataItem.setContent(mockData2)
        
        await composableDocument.autosave()
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: metaDataURL.path))
        let data2 = try Data(contentsOf: metaDataURL)
        let metaDataFromFileSystem2 = try JSONDecoder().decode(MockMetaData.self, from: data2)
        XCTAssertNotEqual(mockData, metaDataFromFileSystem2)
        XCTAssertEqual(mockData2, metaDataFromFileSystem2)
    }
}