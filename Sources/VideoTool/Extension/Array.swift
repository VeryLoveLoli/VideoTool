//
//  Array.swift
//  
//
//  Created by 韦烽传 on 2022/8/20.
//

import Foundation

public extension Array where Element == UInt8 {
    
    /**
     UInt32
     */
    func uint32() -> UInt32 {
        
        var value: UInt32 = 0
        
        if count == 4 {
            
            value += UInt32(self[0]) << 24
            value += UInt32(self[1]) << 16
            value += UInt32(self[2]) << 8
            value += UInt32(self[3]) << 0
        }
        
        return value
    }
    
    /**
     UInt64
     */
    func uint64() -> UInt64 {
        
        var value: UInt64 = 0
        
        if count == 8 {
            
            value += UInt64(self[0]) << 56
            value += UInt64(self[1]) << 48
            value += UInt64(self[2]) << 40
            value += UInt64(self[3]) << 32
            value += UInt64(self[4]) << 24
            value += UInt64(self[5]) << 16
            value += UInt64(self[6]) << 8
            value += UInt64(self[7]) << 0
        }
        
        return value
    }
}
