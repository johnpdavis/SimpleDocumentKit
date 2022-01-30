//
//  BooleanUserDefaultsProtocol.swift
//  DocumentKit
//
//  Created by Overview on 3/6/19.
//  Copyright © 2019 John Davis. All rights reserved.
//

import Foundation

public protocol BooleanUserDefaultsProtocol {
    func bool(forKey defaultName: String) -> Bool
    func set(_ newValue: Bool, forKey: String)
}


