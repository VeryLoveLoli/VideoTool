//
//  VideoFileEncode.swift
//  
//
//  Created by 韦烽传 on 2022/8/20.
//

import Foundation
import VideoToolbox

import Print
import Extension

/**
 视频文件编码
 */
open class VideoFileEncode: VideoEncodeProtocol {
    
    /// 队列
    var queue: DispatchQueue
    
    /// 视频编码
    var videoEncode: VideoEncode?
    
    /// 编码类型（仅支持 `kCMVideoCodecType_H264`、`kCMVideoCodecType_HEVC`）
    open internal(set) var type: CMVideoCodecType
    /// 尺寸
    open internal(set) var dimensions: CMVideoDimensions
    /// 预期帧数
    open internal(set) var fps: Int32
    /// 关键帧间隔（单位帧）
    open internal(set) var keyInterval: Int32
    /// 关键帧间隔时间（单位秒）
    open internal(set) var keyDuration: Int
    /// 压缩倍数
    open internal(set) var multiple: Int32
    /// 是否实时编码
    open internal(set) var isRealTime: Bool
    /// 配置级别（默认`H264`：`kVTProfileLevel_H264_High_AutoLevel` `HEVC`：`kVTProfileLevel_HEVC_Main_AutoLevel`）
    open internal(set) var level: CFString?
    /// 是否编码B帧并重新排序
    open internal(set) var isBFrame: Bool?
    /// 图片质量
    open internal(set) var quality: Float
    
    /// 保存路径
    open internal(set) var path = ""
    /// 文件处理
    var fileHandle: FileHandle?
    
    /// 是否已开始
    open internal(set) var isStart = false
    
    /// 最后一个帧序号
    open internal(set) var lastFrameNumber = -1
    
    /// 协议
    open var delegate: VideoFileEncodeProtocol?
    
    /**
     初始化
     
     - parameter    type:           编码类型（仅支持 `kCMVideoCodecType_H264`、`kCMVideoCodecType_HEVC`）
     - parameter    dimensions:     尺寸
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
    public init(_ type: CMVideoCodecType = kCMVideoCodecType_H264,
          dimensions: CMVideoDimensions = .wh1280x720,
          fps: Int32 = 30,
          keyInterval: Int32 = 30,
          keyDuration: Int = 1,
          multiple: Int32 = 300,
          isRealTime: Bool = true,
          level: CFString? = nil,
          isBFrame: Bool? = nil,
          quality: Float = 1.0) {
        
        queue = DispatchQueue(label: "\(Date().timeIntervalSince1970).\(Self.self).serial")
        self.type = type
        self.dimensions = dimensions
        self.fps = fps
        self.keyInterval = keyInterval
        self.keyDuration = keyDuration
        self.multiple = multiple
        self.isRealTime = isRealTime
        self.level = level
        self.isBFrame = isBFrame
        self.quality = quality
    }
    
    /**
     准备编码
     
     - returns  是否成功
     */
    @discardableResult
    open func prepareVideoEncode() -> Bool {
        
        lastFrameNumber = -1
        
        guard let encode = VideoEncode(type, dimensions: dimensions) else {
            
            delegate?.videoFileEncode(self, path: path, error: NSError(domain: "VideoEncode init error", code: -1))
            isStart = false
            
            return false
        }
        
        videoEncode = encode
        videoEncode?.refreshConfiguration(fps, keyInterval: keyInterval, keyDuration: keyDuration, multiple: multiple, isRealTime: isRealTime, level: level, isBFrame: isBFrame, quality: quality)
        videoEncode?.delegate = self
        
        return true
    }
    
    /**
     准备文件处理
     
     - returns  是否成功
     */
    @discardableResult
    open func prepareFileHandle() -> Bool {
        
        if !path.createDirectoryFromFilePath() {
            
            delegate?.videoFileEncode(self, path: path, error: NSError(domain: "create path \(path) error", code: -1))
            isStart = false
            
            return false
        }
        
        var bool = true
        
        do {
            
            if FileManager.default.fileExists(atPath: path) {
                
                try FileManager.default.removeItem(atPath: path)
            }
            
            FileManager.default.createFile(atPath: path, contents: Data(), attributes: nil)
            
            fileHandle = try FileHandle(forWritingTo: URL(fileURLWithPath: path))
            
        } catch {
            
            Print.error(error.localizedDescription)
            
            delegate?.videoFileEncode(self, path: path, error: error)
            isStart = false
            
            bool = false
        }
        
        return bool
    }
    
