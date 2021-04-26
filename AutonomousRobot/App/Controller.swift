//
//  Controller.swift
//  ARSelfDrivingRobot
//
//  Created by Luke Van In on 2021/04/10.
//

import Foundation
import Combine

import SwiftMindstorms


private let headingThreshold = Measurement<UnitAngle>(value: 7, unit: .degrees)
private let decelerationDistance = Measurement<UnitLength>(value: 1000, unit: .millimeters)
private let headingDamping = Float(0.2)


private let angleFormatter: MeasurementFormatter = {
    let formatter = MeasurementFormatter()
    return formatter
}()


private let distanceFormatter: MeasurementFormatter = {
    let formatter = MeasurementFormatter()
    formatter.unitOptions = .naturalScale
    return formatter
}()


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
        moveSpeed: 30,
        turnSpeed: 10,
        lhsMotorPort: .A,
        rhsMotorPort: .E
    )
    
    var enabled: Bool = false
    
    private var trajectory: Trajectory = .zero
    private var headingPID = PID(
//        kp: 0.1,
        kp: 0.2,
        ki: 0.01
    )
    private var motorSpeed: MotorSpeed = MotorSpeed(lhs: 0, rhs: 0)

    private var updateTimer: Timer?
    private var sendingCommand = false

    private var cancellables = Set<AnyCancellable>()
    fileprivate let robot: Robot

    #warning("TODO: Use a kalman filter to compensate for heading and movement")
    
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
        updateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
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
//        let delta = currentHeading / (.pi * 0.5)
        let delta = headingPID.controlVariable / (.pi * 0.5)
//        let delta = headingPID.controlVariable / .pi
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
        
//        motorSpeed.lhs = motorSpeed.lhs + ((lhsOutputSpeed - motorSpeed.lhs) * motorAcceleration)
//        motorSpeed.rhs = motorSpeed.rhs + ((rhsOutputSpeed - motorSpeed.rhs) * motorAcceleration)
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
        DispatchQueue.main.asyncAfter(wallDeadline: .now() + 0.1) { [weak self] in
            dispatchPrecondition(condition: .onQueue(.main))
            guard let self = self else {
                return
            }
            self.sendingCommand = false
        }
    }
}
