//
//  Data.swift
//  
//
//  Created by 韦烽传 on 2022/8/20.
//

import Foundation

public extension Data {
    
    /**
     字节
     */
    func bytes() -> [UInt8] {
        
        return [UInt8](self)
    }
}
