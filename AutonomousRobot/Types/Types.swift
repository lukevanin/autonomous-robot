//
//  Types.swift
//  ARSelfDrivingRobot
//
//  Created by Luke Van In on 2021/04/10.
//

import Foundation
import CoreGraphics
import simd


///
/// Represents the physical properties of the robot, including its location, elevation, orientation, and size.
///
struct Agent: Equatable {
    var position: WorldCoordinate
    var elevation: Float
    var heading: Float
    var radius: Float
}


//struct World {
//    var agent: Agent
//    var map: Map
//}


///
/// Final destination location that the robot should attempt to reach.
///
typealias Goal = WorldCoordinate


///
///
///
typealias Waypoint = WorldCoordinate


///
/// Represents a sequence of coordinates that the robot should move along to travel from a start location to
/// a destination location.
///
struct Route {
    var agent: Agent
    var goal: WorldCoordinate
    var map: Map
    var waypoints: [Waypoint]
}


///
/// Represents a relative angle and distance that the robot should move towards.
///
struct Trajectory: Equatable {
    static let zero = Trajectory(
        heading: Measurement(value: 0, unit: UnitAngle.degrees),
        distance: Measurement(value: 0, unit: UnitLength.millimeters)
    )
    var heading: Measurement<UnitAngle>
    var distance: Measurement<UnitLength>
}


///
/// A position on the continuous ground plane in the physical world. Units are in meters.
///
struct WorldCoordinate: Equatable {
    
    static let zero = WorldCoordinate(x: 0, y: 0)
    
    var x: Float
    var y: Float
    
    func length() -> Float {
        simd_precise_length(simd_float2(x, y))
    }
    
    static func +(lhs: WorldCoordinate, rhs: WorldCoordinate) -> WorldCoordinate {
        return WorldCoordinate(simd_float2(lhs.x, lhs.y) + simd_float2(rhs.x, rhs.y))
    }

    static func -(lhs: WorldCoordinate, rhs: WorldCoordinate) -> WorldCoordinate {
        return WorldCoordinate(simd_float2(lhs.x, lhs.y) - simd_float2(rhs.x, rhs.y))
    }
}

extension WorldCoordinate {
    init(_ v: simd_float2) {
        self.x = v.x
        self.y = v.y
    }
    
    init(_ v: simd_float3) {
        self.x = v.x / v.z
        self.y = v.y / v.z
    }
}


extension simd_float2 {
    init(_ v: WorldCoordinate) {
        self.init(v.x, v.y)
    }
}


///
/// Represents a discreet point on the map grid.
///
struct MapCoordinate: Hashable {
    
    static let zero = MapCoordinate(x: 0, y: 0)
    
    static let directions = [
        MapCoordinate(x: +1, y: +0),
        MapCoordinate(x: -1, y: +0),
        MapCoordinate(x: +0, y: +1),
        MapCoordinate(x: +0, y: -1),

        MapCoordinate(x: +1, y: +1),
        MapCoordinate(x: +1, y: -1),
        MapCoordinate(x: -1, y: +1),
        MapCoordinate(x: -1, y: -1),
    ]

    var x: Int
    var y: Int
}


///
/// Defines the transformation used to convert a coordinate given in the physical world to discreet point on the
/// map, and vice-versa.
///
struct MapCoordinateSpace: Equatable {
    let worldOrigin: WorldCoordinate
    let worldOrientation: Float
    let worldMin: WorldCoordinate
    let worldMax: WorldCoordinate
    let scale: Float
    let elevationMin: Float
    let elevationMax: Float
    var mapOrigin: MapCoordinate = MapCoordinate(x: 0, y: 0)
    
    #warning("TODO: Compute the worldToMapTransform and mapToWorldTransform at initialization")
    var worldToMapTransform: simd_float3x3 {
        matrix_identity_float3x3 *
            .translate(x: -Float(mapOrigin.x), y: -Float(mapOrigin.y)) *
            .scale(x: scale, y: scale) *
            .translate(x: -worldMin.x, y: -worldMin.y)
    }
    
    var mapToWorldTransform: simd_float3x3 {
        worldToMapTransform.inverse
    }

    var elevationRange: Float {
        elevationMax - elevationMin
    }
    
    var elevationScale: Float {
        1.0 / elevationRange
    }
    
    var worldSize: WorldCoordinate {
        WorldCoordinate(
            x: worldMax.x - worldMin.x,
            y: worldMax.y - worldMin.y
        )
    }
    
    func toMap(_ coordinate: WorldCoordinate) -> MapCoordinate {
        let c = worldToMapTransform * simd_float3(coordinate.x, coordinate.y, 1)
        precondition(c.z != 0)
        return MapCoordinate(x: Int(round(c.x / c.z)), y: Int(round(c.y / c.z)))
    }
    
    func toMapPoint(_ coordinate: WorldCoordinate) -> CGPoint {
        let c = worldToMapTransform * simd_float3(coordinate.x, coordinate.y, 1)
        precondition(c.z != 0)
        return CGPoint(x: CGFloat(c.x / c.z), y: CGFloat(c.y / c.z))
    }

    func toWorld(_ coordinate: MapCoordinate) -> WorldCoordinate {
        let c = mapToWorldTransform * simd_float3(Float(coordinate.x), Float(coordinate.y), 1)
        precondition(c.z != 0)
        return WorldCoordinate(x: c.x / c.z, y: c.y / c.z)
    }

    func toWorld(_ point: CGPoint) -> WorldCoordinate {
        let c = mapToWorldTransform * simd_float3(Float(point.x), Float(point.y), 1)
        precondition(c.z != 0)
        return WorldCoordinate(x: c.x / c.z, y: c.y / c.z)
    }

    func toMap(_ length: Float) -> Int {
        return Int(round(length * scale))
    }

    func toMapLength(_ length: Float) -> Float {
        return round(length * scale)
    }

    func toWorld(_ length: Int) -> Float {
        return Float(length) / scale
    }
}
