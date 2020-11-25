//
//  NSFileVersion+UIDocument.swift
//  DocumentKit
//
//  Created by Overview on 3/6/19.
//  Copyright © 2019 John Davis. All rights reserved.
//

import Foundation
#if !os(macOS)
import UIKit
#endif

extension NSFileVersion {
    /// Choose a version of a UIDocument and discard the others.
    ///
    /// - Parameters:
    ///   - version: Chosen version
    ///   - document: UIDocument to have version chosen for
    ///   - completion: Completion block to be invoked when choice is finished processing. Will be invoked on main queue
    public static func chooseVersion(_ version: NSFileVersion, ofConflictedDocument document: UIDocument, completion:((Bool) -> Void)?) {
        guard document.documentState.contains(.inConflict) else { return }
        
        let currentVersion = NSFileVersion.currentVersionOfItem(at: document.fileURL)
        
        if version == currentVersion {
            //remove other versions
            do {
                try NSFileVersion.removeOtherVersionsOfItem(at: document.fileURL)
                NSFileVersion.unresolvedConflictVersionsOfItem(at: document.fileURL)?.forEach { $0.isResolved = true }
                DispatchQueue.main.async {
                    completion?(true)
                }
            } catch {
                print("Unable to remove other versions of document.")
                DispatchQueue.main.async {
                    completion?(false)
                }
            }
        } else {
            // keep a different version than current
            do {
                try version.replaceItem(at: document.fileURL, options: [])
                try NSFileVersion.removeOtherVersionsOfItem(at: document.fileURL)
                document.revert(toContentsOf: document.fileURL, completionHandler: { success in
                    if success {
                        NSFileVersion.unresolvedConflictVersionsOfItem(at: document.fileURL)?.forEach { $0.isResolved = true }
                    }
                    DispatchQueue.main.async {
                        completion?(success)
                    }
                })
            } catch {
                print("Unable to replace document with version.")
                DispatchQueue.main.async {
                    completion?(false)
                }
            }
        }
    }
}
