//
//  VideoFileDecode.swift
//  
//
//  Created by 韦烽传 on 2022/8/20.
//

import Foundation
import VideoToolbox

import Print

/**
 视频文件解码
 */
open class VideoFileDecode: VideoDecodeProtocol {
    
    // MARK: - 属性
    
    /// 队列
    open var queue: DispatchQueue
    
    /// 视频解码
    let videoDecode = VideoDecode()
    
    /// 编码类型（仅支持 `kCMVideoCodecType_H264`、`kCMVideoCodecType_HEVC`）
    open internal(set) var type: CMVideoCodecType?
    /// 尺寸
    open var dimensions: CMVideoDimensions? { videoDecode.dimensions }
    
    /// 文件路径
    open internal(set) var filePath: String?
    /// 文件管理
    var fileHandle: FileHandle?
    /// 文件长度
    open internal(set) var fileLength: UInt64 = 0
    /// 帧列表
    var frameItems: [VideoFileDecode.FrameItem] = []
    /// 时长（毫秒）
    open internal(set) var duration: UInt64 = 0
    /// 第一帧时间戳
    open var firstFrameTimestamp: UInt64? { frameItems.first?.timestamp }
    
    /// 是否开始
    open internal(set) var isStart = false
    
    /// 上次帧时间
    var lastFrameTimeInterval: TimeInterval = 0
    /// 上次显示时间
    var lastDisplayTimeInterval: TimeInterval = 0
    /// 是否显示
    var isDisplay = true
    
    /// 协议
    open var delegate: VideoFileDecodeProtocol?
    
    // MARK: - 初始化
    
    /**
     初始化
     */
    public init() {
        
        queue = DispatchQueue(label: "\(Date().timeIntervalSince1970).\(Self.self).serial")
        
        videoDecode.delegate = self
    }
    
    // MARK: - 事件
    
    /**
     准备
     
     - parameter    path:   文件路径
     
     - returns  是否成功
     */
    @discardableResult
    open func prepare(_ path: String) -> Bool {
        
        do {
            
            let fileHandle = try FileHandle(forReadingFrom: URL(fileURLWithPath: path))
            
            let count = fileHandle.seekToEndOfFile()
            
            fileHandle.seek(toFileOffset: 0)
            let dataType = fileHandle.readData(ofLength: 4).bytes().uint32()
            
            var fileType = kCMVideoCodecType_H264
            
            switch dataType {
            case VideoFileEncode.DataType.h264:
                fileType = kCMVideoCodecType_H264
            case VideoFileEncode.DataType.h265:
                fileType = kCMVideoCodecType_HEVC
            default:
                Print.error("未知类型文件")
                return false
            }
            
            var items: [VideoFileDecode.FrameItem] = []
            
            while count > fileHandle.offsetInFile {
                
                let item = VideoFileDecode.FrameItem()
                item.offset = fileHandle.offsetInFile
                
                let dataType = fileHandle.readData(ofLength: 1).bytes().first!
                
                switch dataType {
                case VideoFileEncode.DataType.vps:
                    if fileType == kCMVideoCodecType_HEVC {
                        items.append(item)
                    }
                    let length = fileHandle.readData(ofLength: 4).bytes().uint32()
                    fileHandle.seek(toFileOffset: fileHandle.offsetInFile + UInt64(length))
                case VideoFileEncode.DataType.sps:
                    if fileType == kCMVideoCodecType_H264 {
                        items.append(item)
                    }
                    let length = fileHandle.readData(ofLength: 4).bytes().uint32()
                    fileHandle.seek(toFileOffset: fileHandle.offsetInFile + UInt64(length))
                case VideoFileEncode.DataType.pps:
                    let length = fileHandle.readData(ofLength: 4).bytes().uint32()
                    fileHandle.seek(toFileOffset: fileHandle.offsetInFile + UInt64(length))
                case VideoFileEncode.DataType.keyframe:
                    fileHandle.seek(toFileOffset: fileHandle.offsetInFile + 8)
                    let duration = fileHandle.readData(ofLength: 8).bytes().uint64()
                    let length = fileHandle.readData(ofLength: 4).bytes().uint32()
                    fileHandle.seek(toFileOffset: fileHandle.offsetInFile + UInt64(length))
                    items.last?.timestamp = duration
                    items.last?.isKeyframe = true
                case VideoFileEncode.DataType.frame:
                    fileHandle.seek(toFileOffset: fileHandle.offsetInFile + 8)
                    let duration = fileHandle.readData(ofLength: 8).bytes().uint64()
                    let length = fileHandle.readData(ofLength: 4).bytes().uint32()
                    fileHandle.seek(toFileOffset: fileHandle.offsetInFile + UInt64(length))
                    item.timestamp = duration
                    item.isKeyframe = false
                    items.append(item)
                default:
                    Print.error("文件数据格式错误")
                    return false
                }
            }
            
            fileHandle.seek(toFileOffset: 4)
            
            self.fileHandle = fileHandle
            fileLength = count
            filePath = path
            type = fileType
            frameItems = items
            if frameItems.count >= 2 {
                duration = frameItems[frameItems.count-1].timestamp - frameItems[0].timestamp
            }
            else {
                duration = 0
            }
            
        } catch {
            
            Print.error(error.localizedDescription)
            return false
        }
        
        return true
    }
    
