//
//  AStar.swift
//  ARSelfDrivingRobot
//
//  Created by Luke Van In on 2021/04/07.
//

import Foundation
import simd


struct Heap<Element> {
    
    struct Entry {
        let value: Element
        let cost: Float
    }
    
    var isEmpty: Bool {
        return queue.isEmpty
    }
    
    private var queue = [Entry]()

    mutating func insert(_ value: Element, cost: Float) {
        self.insert(Entry(value: value, cost: cost))
    }

    mutating func insert(_ entry: Entry) {
        queue.append(entry)
        queue.sort { $0.cost < $1.cost }
    }
    
    mutating func get() -> Element? {
        guard queue.isEmpty == false else {
            return nil
        }
        return queue.removeFirst().value
    }
}


final class MapPathFinder {
    
    private let map: Map
    
    init(map: Map) {
        self.map = map
    }
    
    func findPath(source: MapCoordinate, target: MapCoordinate) -> [MapCoordinate] {
        guard source != target else {
            // Source is at the target. Return empty path.
            return []
        }
        var frontier = Heap<MapCoordinate>()
        var cameFrom = [MapCoordinate : MapCoordinate]()
        var costSoFar = [MapCoordinate : Float]()
        frontier.insert(source, cost: 0)
        costSoFar[source] = 0
        
        while let current = frontier.get() {
            guard current != target else {
                // We reached the target.
                break
            }
            let currentCost = costSoFar[current]!
            let neighbors = map.neighbors(at: current)
            for next in neighbors {
                guard let nextCost = map.getCost(source: current, target: next) else {
                    // Node is undefined or not traversible.
                    continue
                }
                let newCost = currentCost + nextCost
                let oldCost = costSoFar[next] ?? .greatestFiniteMagnitude
                if newCost < oldCost {
                    costSoFar[next] = newCost
                    let cost = newCost + map.heuristic(source: next, target: target)
                    frontier.insert(next, cost: cost)
                    cameFrom[next] = current
                }
            }
        }
        
        var path = [MapCoordinate]()
        var current = target
        while current != source, let next = cameFrom[current] {
            path.append(current)
            current = next
        }
//        path.append(source)
        path.reverse()
        return path
    }
}


final class WorldPathFinder {
    
    private let map: Map
    
    init(map: Map) {
        self.map = map
    }
    
    ///
    /// Finds a path in the current map given a source and target coordinates in world coordinate space.
    /// Returns the set of waypoints to traverse the path.
    ///
    func findWaypoints(source: WorldCoordinate, target: WorldCoordinate) -> [WorldCoordinate] {
        let mapSource = map.space.toMap(source)
        let mapTarget = map.space.toMap(target)
        let mapPathFinder = MapPathFinder(map: map)
        let roughPath = mapPathFinder.findPath(source: mapSource, target: mapTarget)
        guard roughPath.count > 0 else {
            return []
        }
        let smoothedPath = smoothPath(source: mapSource, path: roughPath)
        let waypoints = smoothedPath.map { map.space.toWorld($0) }
        guard waypoints.count > 1 else {
            return [source, target]
        }
        return [source] + waypoints.dropLast() + [target]
    }
    
    ///
    /// Find the last point that can be travelled to without any collisions. Returns the point and all the points
    /// after it. We are only concerned that there is some route to the target, and care less about the exact
    /// points along the route. We only need to know the next waypoint that needs to be reached.
    ///
    private func smoothPath(source: MapCoordinate, path points: [MapCoordinate]) -> [MapCoordinate] {
        guard points.count > 1 else {
            return points
        }
        var next = 0
        for i in 2 ..< points.count {
            let target = points[i]
            if map.intersection(source: source, target: target) == nil {
                next = i
            }
        }
        let output = Array(points.suffix(from: next))
        return output
    }

    ///
    /// Convert the points in map coordinates, to a list of waypoints in physical world coordinates.
    /// Waypoints are placed only at corners where the path changes direction.
    ///
    private func makeWaypoints(path points: [MapCoordinate]) -> [WorldCoordinate] {
        var waypoints = [WorldCoordinate]()

        var w0 = points[0]
        waypoints.append(map.space.toWorld(w0))
        
        var currentDirection: Int?
        for i in 1 ..< points.count {
            let p0 = points[i - 1]
            let p1 = points[i]
            let delta = MapCoordinate(x: p1.x - p0.x, y: p1.y - p0.y)
            let newDirection = MapCoordinate.directions.firstIndex(of: delta)!
            if let oldDirection = currentDirection {
                if newDirection != oldDirection {
                    waypoints.append(map.space.toWorld(p0))
                    w0 = p1
                    currentDirection = newDirection
                }
            }
            else {
                currentDirection = newDirection
            }
        }
        waypoints.append(map.space.toWorld(points[points.count - 1]))
        return waypoints
    }
}
