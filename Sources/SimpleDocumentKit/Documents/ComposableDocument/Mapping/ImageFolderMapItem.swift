//
//  ImageFolderMapItem.swift
//  
//
//  Created by John Davis on 2/5/22.
//

import UIKit
import UniformTypeIdentifiers

public class ImageFolderMapItem: DynamicFolderMapItem {

    public var images: [UIImageFileMapItem] {
        untrackedChildren.compactMap { $0 as? UIImageFileMapItem }
    }
    
    public required init(filename: String) {
        let imageFileTypes: [UTType : FileMapItemBase.Type] = [.png: UIImageFileMapItem.self,
                                                               .jpeg: UIImageFileMapItem.self]
        
        super.init(filename: filename, supportedUntrackedTypes: imageFileTypes)
    }
    
    public func setImages(_ images: [UIImage]) {
        let items: [UIImageFileMapItem] = images.map { image in
            let item = UIImageFileMapItem(filename: "\(UUID().uuidString).png")
            item.setImage(image)
            return item
        }
        
        untrackedChildren = items
    }
}
