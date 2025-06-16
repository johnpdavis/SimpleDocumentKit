//
//  RootMapItem.swift
//  
//
//  Created by John Davis on 2/4/22.
//

import Foundation

public class RootMapItem: FolderMapItem {
    public static var `default`: RootMapItem {
        RootMapItem(filename: "ROOT_ITEM_SHOULD_NOT_USE_FILENAME")
    }
}
