//
//  VideoCapture.swift
//  
//
//  Created by 韦烽传 on 2022/8/20.
//

import Foundation
import AVFoundation

import Print

/**
 视频捕获
 */
open class VideoCapture: NSObject {
    
    // MARK: - 属性
    
    /// 默认视频捕获
    public static let `default` = VideoCapture()
    
    /// 会话，他是 input 和 output 之间的桥梁，它协调着 input 和 output 之间的数据传输
    public let session = AVCaptureSession()
    /// 设备，前后摄像头
    open internal(set) var device: AVCaptureDevice?
    /// 输出（视频数据）
    public let output: AVCaptureVideoDataOutput = AVCaptureVideoDataOutput()
    
    /// 预览图层
    open lazy var previewLayer = AVCaptureVideoPreviewLayer(session: session)
    
    /// 摄像头位置
    open var position: AVCaptureDevice.Position {
        
        didSet {
            
            switchFrontBackCamera(position)
        }
    }
    
    /// 视频方向
    open var orientation: AVCaptureVideoOrientation {
        
        didSet {
            
            if let videoConnection = output.connection(with: .video) {
                
                if videoConnection.isVideoOrientationSupported {
                    
                    videoConnection.videoOrientation = orientation
                }
            }
        }
    }
    
    /// 尺寸
    open internal(set) var dimensions: CMVideoDimensions
    /// 格式
    open internal(set) var format: AVCaptureDevice.Format?
    /// 帧率范围
    open internal(set) var frameRateRange: AVFrameRateRange?
    /// 帧数
    open internal(set) var fps: Float64
    
    // MARK: - init
    
