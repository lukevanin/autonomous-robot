//
//  Navigator.swift
//  ARSelfDrivingRobot
//
//  Created by Luke Van In on 2021/04/10.
//

import Foundation
import Combine
import simd


private let waypointDistanceThreshold = Float(0.250)
private let pathDistanceThreshold = Float(0.500)


///
/// Moves the robot from its current location on a given map towards a given goal. Stops when there is no
/// route to the goal, or when the goal is reached.
///
final class Navigator {
    
    let trajectory = CurrentValueSubject<Trajectory?, Never>(nil)
    
    private var cancellables = Set<AnyCancellable>()
    
    private let queue = DispatchQueue(
        label: "navigator",
        qos: .utility,
        attributes: [],
        autoreleaseFrequency: .inherit,
        target: .global(qos: .utility)
    )

    init(
        agent: AnyPublisher<Agent, Never>,
        waypoints: AnyPublisher<[WorldCoordinate], Never>
    ) {
        Publishers
            .CombineLatest(agent, waypoints)
//            .throttle(for: 1.0, scheduler: queue, latest: true)
            .receive(on: queue)
            .map { agent, waypoints -> Trajectory? in
                guard waypoints.count > 1 else {
                    return nil
                }
                
                for i in 1 ..< waypoints.count {
                    let waypoint = waypoints[i]
                
                    // Calculate the relative offset to the waypoint.
                    let delta = waypoint - agent.position
                    let distance = delta.length()
                    
                    if distance < waypointDistanceThreshold {
                        // We have reached this waypoint.
                        continue
                    }
                    
                    // Calculate total remaining distance along the path to the
                    // goal.
                    var remainingDistance = Float(0)
                    for j in i ..< waypoints.count {
                        let w0 = waypoints[j - 1]
                        let w1 = waypoints[j]
                        let distance = (w1 - w0).length()
                        remainingDistance += distance
                    }
                    guard remainingDistance > pathDistanceThreshold else {
                        // We are close enough to the goal. Stop here.
                        break
                    }
                    
                    // Calculate the relative angle between the agent's heading, and
                    // the waypoint.
                    // See: https://stackoverflow.com/a/21486462
                    let heading: Float = {
                        let a = simd_normalize(
                            simd_float2(
                                cos(agent.heading),
                                sin(agent.heading)
                            )
                        )
                        let b = simd_normalize(
                            simd_float2(
                                delta.x,
                                delta.y
                            )
                        )
                        let cross = simd_orient(a, b)
                        let dot = simd_dot(a, b)
                        let angle = atan2(cross, dot)
                        // print("Angle", String(format: "%0.2f", angle))
                        return Float(angle)
                    }()
                    return Trajectory(
                        heading: Measurement<UnitAngle>(value: Double(heading), unit: .radians),
                        distance: Measurement<UnitLength>(value: Double(distance), unit: .meters)
                    )
                }
                return nil
            }
            .sink { [weak self] value in
                guard let self = self else {
                    return
                }
                self.trajectory.send(value)
            }
            .store(in: &cancellables)
    }
}