    /**
     写类型
     
     - parameter    type:       类型
     */
    func writeType(_ type: UInt32) {
        
        writeBytes(type.bytes())
    }
    
    /**
     写字节
     
     - parameter    bytes:      字节
     */
    func writeBytes(_ bytes: [UInt8]) {
        
        delegate?.videoFileEncode(self, bytes: bytes)
        
        let data = Data(bytes: bytes, count: bytes.count)
        
        fileHandle?.write(data)
    }
    
    /**
     写PS数据
     
     - parameter    vps:        VPS数据（HEVC）
     - parameter    sps:        SPS数据
     - parameter    pps:        PPS数据
     */
    func writePS(_ vps: [UInt8]?, sps: [UInt8], pps: [UInt8]) {
        
        var bytes: [UInt8] = []
        
        /// VPS
        if let vps = vps {
            
            bytes.append(DataType.vps)
            bytes += UInt32(vps.count).bytes()
            bytes += vps
        }
        
        /// SPS
        bytes.append(DataType.sps)
        bytes += UInt32(sps.count).bytes()
        bytes += sps
        
        /// PPS
        bytes.append(DataType.pps)
        bytes += UInt32(pps.count).bytes()
        bytes += pps
        
        writeBytes(bytes)
    }
    
    /**
     写帧数据
     
     - parameter    bytes:                      帧数据
     - parameter    isKey:                      是否关键帧
     - parameter    presentationTimeStamp:      帧序
     - parameter    duration:                   帧时间
     */
    func writeFrame(_ bytes: [UInt8], isKey: Bool, presentationTimeStamp: CMTime, duration: CMTime) {
        
        var value: [UInt8] = []
        
        /// 数据类型标识
        value.append(isKey ? DataType.keyframe : DataType.frame)
        
        /// 帧序
        value += UInt64(presentationTimeStamp.value).bytes()
        
        /// 帧时间
        value += UInt64(duration.value).bytes()
        
        /// 帧数据
        value += UInt32(bytes.count).bytes()
        value += bytes
        
        writeBytes(value)
    }
    
    /**
     开始
     
     - parameter    path:   保存文件路径
     */
    open func start(_ path: String) {
        
        if isStart { return }
        
        isStart = true
        
        self.path = path
        
        queue.async {
            
            guard self.prepareVideoEncode() else { return }
            guard self.prepareFileHandle() else { return }
            self.writeType(self.type == kCMVideoCodecType_H264 ? DataType.h264 : DataType.h265)
        }
    }
    
    /**
     添加帧缓冲
     
     - parameter    sampleBuffer:   帧缓冲
     - parameter    duration:       时间
     */
    open func add(_ sampleBuffer: CMSampleBuffer, duration: CMTime? = nil) {
        
        if !isStart { return }
        
        queue.async {
            
            self.videoEncode?.add(sampleBuffer, duration: duration)
        }
    }
    
    /**
     停止
     */
    open func stop() {
        
        if !isStart { return }
        
        isStart = false
        
        queue.async {
            
            self.videoEncode?.close()
            self.videoEncode?.delegate = nil
            self.videoEncode = nil
            self.fileHandle?.closeFile()
            self.fileHandle = nil
            self.delegate?.videoFileEncode(self, path: self.path, error: nil)
        }
    }
    
    // MARK: - VideoEncodeProtocol
    
    public func videoEncode(_ encode: VideoEncode, vps: [UInt8]?, sps: [UInt8], pps: [UInt8], bytes: [UInt8], isKey: Bool, presentationTimeStamp: CMTime, duration: CMTime) {
        
        if isKey {
            
            writePS(vps, sps: sps, pps: pps)
        }
        
        writeFrame(bytes, isKey: isKey, presentationTimeStamp: presentationTimeStamp, duration: duration)
        
        lastFrameNumber = Int(presentationTimeStamp.value)
    }
}

public extension VideoFileEncode {
    
    /**
     数据类型标识
     */
    class DataType {
        
        /// H264文件标识
        public static let h264: UInt32 = 264
        /// H265文件标识
        public static let h265: UInt32 = 265
        
        /// VPS数据标识
        public static let vps: UInt8 = 1 << 0
        /// SPS数据标识
        public static let sps: UInt8 = 1 << 1
        /// PPS数据标识
        public static let pps: UInt8 = 1 << 2
        
        /// 关键帧数据标识
        public static let keyframe: UInt8 = 1 << 3
        /// 帧数据标识
        public static let frame: UInt8 = 1 << 4
    }
}
