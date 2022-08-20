//
//  VideoDecode.swift
//  
//
//  Created by 韦烽传 on 2022/8/20.
//

import Foundation
import VideoToolbox

import Print

/**
 视频解码
 */
open class VideoDecode {
    
    /// 会话
    open internal(set) var session: VTDecompressionSession?
    /// 编码类型（仅支持 `kCMVideoCodecType_H264`、`kCMVideoCodecType_HEVC`）
    open internal(set) var type: CMVideoCodecType?
    /// 描述
    open internal(set) var description: CMVideoFormatDescription?
    /// 尺寸
    open internal(set) var dimensions: CMVideoDimensions?
    /// VPS数据（`kCMVideoCodecType_HEVC`才有值）
    open internal(set) var vps: [UInt8]? = nil
    /// SPS数据
    open internal(set) var sps: [UInt8] = []
    /// PPS数据
    open internal(set) var pps: [UInt8] = []
    
    /// 协议
    open var delegate: VideoDecodeProtocol?
    
    /**
     初始化
     */
    public init() {
        
    }
    
    /**
     刷新配置
     
     - parameter    type:           编码类型（仅支持 `kCMVideoCodecType_H264`、`kCMVideoCodecType_HEVC`）
     - parameter    vps:            VPS数据（`kCMVideoCodecType_HEVC`才有值）
     - parameter    sps:            SPS数据
     - parameter    pps:            PPS数据
     - parameter    isRealTime:     是否实时解码
     - parameter    threadCount:    线程数
     */
    @discardableResult
    open func refreshConfiguration(_ type: CMVideoCodecType = kCMVideoCodecType_H264,
                              vps: [UInt8]? = nil,
                              sps: [UInt8],
                              pps: [UInt8],
                              isRealTime: Bool = true,
                              threadCount: Int = 1) -> OSStatus {
        
        if self.type == type
            && self.vps == vps
            && self.sps == sps
            && self.pps == pps
            && description != nil
            && session != nil {
            
            return noErr
        }
        
        if session != nil {
            
            VTDecompressionSessionInvalidate(session!)
        }
        
        description = nil
        session = nil
        
        self.type = nil
        self.vps = nil
        self.sps = []
        self.pps = []
        
        let spsAddress = sps.withUnsafeBytes { body -> UnsafePointer<UInt8> in
            
            let bind = body.bindMemory(to: UInt8.self)
            
            return bind.baseAddress!
        }
        
        let ppsAddress = pps.withUnsafeBytes { body -> UnsafePointer<UInt8> in
            
            let bind = body.bindMemory(to: UInt8.self)
            
            return bind.baseAddress!
        }
        
        var status = noErr
        
        switch type {
            
        case kCMVideoCodecType_H264:
            
            status = CMVideoFormatDescriptionCreateFromH264ParameterSets(allocator: kCFAllocatorDefault, parameterSetCount: 2, parameterSetPointers: [spsAddress, ppsAddress], parameterSetSizes: [sps.count, pps.count], nalUnitHeaderLength: 4, formatDescriptionOut: &description)
            
        case kCMVideoCodecType_HEVC:
            
            guard let vps = vps else {
                
                Print.error("\(kCMVideoCodecType_HEVC) vps nil")
                return -1
            }
            
            let vpsAddress = vps.withUnsafeBytes { body -> UnsafePointer<UInt8> in
                
                let bind = body.bindMemory(to: UInt8.self)
                
                return bind.baseAddress!
            }
            
            status = CMVideoFormatDescriptionCreateFromHEVCParameterSets(allocator: kCFAllocatorDefault, parameterSetCount: 3, parameterSetPointers: [vpsAddress, spsAddress, ppsAddress], parameterSetSizes: [vps.count, sps.count, pps.count], nalUnitHeaderLength: 4, extensions: nil, formatDescriptionOut: &description)
            
        default:
            
            Print.error("不支持 \(type)")
            return -1
        }
        
        guard status == noErr else {
            
            Print.error(NSError(domain: NSOSStatusErrorDomain, code: Int(status)).localizedDescription)
            return status
        }
        
        guard let description = description else {
            
            Print.error("description nil")
            return -1
        }
        
        let outputCallback: @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, OSStatus, VTDecodeInfoFlags, CVImageBuffer?, CMTime, CMTime) -> Void = { (decompressionOutputRefCon, sourceFrameRefCon, status, infoFlags, imageBuffer, presentationTimeStamp, presentationDuration) in
            
            guard let raw = UnsafeRawPointer.init(decompressionOutputRefCon) else {
                
                Print.error("decompressionOutputRefCon nil")
                return
            }
            
            let decode = Unmanaged<VideoDecode>.fromOpaque(raw).takeUnretainedValue()
            
            guard let buffer = imageBuffer else {
                
                Print.error("imageBuffer nil")
                return
            }
            
            decode.delegate?.videoDecode(decode, imageBuffer: buffer, presentationTimeStamp: presentationTimeStamp, duration: presentationDuration)
        }
        