    /**
     初始化
     
     - parameter    preset:             会话预设
     - parameter    position:           摄像头位置
     - parameter    videoSettings:      视频输出设置
     - parameter    orientation:        视频输出方向
     - parameter    dimensions:         视频尺寸
     - parameter    fps:                帧数
     
     */
    public init(_ preset: AVCaptureSession.Preset = .inputPriority,
                position: AVCaptureDevice.Position = .front,
                videoSettings: [String : Any] = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange],
                orientation: AVCaptureVideoOrientation = .portrait,
                dimensions: CMVideoDimensions = .wh1280x720,
                fps: Float64 = 30) {
        
        session.sessionPreset = preset
        
        self.position = position
        
        /// 视频输出设置
        output.videoSettings = videoSettings
        
        session.beginConfiguration()
        session.addOutput(output)
        session.commitConfiguration()
        
        self.orientation = orientation
        
        self.dimensions = dimensions
        
        self.fps = fps
        
        super.init()
        
        /**
         `init`设置属性值不会调用到`didSet`
         */
        
        switchFrontBackCamera(position)
        
        if let videoConnection = output.connection(with: .video) {
            
            if videoConnection.isVideoStabilizationSupported {
                
                /// 防抖模式
                videoConnection.preferredVideoStabilizationMode = .auto
            }
            
            if videoConnection.isVideoOrientationSupported {
                
                /// 视频方向
                videoConnection.videoOrientation = orientation
            }
        }
        
        previewLayer.connection?.videoOrientation = orientation
        
        if let format = format(dimensions), let maxFrameRateRange = maxFrameRateRange(format) {
            
            updateActiveFormat(format, frameRateRange: maxFrameRateRange, fps: fps)
        }
    }
    
    // MARK: - 事件
    
    /**
     相机
     
     - parameter    position:   位置
     */
    open func camera(_ position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        
        var deviceTypes : [AVCaptureDevice.DeviceType] = [.builtInWideAngleCamera,
                                                          .builtInTelephotoCamera,
                                                          .builtInDualCamera,
                                                          .builtInTrueDepthCamera]
        
        if #available(iOS 13, *) {
            
            deviceTypes.append(.builtInUltraWideCamera)
            deviceTypes.append(.builtInDualWideCamera)
            deviceTypes.append(.builtInTripleCamera)
        }
        
        if #available(iOS 15.4, *) {
            
            deviceTypes.append(.builtInLiDARDepthCamera)
        }
        
        let discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: deviceTypes, mediaType: .video, position: position)
        
        for item in discoverySession.devices {
            
            if item.position == position {
                
                return item
            }
        }
        
        return nil
    }
    
    /**
     切换前后摄像头
     切换后重置 `session.sessionPreset` 为`configuration`中设置的值
     
     - parameter    position:       摄像头位置
     */
    open func switchFrontBackCamera(_ position: AVCaptureDevice.Position) {
        
        if device?.position == position {
            
            return
        }
        
        device = camera(position)
        
        Print.debug(position)
        
        guard let device = device else { return }
        
        do {
            
            let input = try AVCaptureDeviceInput(device: device)
            
            session.beginConfiguration()
            
            for item in session.inputs {
                
                if let deviceInput = item as? AVCaptureDeviceInput, deviceInput.device.hasMediaType(.video) {
                    
                    session.removeInput(deviceInput)
                }
            }
            
            session.addInput(input)
            
            session.commitConfiguration()
            
            if let format = format(dimensions) ?? format(.wh1280x720), let frameRateRange = maxFrameRateRange(format) {
                
                updateActiveFormat(format, frameRateRange: frameRateRange, fps: fps)
            }
            
        } catch {
            
            Print.error(error.localizedDescription)
        }
    }
    
    /**
     更新活跃分辨率和帧数（与`session.sessionPreset`互斥）
     
     可通过`videoDevice?.formats`获取格式列表
     可通过`format.videoSupportedFrameRateRanges`获取格式支持的帧数列表
     可通过`format.formatDescription.dimensions`获取格式的分辨率大小
     
     已提供`func format(_ dimensions: CMVideoDimensions) -> AVCaptureDevice.Format?`获取指定格式
     已提供`func maxFrameRateRange(_ format: AVCaptureDevice.Format) -> AVFrameRateRange?`获取格式最大帧数
     
     - parameter    format:                 格式
     - parameter    frameRateRange:         帧数区间
     - parameter    fps:                    帧数
     */
    open func updateActiveFormat(_ format: AVCaptureDevice.Format,
                                 frameRateRange: AVFrameRateRange,
                                 fps: Float64) {
        
        guard let device = device else { return }
        
        session.beginConfiguration()
        
        do {
            
            try device.lockForConfiguration()
            
            device.activeFormat = format
            
            if fps >= frameRateRange.maxFrameRate {
                
                device.activeVideoMinFrameDuration = frameRateRange.minFrameDuration
                device.activeVideoMaxFrameDuration = frameRateRange.minFrameDuration
                self.fps = frameRateRange.maxFrameRate
            }
            else {
                
                device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: CMTimeScale(fps))
                device.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: CMTimeScale(fps))
                self.fps = fps
            }
            
            device.unlockForConfiguration()
            
            self.format = format
            self.frameRateRange = frameRateRange
            
            if #available(iOS 13.0, *) {
                
                dimensions = format.formatDescription.dimensions
                
            } else {
                
                dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
            }
            
        } catch {
            
            Print.error(error.localizedDescription)
        }
        
        session.commitConfiguration()
        
        Print.debug("\n")
        Print.debug("width                      \(dimensions.width)")
        Print.debug("height                     \(dimensions.height)")
        Print.debug("fps                        \(self.fps)")
        Print.debug("\n")
    }
    
    /**
     视频格式
     
     - parameter    dimensions:     视频尺寸
     */
    open func format(_ dimensions: CMVideoDimensions) -> AVCaptureDevice.Format? {
        
        if dimensions == .max {
            
            return maxFormat()
        }
        
        for format in device?.formats ?? [] {
            
            var deviceDimensions: CMVideoDimensions
            
            if #available(iOS 13.0, *) {
                
                deviceDimensions = format.formatDescription.dimensions
                
            } else {
                
                deviceDimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
            }
            
            if deviceDimensions.width == dimensions.width && deviceDimensions.height == dimensions.height {
                
                return format
            }
        }
        
        return nil
    }
    
    /**
     最大视频格式
     
     - parameter    dimensions:     视频尺寸
     */
    open func maxFormat() -> AVCaptureDevice.Format? {
        
        var dimensions: CMVideoDimensions?
        var value: AVCaptureDevice.Format?
        
        for format in device?.formats ?? [] {
            
            var deviceDimensions: CMVideoDimensions
            
            if #available(iOS 13.0, *) {
                
                deviceDimensions = format.formatDescription.dimensions
                
            } else {
                
                deviceDimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
            }
            
            if dimensions == nil {
                
                dimensions = deviceDimensions
                value = format
            }
            else {
                
                if deviceDimensions.width * deviceDimensions.height > dimensions!.width * dimensions!.height {
                    
                    value = format
                }
                else if deviceDimensions.width * deviceDimensions.height == dimensions!.width * dimensions!.height && deviceDimensions.width > dimensions!.width {
                    
                    value = format
                }
            }
        }
        
        return value
    }
    
    /**
     最大帧率范围
     
     - parameter    format:     视频格式
     */
    open func maxFrameRateRange(_ format: AVCaptureDevice.Format) -> AVFrameRateRange? {
        
        var frameRateRange = format.videoSupportedFrameRateRanges.first
        
        for item in format.videoSupportedFrameRateRanges {
            
            if (frameRateRange?.maxFrameRate ?? 0) < item.maxFrameRate {
                
                frameRateRange = item
            }
        }
        
        return frameRateRange
    }
}
