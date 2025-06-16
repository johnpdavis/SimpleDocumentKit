//
//  CompDocumentImageFolderTests.swift
//  
//
//  Created by John Davis on 2/5/22.
//

import SimpleDocumentKit
import XCTest

class CompDocumentImageFolderTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testDocumentAutoSaveWithImageSubFolder() async throws {
        // Arrange Document
        let testDocURL = Utilities.makeTestDocumentTmpURL()
        let composableDoc = ComposableDocument(fileURL: testDocURL)
        
        let metaDataItem = CodableFileMapItem<MockMetaData>(filename: "metaData.json")
        let originalsFolder = ImageFolderMapItem(filename: "originals")
        
        composableDoc.mapRootItem.addChild(metaDataItem)
        composableDoc.mapRootItem.addChild(originalsFolder)
        
        // Arrange Contents
        let blue = UIImage(named: "blue", in: .module, with: nil)!
        let green = UIImage(named: "green", in: .module, with: nil)!
        let purple = UIImage(named: "purple", in: .module, with: nil)!
        let red = UIImage(named: "red", in: .module, with: nil)!
        let yellow = UIImage(named: "yellow", in: .module, with: nil)!
        
        let metaData = MockMetaData(id: "ID", name: "Gallerydo")
        let images = [blue, green, purple, yellow, red]
        
        // Act
        try await composableDoc.save(to: testDocURL, for: .forCreating)
        await composableDoc.open()
        
        metaDataItem.setContent(metaData)
        originalsFolder.setImages(images)
        
        await composableDoc.autosave()
    }

}
