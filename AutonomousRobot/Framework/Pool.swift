//
//  Pool.swift
//  ARSelfDrivingRobot
//
//  Created by Luke Van In on 2021/04/14.
//

import Foundation


final class PoolObject<T> where T: AnyObject {
    
    private(set) var subject: T
    private weak var pool: Pool<T>?
    
    fileprivate init(subject: T, pool: Pool<T>) {
        self.subject = subject
        self.pool = pool
    }
    
    deinit {
        precondition(isKnownUniquelyReferenced(&subject), "Value is not uniquely referenced (value has more than one current owner)")
        pool?.release(subject)
    }
}


final class Pool<T> where T: AnyObject {
    
    typealias Make = () -> T
    typealias Recycle = (T) -> Void
    
    private let queue = DispatchQueue(
        label: "pool",
        qos: .utility,
        attributes: [],
        autoreleaseFrequency: .inherit,
        target: .global(qos: .utility)
    )
    
    private var buffers: [T]
    private let make: Make
    private let recycle: Recycle
    
    init(count: Int = 1, make: @escaping Make, recycle: @escaping Recycle) {
        self.make = make
        self.recycle = recycle
        self.buffers = (0 ..< count).map { _ in
            make()
        }
    }
    
    func allocate() -> PoolObject<T> {
        let subject = allocateUnsafe()
        return PoolObject(subject: subject, pool: self)
    }
    
    func allocateUnsafe() -> T {
        queue.sync {
            if buffers.count > 0 {
                return buffers.removeLast()
            }
            else {
                return make()
            }
        }
    }

    func release(_ t: T) {
        queue.async { [weak self] in
            guard let self = self else {
                return
            }
            self.recycle(t)
            self.buffers.append(t)
        }
    }
}
