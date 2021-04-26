//
//  Navigator.swift
//  ARSelfDrivingRobot
//
//  Created by Luke Van In on 2021/04/10.
//

import Foundation
import Combine
import simd


///
/// Computes the trajectory from the robot's current location to the next waypoint along the path. The
/// trajectory is the straight-line direction and distance that the robot should move. Produces a nil trajectory if
/// there is no route, or if the robot is within sufficient distance of the last waypoint.
///
/// Waypoints are provided by the path finding algorithm which calculates the route through the environment.
///
/// The trajectory is used by the robot controller to determine steering and speed commands which actually
/// move the robot.
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
            .receive(on: queue)
            .map { agent, waypoints -> Trajectory? in
                // Check if the robot has reached the last waypoint. The first
                // waypoint is always the robot's current position. The next
                // waypoint starts at index 1.
                guard waypoints.count > 1 else {
                    return nil
                }
                
                // Iterate through all of the waypoints. Ignore waypoints that
                // are too close (ie the robot might already at a waypoint so we
                // don't need to drive towards it).
                for i in 1 ..< waypoints.count {
                    let waypoint = waypoints[i]
                
                    // Calculate the relative straight-line distance from the
                    // robot to the waypoint to check if the robot is already
                    // "at" the waypoint.
                    let delta = waypoint - agent.position
                    let distance = delta.length()
                    
                    if distance < waypointDistanceThreshold {
                        // We have reached this waypoint.
                        continue
                    }
                    
                    // Calculate total remaining distance along the path to the
                    // goal. If we are close enough to the final goal then we
                    // don't need to compute a trajectory.
                    var remainingDistance = Float(0)
                    for j in i ..< waypoints.count {
                        let w0 = waypoints[j - 1]
                        let w1 = waypoints[j]
                        let distance = (w1 - w0).length()
                        remainingDistance += distance
                    }
                    guard remainingDistance > pathDistanceThreshold else {
                        // We are "at" the goal.
                        break
                    }
                    
                    // Calculate the relative angle between the agent's heading,
                    // and the waypoint so that we know how much more we need to
                    // turn to face towards the waypoint.
                    let agentVector = simd_float2(
                        cos(agent.heading),
                        sin(agent.heading)
                    )
                    let heading = agentVector.angle(
                        to: simd_float2(delta.x, delta.y)
                    )
                    return Trajectory(
                        heading: Measurement(value: Double(heading), unit: .radians),
                        distance: Measurement(value: Double(distance), unit: .meters)
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
