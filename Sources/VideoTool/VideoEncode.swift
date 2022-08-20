//
//  VideoEncode.swift
//  
//
//  Created by 韦烽传 on 2022/8/20.
//

import Foundation
import VideoToolbox

import Print

/**
 视频编码器
 */
open class VideoEncode {
    
    /// 会话
    open internal(set) var session: VTCompressionSession?
    /// 编码类型（仅支持 `kCMVideoCodecType_H264`、`kCMVideoCodecType_HEVC`）
    open internal(set) var type: CMVideoCodecType
    /// 尺寸
    open internal(set) var dimensions: CMVideoDimensions
    
    /// 帧序号
    open internal(set) var frameNumber = 0
    
    /// 协议
    open var delegate: VideoEncodeProtocol?
    
    /// 预期帧数
    open internal(set) var fps: Int32?
    /// 关键帧间隔（单位帧）
    open internal(set) var keyInterval: Int32?
    /// 关键帧间隔时间（单位秒）
    open internal(set) var keyDuration: Int?
    /// 压缩倍数
    open internal(set) var multiple: Int32?
    /// 码率
    open internal(set) var bitRate: Int?
    /// 是否实时编码
    open internal(set) var isRealTime: Bool?
    /// 配置级别（默认`H264`：`kVTProfileLevel_H264_High_AutoLevel` `HEVC`：`kVTProfileLevel_HEVC_Main_AutoLevel`）
    open internal(set) var level: CFString?
    /// 是否编码B帧并重新排序
    open internal(set) var isBFrame: Bool?
    /// 图片质量
    open internal(set) var quality: Float?
    
    /**
     初始化
     
     - parameter    type:           编码类型（仅支持 `kCMVideoCodecType_H264`、`kCMVideoCodecType_HEVC`）
     - parameter    dimensions:     尺寸
     */
    public init?(_ type: CMVideoCodecType = kCMVideoCodecType_H264,
         dimensions: CMVideoDimensions = .wh1280x720) {
        
        switch type {
        case kCMVideoCodecType_H264:
            break
        case kCMVideoCodecType_HEVC:
            break
        default:
            Print.error("不支持 \(type)")
            return nil
        }
        
        self.type = type
        self.dimensions = dimensions
        
        /// 输出回调
        let outputCallback: @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, OSStatus, VTEncodeInfoFlags, CMSampleBuffer?) -> Void = { (outputCallbackRefCon, sourceFrameRefCon, status, infoFlags, sampleBuffer) -> Void in
            
            guard let outputRaw = UnsafeRawPointer.init(outputCallbackRefCon) else {
                
                Print.error("outputCallbackRefCon nil")
                return
            }
            
            let encode: VideoEncode = Unmanaged<VideoEncode>.fromOpaque(outputRaw).takeUnretainedValue()
            
            guard status == noErr else {
                
                Print.error(NSError(domain: NSOSStatusErrorDomain, code: Int(status)))
                return
            }
            
            guard let sampleBuffer = sampleBuffer else {
                
                Print.error("sampleBuffer nil")
                return
            }
            
            guard CMSampleBufferIsValid(sampleBuffer) else {
                
                Print.error("CMSampleBufferIsValid false")
                return
            }
            
            guard CMSampleBufferDataIsReady(sampleBuffer) else {
                
                Print.error("CMSampleBufferDataIsReady false")
                return
            }
            
            guard infoFlags == .asynchronous else {
                
                Print.error("infoFlags != .asynchronous")
                return
            }
            
            guard let array = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: true) else {
                
                Print.error("CMSampleBufferGetSampleAttachmentsArray nil")
                return
            }
            
            guard let raw = CFArrayGetValueAtIndex(array, 0) else {
                
                Print.error("CFArrayGetValueAtIndex nil")
                return
            }
            
            let dict: CFDictionary = Unmanaged<CFDictionary>.fromOpaque(raw).takeUnretainedValue()
            
            let key = kCMSampleAttachmentKey_NotSync
            
            /// 是否关键帧
            let isKeyFrame = !CFDictionaryContainsKey(dict, Unmanaged.passUnretained(key).toOpaque())
            
            guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else {
                
                Print.error("CMSampleBufferGetDataBuffer nil")
                return
            }
                        
            let presentationTimeStamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            let duration = CMSampleBufferGetDuration(sampleBuffer)
            
            encode.callBackFrameBytes(CMSampleBufferGetFormatDescription(sampleBuffer), blockBuffer: blockBuffer, isKey: isKeyFrame, presentationTimeStamp: presentationTimeStamp, duration: duration)
        }
        
        let status = VTCompressionSessionCreate(allocator: kCFAllocatorDefault, width: dimensions.width, height: dimensions.height, codecType: type, encoderSpecification: nil, imageBufferAttributes: nil, compressedDataAllocator: nil, outputCallback: outputCallback, refcon: Unmanaged.passUnretained(self).toOpaque(), compressionSessionOut: &session)
        
        guard status == noErr else {
            
            Print.error(NSError(domain: NSOSStatusErrorDomain, code: Int(status)))
            return nil
        }
        
        guard session != nil else {
            
            Print.error("session nil")
            return nil
        }
    }
    
    /**
     PS数据
     
     - parameter    description:    格式描述
     - parameter    index:          `kCMVideoCodecType_H264:`0::SPS;1:PPS `kCMVideoCodecType_HEVC:`0:VPS;1:SPS;2:PPS
     */
    func psBytes(_ description: CMFormatDescription, index: Int) -> [UInt8]? {
        
        var parameterSetPointerOut: UnsafePointer<UInt8>? = nil
        var parameterSetSizeOut: Int = 0
        var parameterSetCountOut: Int = 0
        
        var status = noErr
        
        switch type {
        case kCMVideoCodecType_H264:
            status = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(description, parameterSetIndex: index, parameterSetPointerOut: &parameterSetPointerOut, parameterSetSizeOut: &parameterSetSizeOut, parameterSetCountOut: &parameterSetCountOut, nalUnitHeaderLengthOut: nil)
        case kCMVideoCodecType_HEVC:
            status = CMVideoFormatDescriptionGetHEVCParameterSetAtIndex(description, parameterSetIndex: index, parameterSetPointerOut: &parameterSetPointerOut, parameterSetSizeOut: &parameterSetSizeOut, parameterSetCountOut: &parameterSetCountOut, nalUnitHeaderLengthOut: nil)
        default:
            Print.error("不支持 \(type)")
            return nil
        }
        
        guard status == noErr else {
            
            Print.error(NSError(domain: NSOSStatusErrorDomain, code: Int(status)).localizedDescription)
            return nil
        }
        
        guard let out = parameterSetPointerOut else {
            
            Print.error("parameterSetPointerOut nil")
            return nil
        }
        
        return [UInt8](Data(bytes: out, count: parameterSetSizeOut))
    }
    
    /**
     VPS数据
     
     - parameter    description:    格式描述
     */
    func vpsBytes(_ description: CMFormatDescription) -> [UInt8]? {
        
        guard type == kCMVideoCodecType_HEVC else {
            
            return nil
        }
        
        return psBytes(description, index: 0)
    }
    
    /**
     SPS数据
     
     - parameter    description:    格式描述
     */
    func spsBytes(_ description: CMFormatDescription) -> [UInt8]? {
        
        return psBytes(description, index: type == kCMVideoCodecType_HEVC ? 1 : 0)
    }
    
    /**
     PPS数据
     
     - parameter    description:    格式描述
     */
    func ppsBytes(_ description: CMFormatDescription) -> [UInt8]? {
        
        return psBytes(description, index: type == kCMVideoCodecType_HEVC ? 2 : 1)
    }
    
    /**
     回调帧数据
     
     - parameter    description:                格式描述
     - parameter    blockBuffer:                数据缓冲
     - parameter    isKey:                      是否关键帧
     - parameter    presentationTimeStamp:      帧序
     - parameter    duration:                   帧时间
     */
    func callBackFrameBytes(_ description: CMFormatDescription?, blockBuffer: CMBlockBuffer, isKey: Bool, presentationTimeStamp: CMTime, duration: CMTime) {
        
        var lengthAtOffsetOut: Int = 0
        var totalLengthOut: Int = 0
        var dataPointerOut: UnsafeMutablePointer<Int8>? = nil
        
        let status = CMBlockBufferGetDataPointer(blockBuffer, atOffset: 0, lengthAtOffsetOut: &lengthAtOffsetOut, totalLengthOut: &totalLengthOut, dataPointerOut: &dataPointerOut)
        
        guard status == noErr else {
            
            Print.error(NSError(domain: NSOSStatusErrorDomain, code: Int(status)).localizedDescription)
            return
        }
        
        var vps: [UInt8]? = nil
        var sps: [UInt8] = []
        var pps: [UInt8] = []
        
        if let description = description {
            
            vps = vpsBytes(description)
            sps = spsBytes(description) ?? []
            pps = ppsBytes(description) ?? []
        }
        
        var bufferOffset = 0
        let headerLength = 4
        
        var bytes: [UInt8] = []
        
        while bufferOffset < totalLengthOut - headerLength {
            
            var naluLength: UInt32 = 0
            
            memcpy(&naluLength, dataPointerOut! + bufferOffset, headerLength)
            
            naluLength = CFSwapInt32BigToHost(naluLength)
            
            guard let out = dataPointerOut else {
                
                Print.error("dataPointerOut nil")
                return
            }
            
            let data = Data.init(bytes: out + (bufferOffset + headerLength), count: Int(naluLength))
            
            /// 只取最长一个（当是关键帧时有可能两个，小的[0~300左右]无法转化成图像）
            if bytes.count < data.count {
                
                bytes = [UInt8](data);
            }
            
            bufferOffset += headerLength + Int(naluLength)
        }
        
        delegate?.videoEncode(self, vps: vps, sps: sps, pps: pps, bytes: bytes, isKey: isKey, presentationTimeStamp: presentationTimeStamp, duration: duration)
    }
    
    /**
     刷新配置
     
     - parameter    fps:            预期帧数
     - parameter    keyInterval:    最大关键帧间隔（单位帧，与`keyDuration`先到达的返回关键帧）
     - parameter    keyDuration:    最大关键帧间隔时间（单位秒）
     - parameter    multiple:       压缩倍数（高画质一般为帧数的5倍，中画质一般为帧数10倍，低画质一般为帧数30倍）
     - parameter    isRealTime:     是否实时编码
     - parameter    level:          配置级别（默认`H264`：`kVTProfileLevel_H264_High_AutoLevel` `HEVC`：`kVTProfileLevel_HEVC_Main_AutoLevel`）
     - parameter    isBFrame:       是否编码B帧并重新排序
     - parameter    quality:        图片质量（`HEVC`：码率无效，=1.0 无压缩非常大，<1.0 非常小而且模糊回调帧数降低）

     `码率=width*height*4*fps*8/multiple`
     */
    open func refreshConfiguration(_ fps: Int32 = 30,
                              keyInterval: Int32 = 30,
                              keyDuration: Int = 1,
                              multiple: Int32 = 300,
                              isRealTime: Bool = true,
                              level: CFString? = nil,
                              isBFrame: Bool? = nil,
                              quality: Float = 1.0) {
        
        guard let session = session else {
            
            Print.error("session nil")
            return
        }
        
        let bitRate = Int(dimensions.width)*Int(dimensions.height)*4*Int(fps)*8/Int(multiple)
        
        Print.debug("\n")
        Print.debug("fps:                       \(fps)")
        Print.debug("keyInterval:               \(keyInterval)")
        Print.debug("keyDuration:               \(keyDuration)")
        Print.debug("multiple:                  \(multiple)")
        Print.debug("bitRate:                   \(bitRate/1024)Kbps")
        Print.debug("dataRateLimits:            \(bitRate/1024/8)Kb/s")
        Print.debug("isRealTime:                \(isRealTime)")
        Print.debug("quality:                   \(quality)")
        
        self.fps = fps
        self.keyInterval = keyInterval
        self.keyDuration = keyDuration
        self.multiple = multiple
        self.bitRate = bitRate
        self.isRealTime = isRealTime
        self.level = level
        self.isBFrame = isBFrame
        self.quality = quality
        
        /// 是否实时编码
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_RealTime, value: isRealTime ? kCFBooleanTrue : kCFBooleanFalse)
        
        if self.level == nil {
            
            switch type {
            case kCMVideoCodecType_H264:
                self.level = kVTProfileLevel_H264_High_AutoLevel
            case kCMVideoCodecType_HEVC:
                self.level = kVTProfileLevel_HEVC_Main_AutoLevel
            default:
                break
            }
        }
        
        /// 配置文件（`Main`系列需关闭B帧）
        if let level = self.level {
            
            VTSessionSetProperty(session, key: kVTCompressionPropertyKey_ProfileLevel, value: level)
            Print.debug("level:                     \(level)")
        }
        
        if self.isBFrame == nil {
            
            switch type {
            case kCMVideoCodecType_H264:
                self.isBFrame = true
            case kCMVideoCodecType_HEVC:
                self.isBFrame = false
            default:
                break
            }
        }
        
        /// 是否编码B帧并重排帧序（配置`Main_xxLevel`需关闭，不然视频卡顿，注意帧数是正确的，但视频就是卡）
        if let isBFrame = self.isBFrame {
            
            VTSessionSetProperty(session, key: kVTCompressionPropertyKey_AllowFrameReordering, value: isBFrame ? kCFBooleanTrue : kCFBooleanFalse)
            Print.debug("isBFrame:                  \(isBFrame)")
        }
        
        Print.debug("\n")
        
        /// 设置关键帧（GOPsize)间隔
        var frameInterval = Int(keyInterval)
        let frameNumber = CFNumberCreate(kCFAllocatorDefault, CFNumberType.intType, &frameInterval)
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_MaxKeyFrameInterval, value: frameNumber)
        
        /// 设置期望帧率
        var fps = fps
        let fpsNumber = CFNumberCreate(kCFAllocatorDefault, CFNumberType.sInt32Type, &fps)
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_ExpectedFrameRate, value: fpsNumber)
        
        /// 设置码率，均值
        var averageBitRate = Int32(bitRate)
        let bitNumber = CFNumberCreate(kCFAllocatorDefault, CFNumberType.sInt32Type, &averageBitRate)
        VTSessionSetProperty(self.session!, key: kVTCompressionPropertyKey_AverageBitRate, value: bitNumber)
        
        /// 设置码率，上限
        let bytes = bitRate/8
        let seconds: Int = 1
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_DataRateLimits, value: NSArray(array: [NSNumber(value: bytes), NSNumber(value: seconds)]))
        
        /// 质量（H265：码率无效，=1.0 无压缩非常大，<1.0 非常小而且模糊回调帧数降低）
        var quality: Float = quality
        let qualityNumber = CFNumberCreate(kCFAllocatorDefault, CFNumberType.floatType, &quality)
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_Quality, value: qualityNumber)
        
        var dictionary: CFDictionary?
        VTSessionCopySupportedPropertyDictionary(session, supportedPropertyDictionaryOut: &dictionary)
        
        if let dictionary = dictionary {
            
            Print.debug("\n")
            Print.debug("VTSessionCopySupportedPropertyDictionary:")
            Print.debug(dictionary)
            Print.debug("\n")
        }
        
        /*
        /// 透明通道质量
        if #available(iOS 13.0, *) {
            VTSessionSetProperty(self.session!, key: kVTCompressionPropertyKey_TargetQualityForAlpha, value: NSNumber(value: 1.0))
        } else {
            // Fallback on earlier versions
        }
        
        /// 是否压缩非关键帧
        VTSessionSetProperty(self.session!, key: kVTCompressionPropertyKey_AllowTemporalCompression, value: kCFBooleanTrue)
        
        /// 是否启用OpenGOP
        VTSessionSetProperty(self.session!, key: kVTCompressionPropertyKey_AllowOpenGOP, value: kCFBooleanTrue)
        
        /// 是否连续压缩帧
        VTSessionSetProperty(self.session!, key: kVTCompressionPropertyKey_MoreFramesBeforeStart, value: kCFBooleanTrue)
        VTSessionSetProperty(self.session!, key: kVTCompressionPropertyKey_MoreFramesAfterEnd, value: kCFBooleanTrue)
        
        /// 是否降低质量保证最大化速度（`true`: 降低质量来最大化其速度；`false`: 优先级应该是最大化质量（在给定的比特率下））
        if #available(iOS 14.0, *) {
            VTSessionSetProperty(self.session!, key: kVTCompressionPropertyKey_PrioritizeEncodingSpeedOverQuality, value: kCFBooleanFalse)
        } else {
            // Fallback on earlier versions
        }
        
        /// 基础层占比
        if #available(iOS 14.5, *) {
            VTSessionSetProperty(self.session!, key: kVTCompressionPropertyKey_BaseLayerFrameRateFraction, value: NSNumber(value: 1.0))
        } else {
            // Fallback on earlier versions
        }
        if #available(iOS 15.0, *) {
            VTSessionSetProperty(self.session!, key: kVTCompressionPropertyKey_BaseLayerBitRateFraction, value: NSNumber(value: 1.0))
        } else {
            // Fallback on earlier versions
        }
        
        /// 最大帧量化参数（1～51，用来调节图片质量和码率，越低图片质量越高图片大小越大，当大于码率时会丢帧）
        if #available(iOS 15.0, *) {
            VTSessionSetProperty(self.session!, key: kVTCompressionPropertyKey_MaxAllowedFrameQP, value: NSNumber(value: 1))
        } else {
            // Fallback on earlier versions
        }
         */
    }
    
    /**
     启动
     */
    @discardableResult
    open func start() -> OSStatus {
        
        var status: OSStatus = -1
        
        guard let session = session else {
            
            Print.error("session nil")
            return status
        }
        
        /// 开始编码
        status = VTCompressionSessionPrepareToEncodeFrames(session)
        
        guard status == noErr else {
            
            Print.error(NSError(domain: NSOSStatusErrorDomain, code: Int(status)).localizedDescription)
            
            return status
        }
        
        return status
    }
    
    /**
     添加帧缓冲
     
     - parameter    sampleBuffer:   帧缓冲
     - parameter    duration:       时间
     
     SE3 1920X1080 30FPS: 帧数据远大于设定值，大多数情况都是1.5～2倍，前摄像头帧数据完全不会降到20Kb/帧（码率810Kb/s）设定码率没效果；
     SE3 其余分辨率帧数据也会出现超过设定码率，分辨率越大越容易出现；
     SE3 建议使用 1280X720或以下，码率效果很好，大多数情况帧数据都会小于设定码率
     */
    @discardableResult
    open func add(_ sampleBuffer: CMSampleBuffer, duration: CMTime? = nil) -> OSStatus {
        
        guard let session = session else {
            
            Print.error("session nil")
            return -1
        }
        
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            
            Print.error("CMSampleBufferGetImageBuffer nil")
            return -1
        }
        
        let presentationTimeStamp = CMTimeMake(value: Int64(frameNumber), timescale: 1000)
        let duration = duration ?? CMSampleBufferGetDuration(sampleBuffer)
        var infoFlags = VTEncodeInfoFlags.init(rawValue: 0)
        
        let status = VTCompressionSessionEncodeFrame(session, imageBuffer: imageBuffer, presentationTimeStamp: presentationTimeStamp, duration: duration, frameProperties: nil, sourceFrameRefcon: nil, infoFlagsOut: &infoFlags)
        
        guard status == noErr else {
            
            Print.error(NSError(domain: NSOSStatusErrorDomain, code: Int(status)).localizedDescription)
            return status
        }
        
        frameNumber += 1
        
        return status
    }
    
    /**
     关闭
     */
    open func close() {
        
        if session != nil {
            
            VTCompressionSessionCompleteFrames(session!, untilPresentationTimeStamp: CMTime.invalid)
            VTCompressionSessionInvalidate(session!)
        }
        
        session = nil
        frameNumber = 0
    }
}
