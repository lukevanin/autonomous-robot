//
//  Map.swift
//  ARSelfDrivingRobot
//
//  Created by Luke Van In on 2021/04/06.
//

import ARKit
import CoreGraphics
import Combine


///
/// An occupancy grid structure representing the obstacles that are detected in the physical world. Used to
/// estimate the regions of the world that the robot can navigate.
///
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
        guard let targetCost = getCost(at: target) else {
            return nil
        }
        guard targetCost < 1.0 else {
            return nil
        }
        let minCost = minimumMovementCost
        var moveCost = minCost + (targetCost * (1.0 - minCost))
        moveCost = min(moveCost, 1.0)
        moveCost = max(moveCost, minCost)
        let a = simd_float2(Float(source.x), Float(source.y))
        let b = simd_float2(Float(target.x), Float(target.y))
        let distance = simd_length(b - a)
        let cost = moveCost * distance
        return cost
    }
    
    func heuristic(source: MapCoordinate, target: MapCoordinate) -> Float {
        let a = simd_float2(Float(source.x), Float(source.y))
        let b = simd_float2(Float(target.x), Float(target.y))
        return simd_length(b - a) * minimumMovementCost
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
            if (x0 == x1 && y0 == y1) {
                break
            }
            let c = MapCoordinate(x: x0, y: y0)
            if let p = getCost(at: c) {
                if p >= obstacleCostThreshold {
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
