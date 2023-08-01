//
//  ComposableDocumentManagerTests.swift
//  
//
//  Created by John Davis on 2/6/22.
//

@testable import SimpleDocumentKit
import XCTest

extension MockMetaData: ManageableDocumentMetaData { }

class MockComposableDocument: ComposableDocument, ManageableMetaDataContaining, ResettableDocument {
    typealias METADATA = MockMetaData
    
    let metaDataItem = CodableFileMapItem<MockMetaData>(filename: "metaData.json")
    
    var metaData: MockMetaData? {
        get {
            do {
                return try metaDataItem.decodeContent()
            } catch {
                print("Caught error getting meta data: \(error)")
                return nil
            }
        }
        
        set {
            metaDataItem.setContent(newValue)
        }
    }
    
    func resetComposableMap() {
        metaDataItem.contentCache = nil
        updateChangeCount(.done)
    }
    
    override required init(fileURL url: URL) {
        super.init(fileURL: url)
        mapRootItem.addChild(metaDataItem)
    }
}

class ComposableDocumentManagerTests: XCTestCase {
    @MainActor
    func testComposableDocumentManagerInit() async throws {
        let rootArea = Utilities.makeTestDocumentTmpRootURL()
        let documentDirectoryName = "UnitTestDocuments"
        let ext = ".unitTest"
        
        let docAreaURL = rootArea.appendingPathComponent(documentDirectoryName, isDirectory: true)
        try FileManager.default.createDirectory(at: docAreaURL, withIntermediateDirectories: true)
        
        let manager = ManagedDocumentManager<MockComposableDocument>(localDocumentRoot: rootArea, documentDirectoryName: documentDirectoryName, managedDocumentExtension: ext, ubiquityContainerIdentifier: "unittest.test", initializeiCloudAccess: false)
        
        XCTAssertEqual(manager.managedDocumentDirectory, docAreaURL)
        
        let mock1URL = docAreaURL.appendingPathComponent("mock1.unitTest", isDirectory: true)
        let metaData1 = MockMetaData(id: "1", name: "Mock1")
        let mock1 = MockComposableDocument(fileURL: mock1URL)
        await mock1.save(to: mock1URL, for: .forCreating)
        await mock1.open()
        mock1.metaData = metaData1
        try await mock1.autoSaveAndClose()
        
        let mock2URL = docAreaURL.appendingPathComponent("mock2.unitTest", isDirectory: true)
        let metaData2 = MockMetaData(id: "2", name: "Mock2")
        let mock2 = MockComposableDocument(fileURL: mock2URL)
        await mock2.save(to: mock2URL, for: .forCreating)
        await mock2.open()
        mock2.metaData = metaData2
        try await mock2.autoSaveAndClose()
        
        let urls = try FileManager.default.contentsOfDirectory(at: docAreaURL, includingPropertiesForKeys: nil, options: [])
        XCTAssertEqual(urls.count, 2)
        
        // Force the processing to short circuit the publisher.
        let result = try! manager.localDocumentManager.coordinator.processFiles()
        await manager.processLocalResult(result)
        
        XCTAssertEqual(manager.localIDToDoc.count, 2)
        
        let doc1 = manager.localIDToDoc["1"]
        await doc1?.open()
        XCTAssertEqual(doc1?.metaData, metaData1)
        
        let doc2 = manager.localIDToDoc["2"]
        await doc2?.open()
        XCTAssertEqual(doc2?.metaData, metaData2)
    }
}
