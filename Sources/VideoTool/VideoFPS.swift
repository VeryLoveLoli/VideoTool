//
//  VideoFPS.swift
//  
//
//  Created by 韦烽传 on 2022/8/20.
//

import Foundation
import LinkedList

/**
 视频帧数
 */
open class VideoFPS: LinkedListOneWay<TimeInterval> {
    
    /**
     添加计数
     
     - returns  瞬时帧数
     */
    open func addCount() -> Int {
        
        let currentTime = Date().timeIntervalSince1970
        
        var fps = 0
        
        if let start = tail?.value {
            
            fps = Int(1/(currentTime - start))
        }
        
        addTailNode(value: currentTime)
        
        while currentTime - (head?.value ?? currentTime) > 1 {
            
            _ = removeHeadNode()
        }
        
        return fps
    }
    
    /**
     秒帧数
     
     - returns 当前秒帧数
     */
    open func second() -> Int {
        
        if let start = head?.value, let end = tail?.value, count > 1 {
            
            return Int(TimeInterval(count-1)/(end - start))
        }
        
        return 0
    }
}
