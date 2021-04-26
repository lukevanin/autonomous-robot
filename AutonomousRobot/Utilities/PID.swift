//
//  PID.swift
//  AutonomousRobot
//
//  Created by Luke Van In on 2021/04/25.
//

import Foundation


struct PID {
    let kp: Float
    let ki: Float
    
    private(set) var controlVariable: Float = 0
    
    private var lastUpdateTime: Date?
    private var lastError: Float = 0
    private var errorIntegral: Float = 0
    
    init(kp: Float, ki: Float) {
        self.kp = kp
        self.ki = ki
    }
    
    mutating func reset() {
//        setPoint = 0
//        controlVariable = 0
//        processVariable = 0
        lastUpdateTime = nil
        lastError = 0
        errorIntegral = 0
    }
    
    mutating func update(error et: Float) {
        let now = Date()
        guard let lastUpdateTime = self.lastUpdateTime else {
            self.lastUpdateTime = now
            return
        }
//        let et = setPoint - processVariable
        let dt = Float(now.timeIntervalSince(lastUpdateTime))
//        let de = et - lastError
        
        let p = kp * et
        let i = ki * errorIntegral
//        let d = kp * (de / dt)
        let ut = p + i // + d
        
        self.errorIntegral += (et * dt)
        self.lastError = et
//        self.setPoint = setPoint
//        self.controlVariable = ut
//        self.processVariable += ut
        self.lastUpdateTime = now
        self.controlVariable = ut
    }
}