    /**
     开始
     */
    @discardableResult
    open func start() -> Bool {
        
        if isStart {  return true }
        
        isStart = true
        
        guard let fileHandle = fileHandle else { return false }
        
        guard let type = type else { return false }
        
        queue.async {
            
            self.lastFrameTimeInterval = 0
            self.read(fileHandle, type: type)
        }
        
        return true
    }
    
    /**
     暂停
     */
    open func pause() {
        
        isStart = false
        
        queue.async {
            
            self.lastFrameTimeInterval = 0
        }
    }
    
    /**
     停止
     */
    open func stop() {
        
        isStart = false
        
        queue.async {
            
            self.lastFrameTimeInterval = 0
            self.fileHandle?.seek(toFileOffset: 4)
        }
    }
    
    /**
     寻找时间点开始
     
     - parameter    point:      时间点（毫秒）
     */
    @discardableResult
    open func seek(_ point: UInt64) -> Bool {
        
        if point > duration {
            
            return false
        }
        
        guard let first = frameItems.first else { return false }
        
        var currentItem = first
        var keyItem = first
        
        for item in frameItems {
            
            if point >= (item.timestamp - first.timestamp) {
                
                if item.isKeyframe {
                    
                    keyItem = item
                }
                
                currentItem = item
            }
            else {
                
                break
            }
        }
        
        if isStart {
            
            isStart = false
            
            queue.async {
                
                self.lastFrameTimeInterval = 0
                self.isStart = true
                if let fileHandle = self.fileHandle, let type = self.type {
                    self.read(fileHandle, type: type, seekFrame: currentItem, keyFrame: keyItem)
                }
                else {
                    self.isStart = false
                }
            }
        }
        else {
                        
            if let fileHandle = fileHandle, let type = type {
                
                isStart = true
                
                queue.async {
                    
                    self.lastFrameTimeInterval = 0
                    self.read(fileHandle, type: type, seekFrame: currentItem, keyFrame: keyItem)
                }
            }
            else {
                
                return false
            }
        }
        
        return true
    }
    
