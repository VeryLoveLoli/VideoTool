//
//  CMVideoDimensions.swift
//  
//
//  Created by 韦烽传 on 2022/8/20.
//

import Foundation
import VideoToolbox

public extension CMVideoDimensions {
    
    static let wh192x144 = CMVideoDimensions(width: 192, height: 144)
    static let wh352x288 = CMVideoDimensions(width: 352, height: 288)
    static let wh480x360 = CMVideoDimensions(width: 480, height: 360)
    static let wh640x480 = CMVideoDimensions(width: 640, height: 480)
    static let wh960x540 = CMVideoDimensions(width: 960, height: 540)
    static let wh1024x768 = CMVideoDimensions(width: 1024, height: 768)
    static let wh1280x720 = CMVideoDimensions(width: 1280, height: 720)
    static let wh1920x1080 = CMVideoDimensions(width: 1920, height: 1080)
    static let wh1920x1440 = CMVideoDimensions(width: 1920, height: 1440)
    static let wh2592x1936 = CMVideoDimensions(width: 2592, height: 1936)
    static let wh3264x2448 = CMVideoDimensions(width: 3264, height: 2448)
    static let wh3840x2160 = CMVideoDimensions(width: 3840, height: 2160)
    static let wh4032x3024 = CMVideoDimensions(width: 4032, height: 3024)
    static let max = CMVideoDimensions(width: Int32.max, height: Int32.max)
}

extension CMVideoDimensions: Equatable {
    
    public static func == (lhs: CMVideoDimensions, rhs: CMVideoDimensions) -> Bool {
        
        lhs.width == rhs.width && lhs.height == rhs.height
    }
}
