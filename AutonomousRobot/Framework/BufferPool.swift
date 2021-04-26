//
//  BufferPool.swift
//  ARSelfDrivingRobot
//
//  Created by Luke Van In on 2021/04/15.
//

import Foundation
import CoreMedia


final class Buffer<T> {
    
    let count: Int
    let data: CFMutableData
    let pointer: UnsafeMutableBufferPointer<T>
    
    init(count: Int, data: CFMutableData) {
        self.count = count
        self.data = data
        let bytePointer = CFDataGetMutableBytePtr(data)!
        let rawPointer = UnsafeMutableRawPointer(bytePointer)
        let typePointer = rawPointer.bindMemory(to: T.self, capacity: count)
        let bufferPointer = UnsafeMutableBufferPointer(start: typePointer, count: count)
        self.pointer = bufferPointer
    }
    
    subscript(index: Int) -> T {
        get {
            pointer[index]
        }
        set {
            pointer[index] = newValue
        }
    }
}


final class BufferPool<T> {
    
    let pool: CMMemoryPool
    
    init(ageOutPeriod: TimeInterval = 1.0) {
        let options = [
            kCMMemoryPoolOption_AgeOutPeriod: ageOutPeriod as CFNumber
        ]
        self.pool = CMMemoryPoolCreate(
            options: options as CFDictionary
        )
    }
    
    deinit {
        CMMemoryPoolInvalidate(pool)
    }
    
    func allocate(count: Int) -> Buffer<T> {
        let bytes = MemoryLayout<T>.stride * count
        let allocator = CMMemoryPoolGetAllocator(pool)
        let data = CFDataCreateMutable(allocator, bytes)!
        CFDataIncreaseLength(data, bytes)
        return Buffer(count: count, data: data)
    }
}
