//
//  VideoFileDecodeProtocol.swift
//  
//
//  Created by 韦烽传 on 2022/8/20.
//

import Foundation
import VideoToolbox

/**
 视频文件解码协议
 */
public protocol VideoFileDecodeProtocol {
    
    /**
     视频文件解码
     
     - parameter    decode:                     解码
     - parameter    imageBuffer:                图像
     - parameter    presentationTimeStamp:      帧序
     - parameter    duration:                   帧时间
     */
    func videoFileDecode(_ decode: VideoFileDecode, imageBuffer: CVImageBuffer, presentationTimeStamp: CMTime, duration: CMTime)
    
    /**
     视频文件解码错误
     
     - parameter    decode:                     解码
     - parameter    status:                     状态
     */
    func videoFileDecode(_ decode: VideoFileDecode, status: OSStatus)
}
