//
//  Mapper.swift
//  ARSelfDrivingRobot
//
//  Created by Luke Van In on 2021/04/08.
//

import ARKit
import Combine


private let mapResolution = Float(0.050) // resolution in meters (size of smallest unit in the map)
private let mapScale = Float(1) / mapResolution
//private let roofThreshold = Float(2.000)
//private let floorThreshold = Float(0.250)
//private let floorThreshold = Float(1.000)


//private class MapFactory {
//
//    private var mapBuilder: MapBuilder!
//
//}


final class Mapper {

    let image = CurrentValueSubject<CGImage?, Never>(nil)
    let map = CurrentValueSubject<Map?, Never>(nil)

    private let queue = DispatchQueue(
        label: "map",
        qos: .utility,
        attributes: [],
        autoreleaseFrequency: .inherit,
        target: .global(qos: .utility)
    )

//    private let factory = MapFactory()
    
    private var mapDimensions = MapCoordinate(x: 0, y: 0)
    private var mapBuilder: MapBuilder!
    private var busy = false
    private var pending: (Agent, Fields)?
    
    private var cancellables = Set<AnyCancellable>()
        
    init(
        agent: AnyPublisher<Agent?, Never>,
        fields: AnyPublisher<[UUID : Field], Never>
    ) {
        Publishers
            .CombineLatest(agent, fields)
//            .debounce(for: 0.1, scheduler: queue)
//            .throttle(for: 0.0, scheduler: DispatchQueue.main, latest: true)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (agent: Agent?, fields: Fields) -> Void in
                guard let self = self else {
                    return
                }
                guard let agent = agent else {
                    return
                }
                self.pending = (agent, fields)
                self.update()
            }
            .store(in: &cancellables)
    }
    
    private func update() {
        dispatchPrecondition(condition: .onQueue(.main))
        guard let current = pending else {
            return
        }
        guard busy == false else {
            return
        }
        busy = true
        pending = nil
        queue.async { [weak self] in
            guard let self = self else {
                return
            }
            let start = Date()
            self.updateMap(agent: current.0, fields: current.1)
            let elapsed = Date().timeIntervalSince(start)
            print("Map: Time", String(format: "%0.3f", elapsed))
            DispatchQueue.main.asyncAfter(wallDeadline: .now() + 0.1) { [weak self] in
                guard let self = self else {
                    return
                }
                self.busy = false
                self.update()
            }
        }
    }
    
    private func updateMap(agent: Agent, fields: [UUID : Field]) {
        
        #warning("TODO: Transform fields around the agent's (apply inverse of agent's transform)")
        #warning("TODO: Calculate changed fields and only update those portions of the map, reject fields and field components that are outside of the agent's line of sight")
        
        guard fields.count > 0 else {
            return
        }
        
//        let mapAgent = MapBuilder.Agent(
//            location: agent.position,
//            elevation: agent.elevation,
//            radius: agent.radius,
//            orientation: agent.heading
//        )

        // Find extents and origin of the world.
        var hasField = false
        var worldMin = simd_float3(+Float.greatestFiniteMagnitude, +Float.greatestFiniteMagnitude, +Float.greatestFiniteMagnitude)
        var worldMax = simd_float3(-Float.greatestFiniteMagnitude, -Float.greatestFiniteMagnitude, -Float.greatestFiniteMagnitude)

        for field in fields.values {
            guard field.count > 0 else {
                continue
            }
            hasField = true
            let fieldTransform = field.transform
            let b = field.bounds

            let coordinates = [
                simd_float4(b.min.x, b.min.y, b.min.z, 1),
                simd_float4(b.max.x, b.min.y, b.min.z, 1),
                simd_float4(b.min.x, b.min.y, b.max.z, 1),
                simd_float4(b.max.x, b.min.y, b.max.z, 1),
                
                simd_float4(b.min.x, b.max.y, b.min.z, 1),
                simd_float4(b.max.x, b.max.y, b.min.z, 1),
                simd_float4(b.min.x, b.max.y, b.max.z, 1),
                simd_float4(b.max.x, b.max.y, b.max.z, 1),
            ]
            
            let worldCoordinates = coordinates
                .map { fieldTransform * $0 }
                .map { simd_float3($0.x / $0.w, $0.y / $0.w, $0.z / $0.w) }
            for c in worldCoordinates {
                worldMin = simd_min(worldMin, c)
                worldMax = simd_max(worldMax, c)
            }
        }
        
        guard hasField else {
            return
        }
        
        
        var mapCoordinateSpace = MapCoordinateSpace(
            worldOrigin: WorldCoordinate(x: worldMin.x, y: worldMin.z),
            worldOrientation: -agent.heading,
            worldMin: WorldCoordinate(x: worldMin.x, y: worldMin.z),
            worldMax: WorldCoordinate(x: worldMax.x, y: worldMax.z),
            scale: mapScale,
            elevationMin: worldMin.y,
            elevationMax: worldMax.y
        )

        // Calculate map boundaries
        let worldBoundaryCoordinates = [
            WorldCoordinate(x: worldMin.x, y: worldMin.z),
            WorldCoordinate(x: worldMin.x, y: worldMax.z),
            WorldCoordinate(x: worldMax.x, y: worldMin.z),
            WorldCoordinate(x: worldMax.x, y: worldMax.z),
        ]
        let mapBoundaryCoordinates = worldBoundaryCoordinates.map { mapCoordinateSpace.toMap($0) }

        var mapMin = MapCoordinate(x: .max, y: .max)
        var mapMax = MapCoordinate(x: .min, y: .min)
        
        for c in mapBoundaryCoordinates {
            mapMin.x = min(mapMin.x, c.x)
            mapMin.y = min(mapMin.y, c.y)
            mapMax.x = max(mapMax.x, c.x)
            mapMax.y = max(mapMax.y, c.y)
        }
        mapCoordinateSpace.mapOrigin = mapMin

        // Make map (X x Z units in size)
        let snap = Float(100)
        let mapSize = MapCoordinate(
            x: Int(ceil(Float(mapMax.x - mapMin.x) / snap) * snap),
            y: Int(ceil(Float(mapMax.y - mapMin.y) / snap) * snap)
        )
        mapDimensions.x = max(mapDimensions.x, mapSize.x)
        mapDimensions.y = max(mapDimensions.y, mapSize.y)

        if mapBuilder?.dimensions != mapDimensions {
            mapBuilder = MapBuilder(
                dimensions: mapDimensions,
                space: mapCoordinateSpace,
                margin: agent.radius
            )
        }
        else {
            mapBuilder.space = mapCoordinateSpace
            mapBuilder.reset()
        }

        for field in fields.values {
            mapBuilder.addField(field)
        }
        let map = mapBuilder.build(floorLocation: mapCoordinateSpace.toMap(agent.position))
        self.map.send(map)
        
        if let image = mapBuilder.cgImage() {
            self.image.send(image)
        }
    }
}
