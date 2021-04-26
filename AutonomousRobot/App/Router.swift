//
//  Planner.swift
//  ARSelfDrivingRobot
//
//  Created by Luke Van In on 2021/04/07.
//

import Foundation
import simd
import Combine


///
/// Computes the path from the robot's position to the given goal. Provides updates whenever the robot's
/// position or orientation changes, or when the map or goal changes.
///
final class Router: ObservableObject {
        
    struct Constraint {
        var agent: Agent
        var goal: WorldCoordinate
        var map: Map
    }
    
    let route = CurrentValueSubject<Route?, Never>(nil)
    
    private var cancellables = Set<AnyCancellable>()
    
    private let queue = DispatchQueue(
        label: "router",
        qos: .utility,
        attributes: [],
        autoreleaseFrequency: .inherit,
        target: .global(qos: .utility)
    )
    
    init(
        agent: AnyPublisher<Agent, Never>,
        map: AnyPublisher<Map, Never>,
        goal: AnyPublisher<WorldCoordinate?, Never>
    ) {
        Publishers
            .CombineLatest3(agent, map, goal)
            .throttle(for: .seconds(routeUpdateInterval), scheduler: queue, latest: true)
            .map { (agent, map, goal) -> Route? in
                guard let goal = goal else {
                    return nil
                }
                let pathfinder = WorldPathFinder(
                    map: map
                )
                let waypoints = pathfinder.findWaypoints(
                    source: agent.position,
                    target: goal
                )
                return Route(
                    agent: agent,
                    goal: goal,
                    map: map,
                    waypoints: waypoints
                )
            }
            .sink { [weak self] route in
                guard let self = self else {
                    return
                }
                self.route.send(route)
            }
            .store(in: &cancellables)
    }
}
