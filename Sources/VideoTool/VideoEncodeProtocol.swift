//
//  VideoEncodeProtocol.swift
//  
//
//  Created by 韦烽传 on 2022/8/20.
//

import Foundation
import VideoToolbox

/**
 视频编码协议
 */
public protocol VideoEncodeProtocol {
    
    /**
     编码数据
     
     - parameter    encode:                     编码
     
     - parameter    vps:                        VPS数据（`kCMVideoCodecType_HEVC`才有此数据）
     - parameter    sps:                        SPS数据（关键帧才有数据）
     - parameter    pps:                        PPS数据（关键帧才有数据）
     
     - parameter    bytes:                      帧数据
     - parameter    isKey:                      是否关键帧
     - parameter    presentationTimeStamp:      帧序
     - parameter    duration:                   帧时间
     */
    func videoEncode(_ encode: VideoEncode, vps: [UInt8]?, sps: [UInt8], pps: [UInt8], bytes: [UInt8], isKey: Bool, presentationTimeStamp: CMTime, duration: CMTime)
}
