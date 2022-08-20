//
//  UInt64.swift
//  
//
//  Created by 韦烽传 on 2022/8/20.
//

import Foundation

public extension UInt64 {
    
    /**
     字节
     */
    func bytes() -> [UInt8] {
        
        var bytes: [UInt8] = []
        
        bytes.append(UInt8((self & 0xff00000000000000 ) >> 56))
        bytes.append(UInt8((self & 0x00ff000000000000 ) >> 48))
        bytes.append(UInt8((self & 0x0000ff0000000000 ) >> 40))
        bytes.append(UInt8((self & 0x000000ff00000000 ) >> 32))
        bytes.append(UInt8((self & 0x00000000ff000000 ) >> 24))
        bytes.append(UInt8((self & 0x0000000000ff0000 ) >> 16))
        bytes.append(UInt8((self & 0x000000000000ff00 ) >> 8))
        bytes.append(UInt8((self & 0x00000000000000ff ) >> 0))
        
        return bytes
    }
}
