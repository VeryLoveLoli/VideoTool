//
//  VideoFileEncodeProtocol.swift
//  
//
//  Created by 韦烽传 on 2022/8/20.
//

import Foundation
import VideoToolbox

/**
 视频文件编码协议
 */
public protocol VideoFileEncodeProtocol {
    
    /**
     视频文件编码
     
     - parameter    encode:     编码
     - parameter    bytes:      字节
     */
    func videoFileEncode(_ encode: VideoFileEncode, bytes: [UInt8])
    
    /**
     视频文件编码
     
     - parameter    encode:     编码
     - parameter    path:       路径
     - parameter    error:      错误
     */
    func videoFileEncode(_ encode: VideoFileEncode, path: String, error: Error?)
}
