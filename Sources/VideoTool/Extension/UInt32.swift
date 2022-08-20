//
//  UInt32.swift
//  
//
//  Created by 韦烽传 on 2022/8/20.
//

import Foundation

public extension UInt32 {
    
    /**
     字节
     */
    func bytes() -> [UInt8] {
        
        var bytes: [UInt8] = []
        
        bytes.append(UInt8((self & 0xff000000 ) >> 24))
        bytes.append(UInt8((self & 0x00ff0000 ) >> 16))
        bytes.append(UInt8((self & 0x0000ff00 ) >> 8))
        bytes.append(UInt8((self & 0x000000ff ) >> 0))
        
        return bytes
    }
}
