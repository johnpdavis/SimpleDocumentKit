//
//  JsonDocumentManager.swift
//  DocumentKit
//
//  Created by Overview on 2/8/19.
//  Copyright © 2019 John Davis. All rights reserved.
//

import UIKit

public class JsonDocumentManager: LocalFileSystemSource {
    public var iCloudManager = iCloudDocumentManager()

    public init(rootURL: URL) {
        self.rootURL = rootURL
        
        iCloudManager.localFileSystemSource = self
    }
    
    public let rootURL: URL
    
    /// URL for document with provided name.
    ///
    /// - Parameter name: Name of document with extension
    /// - Returns: returns URL of document, or nil, if it could not be found or created
    func urlForDocument(name: String) -> URL? {
        if iCloudManager.iCloudOn {
            return iCloudManager.iCloudURLForDocument(filename: name)
        } else {
            return rootURL.appendingPathComponent(name)
        }
    }
    
    /// Will attempt to return a JsonPackageDocument with the provided name. This method will look in the designated storage area, iCloud or Local, depending on the app's settings. If the file does not exist, it will be created.
    ///
    /// - Parameters:
    ///   - name: Name of package with extension
    ///   - completion: Completion block to be invoked with retrieve or created file.
    public func document<DATAROOT: JsonDocData, METADATAROOT: JsonDocData>(name: String, completion:((JsonPackageDocument<DATAROOT, METADATAROOT>?) -> ())?) {
        // If the file doesnt exist, make it. Otherwise return it.
        guard let url = urlForDocument(name: name) else { completion?(nil); return }
        
        if documentExistsWithName(name) {
            let document = JsonPackageDocument<DATAROOT, METADATAROOT>(fileURL: url)
            completion?(document)
        } else {
            let document = JsonPackageDocument<DATAROOT, METADATAROOT>(fileURL: url)
            document.save(to: url, for: .forCreating) { success in
                print("SAVED THE FILE For Creating")
                if success {
                    completion?(document)
                } else {
                    print("FAILED TO SAVE FILE")
                    completion?(nil)
                }
            }
        }
    }

    
    // TODO: This code likely has issues determining the existance of an iCloud file by URL.
    /// Will create the full document URL by invoking `urlForDocument(name:)` and ask NSFileManager if the URL exists.
    ///
    /// - Parameter name: Full name of document including extension.
    /// - Returns: True of document exists. Otherwise false.
    func documentExistsWithName(_ name: String) -> Bool {
        guard let fullFileURL = urlForDocument(name: name) else { fatalError("Cannot construct full Document file URL") }
        
        return FileManager.default.fileExists(atPath:fullFileURL.path)
    }
    
    /// Will change document name by invoking move
    ///
    /// - Parameters:
    ///   - document: Document to move to newly named URL
    ///   - name: New name of document including extension
    ///   - completion: Completion closure to be invoked when rename is complete. Will be invoked on main queue
    public func renameDocument(document: UIDocument, name: String, completion: ((Bool) -> Void)?) {
        guard name != document.fileURL.lastPathComponent else {
            //nothing to rename
            DispatchQueue.main.async {
                completion?(false)
            }
            return
        }

        guard let newURL = urlForDocument(name: name) else {
            // cant make new URL
            DispatchQueue.main.async {
                completion?(false)
            }
            return
        }

        let originalURL = document.fileURL

        print("Invoking Move \(originalURL) \n=>\n\(newURL)")
        FileManager.default.moveUbiquitousItem(at: originalURL, to: newURL, completion: completion)
    }
}
