//
//  Controller.swift
//  ARSelfDrivingRobot
//
//  Created by Luke Van In on 2021/04/10.
//

import Foundation
import Combine

import SwiftMindstorms


///
/// Sends commands to the robot to steer and move the robot toward a given trajectory. Stops the robot when
/// the robot is when no trajectory is given.
///
final class Controller {
    
    struct Configuration {
        var moveSpeed: Int
        var turnSpeed: Int
        var lhsMotorPort: MotorPort
        var rhsMotorPort: MotorPort
    }
    
    struct MotorSpeed {
        var lhs: Float
        var rhs: Float
    }
    
    fileprivate var configuration: Configuration = Configuration(
        moveSpeed: maximumMovementSpeed,
        turnSpeed: minimumMovementSpeed,
        lhsMotorPort: lhsMotorPort,
        rhsMotorPort: rhsMotorPort
    )
    
    var enabled: Bool = false
    
    private var trajectory: Trajectory = .zero
    private var headingPID = PID(
        kp: controllerProportional,
        ki: controllerIntegral
    )
    private var motorSpeed: MotorSpeed = MotorSpeed(lhs: 0, rhs: 0)

    private var updateTimer: Timer?
    private var sendingCommand = false

    private var cancellables = Set<AnyCancellable>()
    fileprivate let robot: Robot

    init(
        trajectory: AnyPublisher<Trajectory?, Never>,
        robot: Robot
    ) {
        self.robot = robot
        trajectory
            .receive(on: DispatchQueue.main)
            .sink { [weak self] trajectory in
                guard let self = self else {
                    return
                }
                self.update(trajectory: trajectory)
            }
            .store(in: &cancellables)
        updateTimer = Timer.scheduledTimer(withTimeInterval: commandUpdateInterval, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self = self else {
                    return
                }
                self.sendMotorCommands()
            }
        }
    }
    
    private func update(trajectory: Trajectory?) {
        dispatchPrecondition(condition: .onQueue(.main))
        if let trajectory = trajectory, enabled == true {
            self.trajectory = trajectory
            calculateMotorSpeed()
        }
        else {
            self.trajectory = Trajectory.zero
            headingPID.reset()
            motorSpeed = MotorSpeed(lhs: 0, rhs: 0)
        }
    }
    
    private func calculateMotorSpeed() {
        let angle = Float(trajectory.heading.converted(to: .radians).value)
        let distance = Float(trajectory.distance.converted(to: .millimeters).value)
        let approachDistance = Float(decelerationDistance.converted(to: .millimeters).value)

        headingPID.update(error: angle)
        
        precondition(approachDistance >= 0)
        precondition(abs(headingPID.controlVariable) <= .pi)
        precondition(abs(angle) <= .pi)

        // Map angle from 0 ... ±.pi to 0 ... 1
        // Delta is the difference in speed between the left and right wheels:
        // 0 = Both wheels turn forward at the same speed.
        // 0 ... +0.25 = Left wheel turns faster than right wheel.
        // +0.25 ... +0.5 = Left wheel turns forward. Right wheel turns backwards.
        // +0.5 ... +1 = Left wheel turns forward. Right wheel turns backwards.
        let lhsSpeed: Float
        let rhsSpeed: Float
        let delta = headingPID.controlVariable / (.pi * 0.5)
        let compensation = 1 - (abs(delta) * 2)
        if delta > 0 {
            // Turning right
            lhsSpeed = 1
            rhsSpeed = compensation
        }
        else if delta < 0 {
            // Turning left
            rhsSpeed = 1
            lhsSpeed = compensation
        }
        else {
            // Straight ahead
            lhsSpeed = 1
            rhsSpeed = 1
        }

        // Calculate speed based on turning amount
        let speed: Float
        let speedLimit: Float
        if distance < approachDistance {
            speedLimit = distance / approachDistance
        }
        else {
            speedLimit = 1
        }
        let speedMin = Float(configuration.turnSpeed)
        let speedMax = Float(configuration.moveSpeed)
        let speedRange = speedMax - speedMin
        let s = (1 - abs(delta)) * speedLimit
        speed = speedMin + (s * speedRange)

        #warning("TODO: Set maximum speed limit based on distance to the target so that we slow down before reaching the target")
        #warning("TODO: Use PID controller for left and right wheels (gradually adjust speed based on measured speed")
        #warning("TODO: Use average heading based on difference between internal trajectory and external trajectory (use internal trajectory more")

        let lhsOutputSpeed = speed * lhsSpeed
        let rhsOutputSpeed = speed * rhsSpeed
        
        motorSpeed.lhs = lhsOutputSpeed
        motorSpeed.rhs = rhsOutputSpeed
 
        print(
            "Controller: Heading:",
            "A:", String(format: "%0.3f", angle),
            "CV:", String(format: "%0.3f", headingPID.controlVariable),
            "D:", String(format: "%0.3f", distance),
            "∂:", String(format: "%0.3f", delta),
            "S:", String(format: "%0.3f", speed),
            "LHS:", String(format: "%0.3f", lhsSpeed),
            "RHS:", String(format: "%0.3f", rhsSpeed)
        )
    }

    private func sendMotorCommands() {
        dispatchPrecondition(condition: .onQueue(.main))
        guard sendingCommand == false else {
            return
        }
        sendingCommand = true
        let request: AnyRequest
        if enabled {
            print(
                "Controller: Motor",
                "L:", String(format: "%0.3f", motorSpeed.lhs),
                "R:", String(format: "%0.3f", motorSpeed.rhs)
            )
            request = AnyRequest(
                MoveStartSpeeds(
                    lspeed: Int(round(motorSpeed.lhs)),
                    rspeed: Int(round(motorSpeed.rhs)),
                    lmotor: configuration.lhsMotorPort,
                    rmotor: configuration.rhsMotorPort
                )
            )
        }
        else {
            print("Controller: Motor: Stop")
            request = AnyRequest(
                MoveStop(
                    lmotor: configuration.lhsMotorPort,
                    rmotor: configuration.rhsMotorPort
                )
            )
        }
        robot.enqueue(
            request: request,
            completion: { _ in }
        )
        self.sendingCommand = false
    }
}
