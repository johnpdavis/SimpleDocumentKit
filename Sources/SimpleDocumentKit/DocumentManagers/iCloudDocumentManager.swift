//
//  iCloudDocumentManager.swift
//  DocumentKit
//
//  Created by Overview on 2/9/19.
//  Copyright © 2019 John Davis. All rights reserved.
//

import Combine
import Foundation

public class iCloudDocumentManager: BaseDocumentManager {
    
    // MARK: Properties
    
    var iCloudOn: Bool { return ICloudDefaults.standard.iCloudOn }
    public var iCloudRootURL: URL?
    public var currentiCloudURLs: [URL] {
        return coordinator.urls
    }
    
    // MARK: Initializers
    init(localDocumentRoot: URL, documentExtension: String) {
        let coordinator = iCloudDocumentQueryCoordinator(documentExtension: documentExtension)
        super.init(localDocumentRoot: localDocumentRoot, coordinator: coordinator)
    }

    func iCloudURLForDocument(filename: String) -> URL? {
        return iCloudRootURL?.appendingPathComponent("Documents").appendingPathComponent(filename)
    }
    
    public func initializeiCloudAccess(completion:@escaping ((Bool, URL?) -> Void)) {
        DispatchQueue.global(qos: .default).async {
            if let url = FileManager.default.url(forUbiquityContainerIdentifier: nil) {
                self.iCloudRootURL = url
                DispatchQueue.main.async {
                    completion(true, url)
                }
            } else {
                DispatchQueue.main.async {
                    completion(false, nil)
                }
            }
        }
    }
    
    public func scaniCloudOptIn(promptForOptIn:@escaping (() -> ()), completion: @escaping (() -> Void)) {
        initializeiCloudAccess(completion: { iCloudAvailable, _ in
            if !iCloudAvailable {
                print("iCloud is not available")
                // If iCloud isn't available, set promoted to no (so we can ask them next time it becomes available)
                ICloudDefaults.standard.iCloudPrompted = false
                
                // If iCloud was toggled on previously, warn user that the docs will be loaded locally and data may be lost
                if ICloudDefaults.standard.iCloudWasOn {
                    print("DATA WAS PROBABLY LOST")
                }
                
                // No matter what, iCloud isn't available so switch it to off.
                ICloudDefaults.standard.iCloudWasOn = false
                ICloudDefaults.standard.iCloudOn = false
            } else {
                // Ask user if want to turn on iCloud if it's available and we haven't asked already
                if !ICloudDefaults.standard.iCloudOn && !ICloudDefaults.standard.iCloudPrompted {
                    ICloudDefaults.standard.iCloudPrompted = true
                    
                    promptForOptIn()
                }
                
                // If iCloud newly switched on, move local docs to iCloud
                if ICloudDefaults.standard.iCloudOn && !ICloudDefaults.standard.iCloudWasOn {
                    self.localToCloud()
                }
                
                // If iCloud newly switched off, move iCloud docs to Local
                if !ICloudDefaults.standard.iCloudOn && ICloudDefaults.standard.iCloudWasOn {
                    self.cloudToLocal()
                }
                
                // Start querying iCloud for files, whether on or off
                self.coordinator.startQuery()
                
                // No matter what, refresh with current value of iCloudOn
                ICloudDefaults.standard.iCloudWasOn = ICloudDefaults.standard.iCloudOn
            }
            
            completion()
        })
    }
    
    func moveFilesToiCloud() {
        let localURLs = try? FileManager.default.contentsOfDirectory(at: localDocumentRoot, includingPropertiesForKeys: nil, options: []) else { return }
        
        localURLs.forEach { localURL in
            let filename = localURL.lastPathComponent
            guard let newURL = iCloudURLForDocument(filename: filename) else { return }
            
            DispatchQueue.global(qos: .default).async {
                do {
                    try FileManager.default.setUbiquitous(true, itemAt: localURL, destinationURL: newURL)
                    print("--- Moved \n\(localURL)\n=>\n\(newURL)\n---")
                } catch {
                    print("Failed to move file to iCloud: \(error.localizedDescription)")
                }
            }
        }
    }

    func moveiCloudToLocal() {
        coordinator.urls.forEach { iCloudURL in
            let filename = iCloudURL.lastPathComponent
            guard let newURL = localFileSystemSource?.rootURL.appendingPathComponent(filename) else { return }
            
            DispatchQueue.global(qos: .default).async {
                var error: NSError?
                let fileCoordinator = NSFileCoordinator()
                fileCoordinator.coordinate(readingItemAt: iCloudURL, options: .withoutChanges, error: &error) { safeURL in
                    do {
                       try FileManager.default.setUbiquitous(false, itemAt: safeURL, destinationURL: newURL)
                        print("--- Moved\n\(safeURL)\n=>\n\(newURL)\n")
                    } catch {
                        print("Failed to copy file: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    func iCloudFileExists(URL: URL) -> Bool {
        return coordinator.urls.contains(URL)
    }
}
