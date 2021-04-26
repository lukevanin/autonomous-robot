//
//  FlexibleBuffer.swift
//  ARSelfDrivingRobot
//
//  Created by Luke Van In on 2021/04/14.
//

import Foundation


final class FlexibleBuffer<T> {

    var capacity: Int {
        data.count
    }
    private(set) var data: UnsafeMutableBufferPointer<T>

    init(capacity: Int) {
        self.data = UnsafeMutableBufferPointer<T>.allocate(capacity: capacity)
    }
    
    deinit {
        data.deallocate()
    }
    
    subscript(index: Int) -> T {
        get {
            return data[index]
        }
        set {
            data[index] = newValue
        }
    }

    func reallocate(capacity: Int) {
        guard capacity != data.count else {
            return
        }
        let old = data
        let new = UnsafeMutableBufferPointer<T>.allocate(capacity: capacity)
        let count = min(old.count, new.count)
        for i in 0 ..< count {
            new[i] = old[i]
        }
        old.deallocate()
        data = new
    }
}
