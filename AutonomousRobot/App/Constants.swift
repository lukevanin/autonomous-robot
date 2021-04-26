//
//  Constants.swift
//  AutonomousRobot
//
//  Created by Luke Van In on 2021/04/26.
//

import Foundation
import Combine

import SwiftMindstorms

/// Distance of the image sensor from the bottom of the wheels
/// (meters).
let agentCameraElevation = Float(0.350)

/// Distance of the image sensor from center of thr axis of the robot
/// (meters).
let agentCameraOffset = Float(0.100)

/// Size of the maximum dimension of the robot from the robot's center of mass
/// (meters).
let agentRadius = Float(0.150)

/// Indicates whether the camera flash should be enabled.
let torchEnabled = false

/// Resolution of the map - one unit/pixel on the map (meters). Increase this value to improve the fidelity of
/// the map at the cost of memory usage. Decrease this
let mapResolution = Float(0.050)

/// How often the route is recalculated. Increase this value to reduce the rate that the route is recalculated,
/// while also reducing resource usage. Increase this value to update the route more frequently and reduce
/// latency, at the cost of higher resource usage.
let routeUpdateInterval = TimeInterval(0.1)

/// Proportional gain used for the motor's PI / PD / PID controller. Increasing this value causes the robot to
/// turn more rapidly. Setting the steering rate too high can cause the robot to overshoot the intended target
/// angle. This may lead to unwanted oscillating or weaving behaviour as the robot tries to correct the angle.
/// Increase this value if the robot does not turn sharply enough. Decrease this value if the robot turns too
/// aggressively, or if it weaves sideways when moving along a straight path.
let controllerProportional = Float(0.2)

/// Integral gain used for the motor's PI / PD / PID controller. Increase this value if the robot appears to weave
/// slowly (like a drunken person) when moving along a straight path. Decrease this value if the robot does not
/// turn sharply enough when turning a corner.
let controllerIntegral = Float(0.01)

/// Distance at which the robot considers that it has arrived at a waypoint. If the robot estimates it is within this
/// distance of a waypoint it will choose successive waypoints until no more remain. Increase this value if the
/// robot seems to orbit around a waypoint instead of moving to the next one. Decrease this value if the robot
/// appears to "cut corners" instead of following the intended path.
/// (meters)
let waypointDistanceThreshold = Float(0.250)

/// Remaining distance to the goal, at which the robot will stop. Increase this distance if the robot drives in
/// circles around the goal location instead of stopping. Decrease this value if the robot stops before the goal.
/// (meters)
let pathDistanceThreshold = Float(0.500)

/// Used to tune the robot's preference of reducing risk by increasing the distance at which it avoids obstacles
/// at the expense of using a longer route. The map increases the cost of moving toward an obstacle, so that
/// the robot prefers longer routes that increase the distance to obstacles. Increase this value to allow the
/// robot to drive closer to obstacles, at the expense of higher risk of collision.
let minimumMovementCost = Float(0.050)

/// Used to tune path smoothing behaviour. The robot will usually choose the waypoint furthest from it that
/// does lead to a collision. Increase this value to allow the robot to move closer to obstacles. Decrease the
/// value to decrease risk and increae the distance at which the robot passes obstacles.
let obstacleCostThreshold = Float(0.040)

/// Distance at which the robot will start slowing down when approaching a waypoint. When the robot
/// estimates it is within this distance of a waypoint, it will decrease its speed proportionally from the maximum
/// movement speed when it is farthest, to the minimum movement speed when it is closest. Reducing the
/// speed allows the robot to control its position and steering more precisely, which reduces the risk of
/// collision, improves location and speed estimation, and mitigates issues with LiDAR tracking which can
/// sometimes result from moving too quickly when turning.
let decelerationDistance = Measurement<UnitLength>(value: 1000, unit: .millimeters)

/// Maximum speed that the robot will move at as a percentage of the maximum possible motor speed, where
/// a value of 0 indicates no movement, and a value of 100 indicates the maximum possible speed.
/// Valid values are in the range from 0 to 100 inclusive. Increase this value to increase the robot's top speed.
let maximumMovementSpeed = 30

/// Minimum speed that the robot will move at as a percentage of the maximum possible motor speed, where
/// a value of 0 indicates no movement, and a value of 100 indicates the maximum possible speed.
/// Valid values are in the range from 0 to 100 inclusive.
let minimumMovementSpeed = 10

/// Port which the left hand side motor is connected to on the Lego® programmable hub.
let lhsMotorPort = MotorPort.A

/// Port which the right hand side motor is connected to on the Lego® programmable hub.
let rhsMotorPort = MotorPort.E

/// Interval at which commands are send to the programmable hub. Increase this value to reduce latency.
let commandUpdateInterval = TimeInterval(0.1)
