//
//  iCloudQueryCoordinator.swift
//  DocumentKit
//
//  Created by Overview on 2/10/19.
//  Copyright © 2019 John Davis. All rights reserved.
//

import Foundation

public class iCloudDocumentQueryCoordinator: DocumentQueryCoordinator {
    init(documentExtension: String) {
        super.init(searchScope: NSMetadataQueryUbiquitousDocumentsScope, documentExtension: documentExtension)
    }
}
