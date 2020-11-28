//
//  DirectoryDispatchObserver.swift
//  Vantage Point
//
//  Created by John Davis on 6/21/20.
//  Copyright © 2020 John Davis. All rights reserved.
//

import Foundation

protocol DirectoryDispatchObserverDelegate: class {
    func directoryDispatchObserverDetectedChange(_ observer: DirectoryDispatchObserver)
}

open class DirectoryDispatchObserver {
    var url: URL
    
    weak var delegate: DirectoryDispatchObserverDelegate?
    
    var monitoredFileDescriptor: CInt = -1
    let monitoredDirectoryQueue = DispatchQueue(label: "com.johndavis.simpledocumentkit.Directorywatcher", attributes: DispatchQueue.Attributes.concurrent)
    var monitoredSource: DispatchSourceFileSystemObject?
    
    init(url: URL) {
        self.url = url
    }
    
    func startWatching() {
        _ = subscribeToEvents()
    }
    
    func stopWatching() {
        monitoredSource?.cancel()
    }

    private func subscribeToEvents() -> Bool {
        monitoredFileDescriptor = open(self.url.path, O_EVTONLY)
        
        if monitoredFileDescriptor < 0 {
            print("Failed to create file descriptor")
            return false
        }
        
        let events: DispatchSource.FileSystemEvent = .all
        
        monitoredSource = DispatchSource.makeFileSystemObjectSource(fileDescriptor: self.monitoredFileDescriptor, eventMask: events, queue: self.monitoredDirectoryQueue)
        
        let eventHandler: () -> Void = {
            print("Something happened at the path provided")
            self.delegate?.directoryDispatchObserverDetectedChange(self)
        }
        
        let cancelHandler: () -> Void = {
            monitoredDirectoryQueue.async {
                close(self.monitoredFileDescriptor)
                self.monitoredFileDescriptor = -1
                self.monitoredSource = nil
            }
        }
        
        monitoredSource?.setEventHandler(handler: eventHandler)
        monitoredSource?.setCancelHandler(handler: cancelHandler)
        monitoredSource?.resume()
        
        return true
    }
}
