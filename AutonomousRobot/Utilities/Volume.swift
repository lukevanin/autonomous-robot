//
//  Volume.swift
//  ARSelfDrivingRobot
//
//  Created by Luke Van In on 2021/04/14.
//

import Foundation


struct Volume {
    static let undefined = Volume(
        min: SIMD3(
            +.greatestFiniteMagnitude,
            +.greatestFiniteMagnitude,
            +.greatestFiniteMagnitude
        ),
        max: SIMD3(
            -.greatestFiniteMagnitude,
            -.greatestFiniteMagnitude,
            -.greatestFiniteMagnitude
        )
    )

    var mid: SIMD3<Float> {
        min + (span * 0.5)
    }
    
    var span: SIMD3<Float> {
        max - min
    }

    var min: SIMD3<Float>
    var max: SIMD3<Float>
}
