//
//  Mocks.swift
//  
//
//  Created by John Davis on 2/4/22.
//

import Foundation

struct MockMetaData: Codable, Identifiable, Equatable {
    let id: String
    let name: String
}

struct MockData: Codable, Equatable {
    let data: String
}
