//
//  ICloudDefaults.swift
//  DocumentKit
//
//  Created by Overview on 2/9/19.
//  Copyright © 2019 John Davis. All rights reserved.
//

import Foundation

public struct ICloudDefaults {
    /// Standard iCloudDefaults that returns an instance wrapping `UserDefaults`
    public static var `standard` = ICloudDefaults()
    
    /// Boolean providing defaults object. The default initializer will set this to `UserDefaults.standard`
    private var defaults: BooleanUserDefaultsProtocol
    
    /// Initialize ICloudDefaults Interface
    ///
    /// - Parameter defaults: Point to inject a boolean storing data structure. By default this will be set to `UserDefaults.standard`
    public init(defaults: BooleanUserDefaultsProtocol = UserDefaults.standard) {
        self.defaults = defaults
    }
    
    public var iCloudOn: Bool {
        get {
            return UserDefaults.standard.bool(forKey: "iCloudOn")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "iCloudOn")
        }
    }
    
    var iCloudWasOn: Bool {
        get {
            return UserDefaults.standard.bool(forKey: "iCloudWasOn")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "iCloudWasOn")
        }
    }
    
    var iCloudPrompted: Bool {
        get {
            return UserDefaults.standard.bool(forKey: "iCloudPrompted")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "iCloudPrompted")
        }
    }
}
