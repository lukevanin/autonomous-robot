//
//  Types.swift
//  ARSelfDrivingRobot
//
//  Created by Luke Van In on 2021/04/10.
//

import Foundation
import simd


struct Agent: Equatable {
    var position: WorldCoordinate
    var elevation: Float
    var heading: Float
    var radius: Float
}


struct World {
    var agent: Agent
    var map: Map
}


typealias Goal = WorldCoordinate


typealias Waypoint = WorldCoordinate


struct Route {
    var agent: Agent
    var goal: WorldCoordinate
    var map: Map
    var waypoints: [Waypoint]
}


struct Trajectory: Equatable {
    static let zero = Trajectory(
        heading: Measurement(value: 0, unit: UnitAngle.degrees),
        distance: Measurement(value: 0, unit: UnitLength.millimeters)
    )
    var heading: Measurement<UnitAngle>
    var distance: Measurement<UnitLength>
}
