//
//  Renderer.swift
//  ARSelfDrivingRobot
//
//  Created by Luke Van In on 2021/04/08.
//

import UIKit
import Foundation
import CoreGraphics
import Combine


///
/// Draws a representation of the state of the world including the generated map, agent's position, current
/// goal, waypoints, and trajectory. The rendering is used for visualizing the internal workings of the program.
///
final class Renderer: ObservableObject {

    struct Scene {
        var map: Map
        var agent: Agent?
        var goal: WorldCoordinate?
        var trajectory: Trajectory?
        var waypoints: [WorldCoordinate]?
    }

    private struct ImageRenderer {
        let scene: Scene
        let ciContext: CIContext
        let cellRadius: CGFloat = 4
        let agentRadius: CGFloat = 8
        let waypointRadius: CGFloat = 3
        let width: Int
        let height: Int
        let center: CGPoint
        let mapToViewTransform: CGAffineTransform
        
        init(scene: Scene, ciContext: CIContext) {
            self.scene = scene
            let width = CGFloat(scene.map.dimensions.x) * cellRadius * 2
            let height = CGFloat(scene.map.dimensions.y) * cellRadius * 2
            self.width = Int(width)
            self.height = Int(height)
            self.center = CGPoint(
                x: width * 0.5,
                y: height * 0.5
            )
            self.ciContext = ciContext
            self.mapToViewTransform = CGAffineTransform
                .identity
                .translatedBy(x: 0, y: height)
                .scaledBy(x: cellRadius * 2, y: -cellRadius * 2)
        }

        func render() -> CGImage? {
            
            let cellInset = UIEdgeInsets(
                top: cellRadius,
                left: cellRadius,
                bottom: cellRadius,
                right: cellRadius
            )
            
            let agentInset = UIEdgeInsets(
                top: agentRadius,
                left: agentRadius,
                bottom: agentRadius,
                right: agentRadius
            )

            let waypointInset = UIEdgeInsets(
                top: waypointRadius,
                left: waypointRadius,
                bottom: waypointRadius,
                right: waypointRadius
            )

//            let space = scene.map.space
//            let agentOrigin = CGPoint(
//                x: (space.worldOrigin.x / space.worldSize.x) * space.scale,
//                y: (space.worldOrigin.y / space.worldSize.y) * space.scale
//            )
//            let width = Int(ceil(CGFloat(scene.map.dimensions.x) * cellRadius * 2))
//            let height = Int(ceil(CGFloat(scene.map.dimensions.y) * cellRadius * 2))

            #warning("TODO: Use memory pool")
            let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue)
            let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: bitmapInfo.rawValue
            )!
            context.setShouldAntialias(false)
            context.setAllowsAntialiasing(false)
            context.interpolationQuality = .none

            context.setFillColor(UIColor.yellow.cgColor)
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
            
            // Map
            if let mapImage = scene.map.cgImage() {
                context.saveGState()
                let mapSize = CGSize(
                    width: width,
                    height: height
                )
                let mapRect = CGRect(
                    origin: .zero,
                    size: mapSize
                )
                context.setFillColor(UIColor.cyan.cgColor)
                context.fill(mapRect)
                context.setBlendMode(.difference)
                context.draw(mapImage, in: mapRect)
                
                context.restoreGState()
            }
            
            context.setBlendMode(.normal)
            
            // Origin
            let zp = convert(WorldCoordinate(x: 0, y: 0))
            let zr = CGRect(origin: zp, size: .zero).inset(by: agentInset)
            context.setFillColor(UIColor.systemPink.cgColor)
            context.fillEllipse(in: zr)

            // Waypoints
            if let waypoints = scene.waypoints, waypoints.count > 0 {
                if waypoints.count > 1 {
                    context.move(to: convert(waypoints[0]))
                    context.addLine(to: convert(waypoints[1]))
                    context.setStrokeColor(UIColor.black.cgColor)
                    context.setLineWidth(3)
                    context.strokePath()

                    if waypoints.count > 2 {
                        context.move(to: convert(waypoints[1]))
                        for i in 2 ..< waypoints.count {
                            let c = convert(waypoints[i])
                            context.addLine(to: c)
                        }
                        context.setStrokeColor(UIColor.gray.cgColor)
                        context.setLineWidth(2)
                        context.strokePath()
                    }
                }

                for (i, waypoint) in waypoints.enumerated() {
                    let c = convert(waypoint)
                    let r = CGRect(origin: c, size: .zero).inset(by: waypointInset)
                    if i <= 1 {
                        context.setFillColor(UIColor.black.cgColor)
                    }
                    else {
                        context.setFillColor(UIColor.gray.cgColor)
                    }
                    context.fillEllipse(in: r)
                }
            }
            
