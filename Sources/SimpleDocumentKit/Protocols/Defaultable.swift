//
//  DocumentKitRoot.swift
//  DocumentKit
//
//  Created by Overview on 2/8/19.
//  Copyright © 2019 John Davis. All rights reserved.
//

import Foundation

public protocol Defaultable {
    static func `default`() -> Self
}