        var outputCallbackRecord = VTDecompressionOutputCallbackRecord.init(decompressionOutputCallback: outputCallback, decompressionOutputRefCon: Unmanaged.passUnretained(self).toOpaque())
        
        /// 视频尺寸
        let dimensions = CMVideoFormatDescriptionGetDimensions(description)
        self.dimensions = dimensions
        
        /// 硬解必须是 kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange / kCVPixelFormatType_420YpCbCr8Planar
        var keyCallBlocks = kCFTypeDictionaryKeyCallBacks
        var valueCallBlocks = kCFTypeDictionaryValueCallBacks
        
        guard let imageBufferAttributes = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &keyCallBlocks, &valueCallBlocks) else {
            
            Print.error("imageBufferAttributes nil")
            return -1
        }
        
        let key1 = kCVPixelBufferPixelFormatTypeKey as NSString
        let key1Address = Unmanaged.passRetained(key1).autorelease().toOpaque()
        
        let value1 = NSNumber(value: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange)
        let value1Address = Unmanaged.passRetained(value1).autorelease().toOpaque()
        
        CFDictionaryAddValue(imageBufferAttributes, key1Address, value1Address)
        
        let key2 = kCVPixelBufferOpenGLCompatibilityKey as NSString
        let key2Address = Unmanaged.passRetained(key2).autorelease().toOpaque()
        
        let value2 = NSNumber(value: true)
        let value2Address = Unmanaged.passRetained(value2).autorelease().toOpaque()
        
        CFDictionaryAddValue(imageBufferAttributes, key2Address, value2Address)
        
        let key3 = kCVPixelBufferWidthKey as NSString
        let key3Address = Unmanaged.passRetained(key3).autorelease().toOpaque()
        
        let value3 = NSNumber(value: dimensions.width)
        let value3Address = Unmanaged.passRetained(value3).autorelease().toOpaque()
        
        CFDictionaryAddValue(imageBufferAttributes, key3Address, value3Address)
        
        let key4 = kCVPixelBufferHeightKey as NSString
        let key4Address = Unmanaged.passRetained(key4).autorelease().toOpaque()
        
        let value4 = NSNumber(value: dimensions.height)
        let value4Address = Unmanaged.passRetained(value4).autorelease().toOpaque()
        
        CFDictionaryAddValue(imageBufferAttributes, key4Address, value4Address)
        
        Print.debug("\n")
        Print.debug("imageBufferAttributes:")
        Print.debug(imageBufferAttributes)
        Print.debug("\n")
        
        /* 目前 `Dictionary` 强转 `CFDictionary` 可以了
        let imageBufferAttributes = [kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
                                 kCVPixelBufferOpenGLCompatibilityKey: 1,
                                               kCVPixelBufferWidthKey: dimensions.width,
                                              kCVPixelBufferHeightKey: dimensions.height] as [CFString : Any]
        print("Dictionary", imageBufferAttributes)
        print("Dictionary as CFDictionary", imageBufferAttributes as CFDictionary)
         */
        
        status = VTDecompressionSessionCreate(allocator: kCFAllocatorDefault, formatDescription: description, decoderSpecification: nil, imageBufferAttributes: imageBufferAttributes, outputCallback: &outputCallbackRecord, decompressionSessionOut: &session)
        
        guard status == noErr else {
            
            Print.error(NSError(domain: NSOSStatusErrorDomain, code: Int(status)).localizedDescription)
            return status
        }
        
        guard let session = session else {
            
            Print.error("session nil")
            return -1
        }
        
        /// 解码线程数
        VTSessionSetProperty(session, key: kVTDecompressionPropertyKey_ThreadCount, value: NSNumber(value: threadCount))
        
        /// 是否实时编码
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_RealTime, value: isRealTime ? kCFBooleanTrue : kCFBooleanFalse)
        
        self.type = type
        self.vps = vps
        self.sps = sps
        self.pps = pps
        
        Print.debug("\n")
        Print.debug("type:                      \(type)")
        Print.debug("width                      \(dimensions.width)")
        Print.debug("height                     \(dimensions.height)")
        Print.debug("\n")
        
        return status
    }
    
    /**
     添加编码数据
     
     - parameter    bytes:                      编码数据
     - parameter    presentationTimeStamp:      帧序
     - parameter    duration:                   帧时间
     */
    @discardableResult
    open func add(_ bytes: [UInt8], presentationTimeStamp: CMTime? = nil, duration: CMTime? = nil) -> CVPixelBuffer? {
        
        guard let session = session else {
            
            Print.error("session nil")
            return nil
        }
        
        var buffer = [0, 0, 0, 0] + bytes
        
        let x = UInt32(bytes.count)
        
        buffer[0] = UInt8((x << 0 ) >> 24)
        buffer[1] = UInt8((x << 8 ) >> 24)
        buffer[2] = UInt8((x << 16 ) >> 24)
        buffer[3] = UInt8((x << 24 ) >> 24)
        
        var pixelBuffer: CVPixelBuffer? = nil
        
        var blockBuffer: CMBlockBuffer? = nil
        
        var status = CMBlockBufferCreateWithMemoryBlock(allocator: kCFAllocatorDefault, memoryBlock: &buffer, blockLength: buffer.count, blockAllocator: kCFAllocatorNull, customBlockSource: nil, offsetToData: 0, dataLength: buffer.count, flags: CMBlockBufferFlags(truncating: false), blockBufferOut: &blockBuffer)
        
        guard status == noErr else {
            
            Print.error(NSError(domain: NSOSStatusErrorDomain, code: Int(status)).localizedDescription)
            return nil
        }
        
        var sampleBuffer: CMSampleBuffer? = nil
        
        var sampleTimingArray: [CMSampleTimingInfo] = []
        
        sampleTimingArray.append(CMSampleTimingInfo(duration: duration ?? .invalid, presentationTimeStamp: presentationTimeStamp ?? .invalid, decodeTimeStamp: .invalid))
        
        status = CMSampleBufferCreateReady(allocator: kCFAllocatorDefault, dataBuffer: blockBuffer, formatDescription: description, sampleCount: 1, sampleTimingEntryCount: sampleTimingArray.count, sampleTimingArray: sampleTimingArray, sampleSizeEntryCount: 1, sampleSizeArray: [buffer.count], sampleBufferOut: &sampleBuffer)
        
        guard status == noErr else {
            
            Print.error(NSError(domain: NSOSStatusErrorDomain, code: Int(status)).localizedDescription)
            return nil
        }
        
        guard let sampleBuffer = sampleBuffer else {
            
            Print.error("sampleBuffer nil")
            return nil
        }
        
        let flags = VTDecodeFrameFlags.init(rawValue: 0)
        var outFlags = VTDecodeInfoFlags.init(rawValue: 0)
        
        status = VTDecompressionSessionDecodeFrame(session, sampleBuffer: sampleBuffer, flags: flags, frameRefcon: &pixelBuffer, infoFlagsOut: &outFlags)
        
        guard status == noErr else {
            
            Print.error(NSError(domain: NSOSStatusErrorDomain, code: Int(status)).localizedDescription)
            return nil
        }
        
        return pixelBuffer
    }
    
    /**
     关闭
     */
    open func close() {
        
        if session != nil {
            
            VTDecompressionSessionInvalidate(session!)
        }
        
        session = nil
        description = nil
    }
}
