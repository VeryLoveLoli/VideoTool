//
//  VideoDecodeProtocol.swift
//  
//
//  Created by 韦烽传 on 2022/8/20.
//

import Foundation
import VideoToolbox

/**
 视频解码协议
 */
public protocol VideoDecodeProtocol {
    
    /**
     解码图像缓冲
     
     - parameter    decode:                     解码
     - parameter    imageBuffer:                图像缓冲
     - parameter    presentationTimeStamp:      帧序
     - parameter    duration:                   帧时间
     */
    func videoDecode(_ decode: VideoDecode, imageBuffer: CVImageBuffer, presentationTimeStamp: CMTime, duration: CMTime)
}