    /**
     读取
     
     - parameter    fileHandle:     文件处理
     - parameter    type:           编码类型
     - parameter    seekOffset:     寻找帧偏移
     - parameter    keyOffset:      关键帧偏移
     */
    func read(_ fileHandle: FileHandle, type: CMVideoCodecType, seekFrame: VideoFileDecode.FrameItem? = nil, keyFrame: VideoFileDecode.FrameItem? = nil) {
        
        var vps: [UInt8]?
        var sps: [UInt8] = []
        var pps: [UInt8] = []
        
        if let keyFrame = keyFrame {
            
            fileHandle.seek(toFileOffset: keyFrame.offset)
            isDisplay = false
        }
        else {
            
            isDisplay = true
        }
        
        while fileLength > fileHandle.offsetInFile {
            
            let dataType = fileHandle.readData(ofLength: 1).bytes().first!
            
            switch dataType {
            case VideoFileEncode.DataType.vps:
                var length = fileHandle.readData(ofLength: 4).bytes().uint32()
                let v = fileHandle.readData(ofLength: Int(length)).bytes()
                fileHandle.readData(ofLength: 1)
                length = fileHandle.readData(ofLength: 4).bytes().uint32()
                let s = fileHandle.readData(ofLength: Int(length)).bytes()
                fileHandle.readData(ofLength: 1)
                length = fileHandle.readData(ofLength: 4).bytes().uint32()
                let p = fileHandle.readData(ofLength: Int(length)).bytes()
                if vps != v || sps != s || pps != p {
                    vps = v
                    sps = s
                    pps = p
                    let status = videoDecode.refreshConfiguration(type, vps: vps, sps: sps, pps: pps, isRealTime: true, threadCount: 1)
                    if status != noErr {
                        delegate?.videoFileDecode(self, status: status)
                    }
                }
            case VideoFileEncode.DataType.sps:
                var length = fileHandle.readData(ofLength: 4).bytes().uint32()
                let s = fileHandle.readData(ofLength: Int(length)).bytes()
                fileHandle.readData(ofLength: 1)
                length = fileHandle.readData(ofLength: 4).bytes().uint32()
                let p = fileHandle.readData(ofLength: Int(length)).bytes()
                if sps != s || pps != p {
                    sps = s
                    pps = p
                    let status = videoDecode.refreshConfiguration(type, vps: vps, sps: sps, pps: pps, isRealTime: true, threadCount: 1)
                    if status != noErr {
                        delegate?.videoFileDecode(self, status: status)
                    }
                }
            case VideoFileEncode.DataType.keyframe:
                fallthrough
            case VideoFileEncode.DataType.frame:
                let presentationTimeStamp = fileHandle.readData(ofLength: 8).bytes().uint64()
                let duration = fileHandle.readData(ofLength: 8).bytes().uint64()
                let length = fileHandle.readData(ofLength: 4).bytes().uint32()
                let bytes = fileHandle.readData(ofLength: Int(length)).bytes()
                if !isDisplay {
                    if let seekFrame = seekFrame, seekFrame.timestamp <= duration {
                        isDisplay = true
                    }
                }
                videoDecode.add(bytes, presentationTimeStamp: CMTime(value: CMTimeValue(presentationTimeStamp), timescale: 1000), duration: CMTime(value: CMTimeValue(duration), timescale: 1000))
            default:
                break
            }
            
            if !isStart && (dataType == VideoFileEncode.DataType.frame || dataType == VideoFileEncode.DataType.keyframe) {
                
                break
            }
        }
        
        if isStart {
            
            isStart = false
            fileHandle.seek(toFileOffset: 4)
        }
        
        lastFrameTimeInterval = 0
    }
    
    // MARK: - VideoDecodeProtocol
    
    public func videoDecode(_ decode: VideoDecode, imageBuffer: CVImageBuffer, presentationTimeStamp: CMTime, duration: CMTime) {
        
        if !isDisplay {
            return
        }
        
        /// 当前时间
        let currentTimeInterval = Date().timeIntervalSince1970
        /// 时间间隔
        let displayDuration = currentTimeInterval - lastDisplayTimeInterval
        
        lastDisplayTimeInterval = currentTimeInterval
        
        /// 帧时间
        let currentDuration = duration.seconds
        /// 帧时间间隔
        let timeInterval = currentDuration - lastFrameTimeInterval
        lastFrameTimeInterval = currentDuration
        
        if lastFrameTimeInterval != timeInterval {
            
            /// 睡眠时间
            let sleepTime = timeInterval - displayDuration
            
            /// 延时显示
            if sleepTime > 0 {
                
                lastDisplayTimeInterval = currentTimeInterval + sleepTime
                Thread.sleep(forTimeInterval: sleepTime)
            }
        }
        
        delegate?.videoFileDecode(self, imageBuffer: imageBuffer, presentationTimeStamp: presentationTimeStamp, duration: duration)
    }
}

public extension VideoFileDecode {
    
    /**
     帧列表项
     */
    class FrameItem {
        
        /// 文件偏移
        open var offset: UInt64 = 0
        /// 图像时间
        open var timestamp: UInt64 = 0
        /// 是否关键帧
        open var isKeyframe: Bool = false
    }
}
