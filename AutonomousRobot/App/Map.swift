//
//  Map.swift
//  ARSelfDrivingRobot
//
//  Created by Luke Van In on 2021/04/06.
//

import ARKit
import CoreGraphics
import Combine


let elevationDistanceThreshold = Float(0.100)


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


struct MapCoordinateSpace: Equatable {
    let worldOrigin: WorldCoordinate
    let worldOrientation: Float
    let worldMin: WorldCoordinate
    let worldMax: WorldCoordinate
    let scale: Float
    let elevationMin: Float
    let elevationMax: Float
    var mapOrigin: MapCoordinate = MapCoordinate(x: 0, y: 0)
    
    var worldToMapTransform: simd_float3x3 {
        matrix_identity_float3x3 *
            .translate(x: -Float(mapOrigin.x), y: -Float(mapOrigin.y)) *
            .scale(x: scale, y: scale) *
//            .rotate(angle: worldOrientation) *
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


//final class MapImageRenderer {
    
//    let pool: CMMemoryPool
//
//    init() {
//        let options = [
//            kCMMemoryPoolOption_AgeOutPeriod: 5.0 as CFNumber
//        ]
//        self.pool = CMMemoryPoolCreate(
//            options: options as CFDictionary
//        )
//    }
    
//    deinit {
//        CMMemoryPoolInvalidate(pool)
//    }
    
//    func render(map: Map) -> CGImage? {
//        let bytesPerComponent = MemoryLayout<Float>.size
//        let bytesPerRow = map.dimensions.x * bytesPerComponent
//        let dataProvider = CGDataProvider(data: map.data.data)!
//        let bitmapInfo: CGBitmapInfo = [.byteOrder32Little, .floatComponents]
//        let image = CGImage(
//            width: map.dimensions.x,
//            height: map.dimensions.y,
//            bitsPerComponent: bytesPerComponent * 8,
//            bitsPerPixel: bytesPerComponent * 8,
//            bytesPerRow: bytesPerRow,
//            space: CGColorSpaceCreateDeviceGray(),
//            bitmapInfo: bitmapInfo,
//            provider: dataProvider,
//            decode: nil,
//            shouldInterpolate: false,
//            intent: .defaultIntent
//        )
//        return image

//        let bytes = map.dimensions.x * map.dimensions.y
//        let buffer = pool.allocate(count: bytes)
//        for i in 0 ..< map.data.count {
//            var d = map.data[i]
//            d = max(d, 0)
//            d = min(d, 1)
//            let c = UInt8(round(d * 255))
//            buffer[i] = c
//        }
//        let dataProvider = CGDataProvider(data: buffer.data)!
//        let alphaInfo: CGImageAlphaInfo = .none
//        let image = CGImage(
//            width: map.dimensions.x,
//            height: map.dimensions.y,
//            bitsPerComponent: 8,
//            bitsPerPixel: 8,
//            bytesPerRow: map.dimensions.x,
//            space: CGColorSpaceCreateDeviceGray(),
//            bitmapInfo: CGBitmapInfo(rawValue: alphaInfo.rawValue),
//            provider: dataProvider,
//            decode: nil,
//            shouldInterpolate: false,
//            intent: .defaultIntent
//        )
//        return image
//    }
//}


struct Map {
    
    #warning("TODO: Compose a sparse map out of uniform sub-tiles")
    
    let dimensions: MapCoordinate
    let space: MapCoordinateSpace
    let data: Buffer<Float>
    
    func getCost(at coordinate: MapCoordinate) -> Float? {
        guard let i = index(at: coordinate) else {
            return nil
        }
        let effort = 1.0 - data[i]
        let cost = pow(effort, 2)
        return cost
    }
    
    func getCost(source: MapCoordinate, target: MapCoordinate) -> Float? {
//        guard let sourceCost = getCost(at: source) else {
//            return nil
//        }
        guard let targetCost = getCost(at: target) else {
            return nil
        }
//        guard sourceCost < 1.0 else {
//            return nil
//        }
        guard targetCost < 1.0 else {
            return nil
        }
        let minCost = Float(0.050)
//        let costDelta = (targetCost - sourceCost)
        var moveCost = minCost + (targetCost * (1.0 - minCost))
        moveCost = min(moveCost, 1.0)
        moveCost = max(moveCost, minCost)
        // Calculate the change in elevation from the source to the target.
        // Reject the path if the change in elevation is too large.
//        let elevationChange = abs(targetCost - sourceCost)
//        let elevationDistance = elevationChange * space.elevationRange
//        guard elevationDistance <= elevationDistanceThreshold else {
//            return nil
//        }
        let a = simd_float2(Float(source.x), Float(source.y))
        let b = simd_float2(Float(target.x), Float(target.y))
        let distance = simd_length(b - a)
        let cost = moveCost * distance
        return cost
//        return distance
    }
    
    func heuristic(source: MapCoordinate, target: MapCoordinate) -> Float {
        let a = simd_float2(Float(source.x), Float(source.y))
        let b = simd_float2(Float(target.x), Float(target.y))
        return simd_length(b - a) * 0.050
    }
    
    ///
    /// See: https://en.wikipedia.org/wiki/Bresenham%27s_line_algorithm
    ///
    func intersection(source: MapCoordinate, target:MapCoordinate) -> (MapCoordinate, Float)? {
        var x0 = source.x
        var y0 = source.y
        let x1 = target.x
        let y1 = target.y
        let dx =  abs(x1 - x0);
        let sx = x0 < x1 ? 1 : -1;
        let dy = -abs(y1 - y0);
        let sy = y0 < y1 ? 1 : -1;
        var err = dx + dy;  /* error value e_xy */
        while (true) {   /* loop */
//            plot(x0, y0);
            if (x0 == x1 && y0 == y1) {
                break
            }
            let c = MapCoordinate(x: x0, y: y0)
            if let p = getCost(at: c) {
                if p >= 0.040 {
                    // Obstacle between the two points
                    return (c, p)
                }
            }

            let e2 = 2 * err
            if (e2 >= dy) { /* e_xy+e_x > 0 */
                err += dy
                x0 += sx
            }
            if (e2 <= dx) { /* e_xy+e_y < 0 */
                err += dx
                y0 += sy
            }
        }
        
        // No collision between points
        return nil
    }

    
    func neighbors(at coordinate: MapCoordinate) -> [MapCoordinate] {
        return MapCoordinate
            .directions
            .map { direction in
                MapCoordinate(
                    x: coordinate.x + direction.x,
                    y: coordinate.y + direction.y
                )
            }
    }
    
    private func index(at coordinate: MapCoordinate) -> Int? {
        guard contains(coordinate: coordinate) else {
            return nil
        }
        return (coordinate.y * dimensions.x) + coordinate.x
    }

    func contains(coordinate: MapCoordinate) -> Bool {
        return coordinate.x >= 0 &&
            coordinate.x < dimensions.x &&
            coordinate.y >= 0 &&
            coordinate.y < dimensions.y
    }
}

extension Map {
    func cgImage() -> CGImage? {
        let bytesPerComponent = MemoryLayout<Float>.size
        let bytesPerRow = dimensions.x * bytesPerComponent
        let dataProvider = CGDataProvider(data: data.data)!
        let bitmapInfo: CGBitmapInfo = [.byteOrder32Little, .floatComponents]
        let image = CGImage(
            width: dimensions.x,
            height: dimensions.y,
            bitsPerComponent: bytesPerComponent * 8,
            bitsPerPixel: bytesPerComponent * 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: bitmapInfo,
            provider: dataProvider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
        return image
    }
}

//extension Map {
//    func interpolate(_ map: Map, _ t: Float) -> Map {
//        precondition(map.dimensions == dimensions)
//        let s = 1.0 - t
//        let data = zip(self.data, map.data).map { (a: Float?, b: Float?) -> Float? in
//            guard let a = a else {
//                return nil
//            }
//            guard let b = b else {
//                return nil
//            }
//            return (a * s) + (b * t)
//        }
//        return Map(
//            dimensions: dimensions,
//            space: map.space,
//            data: data
//        )
//    }
//}
