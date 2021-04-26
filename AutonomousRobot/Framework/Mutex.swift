//
//  Mutex.swift
//  ARSelfDrivingRobot
//
//  Created by Luke Van In on 2021/04/15.
//

import Foundation


///
/// Mutex implemented using `pthread_mutex_lock` and `pthread_mutex_unlock`. Used for
/// obtaining an exclusive lock on a shared resource used by multiple threads.
///
public class PThreadMutex {
    var mutex: pthread_mutex_t = pthread_mutex_t()
   
    public init() { /* ... */ }
   
    public func sync<R>(execute: () throws -> R) rethrows -> R {
        pthread_mutex_lock(&mutex)
        defer { pthread_mutex_unlock(&mutex) }
        return try execute()
    }
}
