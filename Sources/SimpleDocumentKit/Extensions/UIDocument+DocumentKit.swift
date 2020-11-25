//
//  UIDocument+DocumentKit.swift
//  DocumentKit
//
//  Created by Overview on 3/5/19.
//  Copyright © 2019 John Davis. All rights reserved.
//

#if !os(macOS)
import UIKit
#endif

public extension UIDocument {
    var documentStateString: String {
        var returnStates: [String] = []
        
        if documentState.contains(.normal) {
            returnStates.append("Normal")
        }
        if documentState.contains(.closed) {
            returnStates.append("Closed")
        }
        if documentState.contains(.inConflict) {
            returnStates.append("In Conflict")
        }
        if documentState.contains(.savingError) {
            returnStates.append("Saving Error")
        }
        if documentState.contains(.editingDisabled) {
            returnStates.append("Editing disabled.")
        }
        if documentState.contains(.progressAvailable) {
            returnStates.append("Progress Available.")
        }
        
        return returnStates.joined(separator: " - ")
    }
}