            // Agent
            if let agent = scene.agent {
                let p = convert(agent.position)
                let h = 0
                let q = CGPoint(
                    x: p.x + (cos(CGFloat(h)) * agentRadius),
                    y: p.y + (sin(CGFloat(h)) * agentRadius)
                )
                let r = CGRect(origin: p, size: .zero).inset(by: agentInset)
                context.setFillColor(UIColor.blue.cgColor)
                context.fillEllipse(in: r)

                context.move(to: p)
                context.addLine(to: q)
                context.setLineWidth(5)
                context.setStrokeColor(UIColor.white.cgColor)
                context.strokePath()


//                if let trajectory = scene.trajectory {
////                    let p = convert(agent.position)
//                    // let h = (-agent.heading - .pi) + trajectory.heading
//                    let heading = Float(trajectory.heading.converted(to: .radians).value)
//                    let distance = Float(trajectory.distance.converted(to: .meters).value)
//                    let h = agent.heading + heading
//                    let d = CGFloat(distance * scene.map.space.scale) * (cellRadius * 2)
//                    let q = CGPoint(
//                        x: p.x + (cos(CGFloat(h)) * d),
//                        y: p.y + (sin(CGFloat(h)) * d)
//                    )
//                    context?.move(to: p)
//                    context?.addLine(to: q)
//                    context?.setLineWidth(5)
//                    context?.setStrokeColor(UIColor.red.cgColor)
//                    context?.strokePath()
//                }
            }
            
            // Goal
            if let goal = scene.goal {
                let p = convert(goal)
                let r = CGRect(origin: p, size: .zero).inset(by: waypointInset)
                context.setFillColor(UIColor.systemIndigo.cgColor)
                context.fillEllipse(in: r)
            }
            
            // Rotate map
            let mapImage = context.makeImage()!
            return mapImage
//            let ciInputImage = CIImage(cgImage: mapImage)
//            let ciOutputImage = ciInputImage.oriented(CGImagePropertyOrientation.left)
//            let outputImage = ciContext.createCGImage(ciOutputImage, from: ciOutputImage.extent)
//            return outputImage
        }
        
        private func convert(_ coordinate: WorldCoordinate) -> CGPoint {
            let p = scene.map.space.toMapPoint(coordinate)
            return p.applying(mapToViewTransform)
        }
        
        private func convert(_ coordinate: MapCoordinate) -> CGPoint {
            let p = CGPoint(x: coordinate.x, y: coordinate.y)
            return p.applying(mapToViewTransform)
        }
    }

    let image = CurrentValueSubject<CGImage?, Never>(nil)

    private let ciContext = CIContext(
        options: [
            CIContextOption.cacheIntermediates: false,
            CIContextOption.highQualityDownsample: true,
            CIContextOption.useSoftwareRenderer: false,
        ]
    )
    private var queue = DispatchQueue(
        label: "render",
        qos: .utility,
        attributes: [],
        autoreleaseFrequency: .inherit,
        target: .global(qos: .utility)
    )
    private var cancellables = Set<AnyCancellable>()
    private var rendering = false
    private var pendingScene: Scene?

    init(scene: AnyPublisher<Scene?, Never>) {
        scene
            .receive(on: DispatchQueue.main)
            .sink { [weak self] scene in
                guard let self = self else {
                    return
                }
                guard let scene = scene else {
                    return
                }
                self.pendingScene = scene
                self.update()
            }
            .store(in: &cancellables)
    }
    
    private func update() {
        dispatchPrecondition(condition: .onQueue(.main))
        guard rendering == false else {
            return
        }
        guard let currentScene = pendingScene else {
            return
        }
        pendingScene = nil
        rendering = true
        queue.async { [weak self, ciContext] in
            let renderer = ImageRenderer(scene: currentScene, ciContext: ciContext)
            let start = Date()
            let image = renderer.render()
            let elapsed = Date().timeIntervalSince(start)
            print("Render: Time", String(format: "%0.3f", elapsed))
            DispatchQueue.main.asyncAfter(wallDeadline: .now() + 0.2) {
                guard let self = self else {
                    return
                }
                if let image = image {
                    self.image.send(image)
                }
                self.rendering = false
                self.update()
            }
        }
    }
}
