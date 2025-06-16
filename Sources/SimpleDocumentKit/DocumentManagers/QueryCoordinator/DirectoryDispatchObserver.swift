//
//  DirectoryDispatchObserver.swift
//  Vantage Point
//
//  Created by John Davis on 6/21/20.
//  Copyright © 2020 John Davis. All rights reserved.
//

import Combine
import Foundation

open class DirectoryDispatchObserver {
    var url: URL
    
    var monitoredFileDescriptor: CInt = -1
    let monitoredDirectoryQueue = DispatchQueue(label: "com.johndavis.simpledocumentkit.Directorywatcher", attributes: DispatchQueue.Attributes.concurrent)
    var monitoredSource: DispatchSourceFileSystemObject?
    
    var changeObservedSubject = PassthroughSubject<Bool, Never>()
    
    var childCancellables = Set<AnyCancellable>()
    var childMonitors: [DirectoryDispatchObserver] = []
    
    init(url: URL) {
        self.url = url
    }
    
    func startWatching() {
        stopWatching()
        _ = subscribeToEvents()
    }
    
    func stopWatching() {
        monitoredSource?.cancel()
        childMonitors.forEach { $0.stopWatching() }
        childMonitors = []
        childCancellables.removeAll()
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
            self.changeObservedSubject.send(true)
        }
        
        let cancelHandler: () -> Void = {
            close(self.monitoredFileDescriptor)
            self.monitoredFileDescriptor = -1
            self.monitoredSource = nil
        }
        
        monitoredSource?.setEventHandler(handler: eventHandler)
        monitoredSource?.setCancelHandler(handler: cancelHandler)
        monitoredSource?.resume()
        
        monitorSubdirectories()
        
        return true
    }
    
    func monitorSubdirectories() {
        // Monitor subdirectories
        if let children = try? FileManager.default.contentsOfDirectory(at: self.url, includingPropertiesForKeys: [.isDirectoryKey]) {
            for child in children {
                var isDirectory: ObjCBool = false
                
                if FileManager.default.fileExists(atPath: child.path, isDirectory: &isDirectory), isDirectory.boolValue {
                    let subdirectoryMonitor = DirectoryDispatchObserver(url: child)
                    subdirectoryMonitor.changeObservedSubject
                        .eraseToAnyPublisher()
                        .debounce(for: 0.2, scheduler: DispatchQueue.main)
                        .sink { [weak self] _ in
                            self?.changeObservedSubject.send(true)
                        }
                        .store(in: &childCancellables)
                    childMonitors.append(subdirectoryMonitor)
                    subdirectoryMonitor.startWatching()
                }
            }
        }
    }
}
