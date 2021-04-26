//
//  ViewController.swift
//  ARSelfDrivingRobot
//
//  Created by Luke Van In on 2021/04/03.
//

import UIKit
import SceneKit
import ARKit
import Combine

import SwiftMindstorms


func makeMeshMaterial(color: UIColor) -> SCNMaterial {
    let material = SCNMaterial()
    material.diffuse.contents = color
    material.fillMode = .fill
    material.lightingModel = .physicallyBased
    material.shininess = 0.8
    material.roughness.contents = 0.2
    material.metalness.contents = 0.1
    material.isDoubleSided = false
    return material
}


private let meshMaterials: [SCNMaterial] = [
    makeMeshMaterial(color: .systemTeal),
    makeMeshMaterial(color: .systemPink),
    makeMeshMaterial(color: .systemYellow),
    makeMeshMaterial(color: .systemGreen),
    makeMeshMaterial(color: .systemOrange),
    makeMeshMaterial(color: .systemBlue),
    makeMeshMaterial(color: .systemPurple),
]


func meshMaterial(for anchor: ARMeshAnchor) -> SCNMaterial {
    let i = Int(anchor.identifier.uuid.0) % meshMaterials.count
    return meshMaterials[i]
}


private let floorMaterial: SCNMaterial = {
    let material = SCNMaterial()
    material.diffuse.contents = UIColor.yellow.withAlphaComponent(1.0)
    material.fillMode = .lines
    return material
}()


private let goalMaterial = makeMeshMaterial(color: UIColor.systemIndigo.withAlphaComponent(0.9))


private let planeMaterial: SCNMaterial = {
    let material = SCNMaterial()
    material.diffuse.contents = UIColor.systemPink.withAlphaComponent(0.84)
    material.fillMode = .fill
    return material
}()

final class ViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate {
    
    private let robotConnectionButton: UIButton = {
        let button = UIButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.layer.cornerRadius = 16
        button.layer.masksToBounds = true
        button.backgroundColor = .systemPink
        button.contentEdgeInsets = UIEdgeInsets(top: 16, left: 32, bottom: 16, right: 32)
        button.alpha = 0.9
        return button
    }()
    
    private let trackingStateButton: UIButton = {
        let button = UIButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.layer.cornerRadius = 16
        button.layer.masksToBounds = true
        button.backgroundColor = .systemPink
        button.contentEdgeInsets = UIEdgeInsets(top: 16, left: 32, bottom: 16, right: 32)
        button.alpha = 0.9
        return button
    }()
    
    private let robotEnableButton: UIButton = {
        let button = UIButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.layer.cornerRadius = 16
        button.layer.masksToBounds = true
        button.backgroundColor = .systemPink
        button.contentEdgeInsets = UIEdgeInsets(top: 16, left: 32, bottom: 16, right: 32)
        button.alpha = 0.9
        return button
    }()

    private let sceneView: ARSCNView = {
        let view = ARSCNView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.showsStatistics = true
//        view.debugOptions = [.showFeaturePoints, .showWireframe]
        view.debugOptions = [.showWireframe]
        view.automaticallyUpdatesLighting = false
        view.rendersCameraGrain = false
        view.rendersMotionBlur = false
        view.antialiasingMode = .none
        view.autoenablesDefaultLighting = true
        view.isJitteringEnabled = false
        return view
    }()
    
    private let mapImageView: UIImageView = {
        let view = UIImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.contentMode = .scaleAspectFit
        view.layer.magnificationFilter = .nearest
        view.layer.minificationFilter = .nearest
        view.backgroundColor = .black
        view.alpha = 0.9
        return view
    }()
    
    private let routeImageView: UIImageView = {
        let view = UIImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.contentMode = .scaleAspectFit
        view.layer.magnificationFilter = .nearest
        view.layer.minificationFilter = .nearest
        view.backgroundColor = .black
        view.alpha = 0.9
        return view
    }()
    
    private let depthImageView: UIImageView = {
        let view = UIImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.contentMode = .scaleAspectFit
        view.layer.magnificationFilter = .nearest
        view.layer.minificationFilter = .nearest
        view.backgroundColor = .black
        view.alpha = 0.9
        return view
    }()

    #warning("TODO: Move all the interesting things into AppDelegate or some other ")
    private let agent = CurrentValueSubject<Agent?, Never>(nil)
    
    private let goal = CurrentValueSubject<Goal?, Never>(nil)
    
    private let trackingState = CurrentValueSubject<ARCamera.TrackingState, Never>(.notAvailable)
    
    private let fields = CurrentValueSubject<[UUID : Field], Never>([:])

    private var scanner: Scanner?

    private var mapper: Mapper?
    
    private var router: Router?
    
    private var navigator: Navigator?
    
    private var controller: Controller?
    
    private var routeRenderer: Renderer?
    
    private var hub: Hub?
    
    private var goalAnchor: ARAnchor?
    
    private let ciContext = CIContext(
        options: [
            CIContextOption.cacheIntermediates: false,
            CIContextOption.highQualityDownsample: false,
            CIContextOption.allowLowPower: false,
        ]
    )
    
    var isTorchOn = false
    
//    private let mapImageRenderer = MapImageRenderer()
    
//    private let mapImageQueue = DispatchQueue(
//        label: "map-image",
//        qos: .utility,
//        attributes: [],
//        autoreleaseFrequency: .inherit,
//        target: .global(qos: .utility)
//    )
    
//    private var mapRendering = false
    
//    private var fieldBufferPool = Pool<FlexibleBuffer<Blob>>(
//        count: 10,
//        make: { FlexibleBuffer<Blob>(capacity: 4096) },
//        recycle: { _ in }
//    )
    
//    private var updatingMap = false
//    private var mapNeedsUpdate = false
    
    private var cancellables = Set<AnyCancellable>()

    init() {
        super.init(nibName: nil, bundle: nil)
        let scanner = Scanner()
        let mapper = Mapper(
            agent: agent.eraseToAnyPublisher(),
            fields: scanner.fields.eraseToAnyPublisher()
        )
        let router = Router(
            agent: agent.compactMap { $0 }.eraseToAnyPublisher(),
            map: mapper.map.compactMap { $0 }.eraseToAnyPublisher(),
            goal: goal.eraseToAnyPublisher()
        )
        let navigator = Navigator(
            agent: agent.compactMap { $0 }.eraseToAnyPublisher(),
            waypoints: router.route
                .compactMap { route -> [WorldCoordinate] in
                    guard let route = route else {
                        return []
                    }
                    return route.waypoints
                }
                .eraseToAnyPublisher()
        )
        let hub = Hub(
            connection: BluetoothConnection()
        )
        let robot = Robot(
            orientation: .left,
            hub: hub
        )
        let controller = Controller(
            trajectory: navigator.trajectory.eraseToAnyPublisher(),
            robot: robot
        )
        let scene = Publishers
            .CombineLatest4(mapper.map.compactMap { $0 }, agent, router.route, navigator.trajectory)
            .map { map, agent, route, trajectory -> Renderer.Scene? in
                return Renderer.Scene(
                    map: map,
                    agent: agent,
                    goal: route?.goal,
                    trajectory: trajectory,
                    waypoints: route?.waypoints
                )
            }
//        let scene = Publishers
//            .CombineLatest4(mapper.map.compactMap { $0 }, agent, goal, router.route)
//            .map { map, agent, goal, route -> Renderer.Scene? in
//                return Renderer.Scene(
//                    map: map,
//                    agent: agent,
//                    goal: goal,
//                    trajectory: nil,
//                    waypoints: route?.waypoints
//                )
//            }
//        let scene = Publishers
//            .CombineLatest3(mapper.map.compactMap { $0 }, agent, goal)
//            .map { map, agent, goal -> Renderer.Scene? in
//                return Renderer.Scene(
//                    map: map,
//                    agent: agent,
//                    goal: goal,
//                    trajectory: nil,
//                    waypoints: nil
//                )
//            }
        let renderer = Renderer(
            scene: scene.eraseToAnyPublisher()
        )
        self.scanner = scanner
        self.mapper = mapper
        self.navigator = navigator
        self.controller = controller
        self.router = router
        self.routeRenderer = renderer
        self.hub = hub
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Set up the scene view delegate
        sceneView.delegate = self
        sceneView.session.delegate = self
        
        // Create the scene to display in the scene view
        let scene = SCNScene()
        scene.fogColor = UIColor.systemGray6
        scene.fogStartDistance = 3.0
        scene.fogEndDistance = 6.0
//        scene.fogDensityExponent = 2
        sceneView.scene = scene
        
        let buttonsLayout: UIStackView = {
            let layout = UIStackView(
                arrangedSubviews: [
                    robotConnectionButton,
                    trackingStateButton,
                    robotEnableButton
                ]
            )
            layout.translatesAutoresizingMaskIntoConstraints = false
            layout.axis = .vertical
            layout.spacing = 32
            layout.alignment = .fill
            return layout
        }()
        
        view.addSubview(sceneView)
        view.addSubview(mapImageView)
        view.addSubview(routeImageView)
        view.addSubview(depthImageView)
        view.addSubview(buttonsLayout)
        
        NSLayoutConstraint.activate([
            sceneView.leftAnchor.constraint(equalTo: view.leftAnchor),
            sceneView.topAnchor.constraint(equalTo: view.topAnchor),
            sceneView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 1.0),
            sceneView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 1.0),

            routeImageView.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -64),
            routeImageView.topAnchor.constraint(equalTo: view.topAnchor, constant: 64),
            routeImageView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.33),
            routeImageView.heightAnchor.constraint(equalTo: routeImageView.widthAnchor),

            mapImageView.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -64),
            mapImageView.topAnchor.constraint(equalTo: routeImageView.bottomAnchor, constant: 64),
            mapImageView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.33),
            mapImageView.heightAnchor.constraint(equalTo: mapImageView.widthAnchor),

            depthImageView.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 64),
            depthImageView.topAnchor.constraint(equalTo: view.topAnchor, constant: 64),
            depthImageView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.33),
            depthImageView.heightAnchor.constraint(equalTo: depthImageView.widthAnchor),

            buttonsLayout.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 32),
            buttonsLayout.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            buttonsLayout.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.33),

            robotConnectionButton.heightAnchor.constraint(equalToConstant: 64),

            robotEnableButton.heightAnchor.constraint(equalToConstant: 64),

            trackingStateButton.heightAnchor.constraint(equalToConstant: 64),
        ])
        
//        mapper?
//            .map
//            .compactMap { $0 }
//            .throttle(for: 0.200, scheduler: DispatchQueue.main, latest: true)
////            .receive(on: mapImageQueue)
//            .sink { [weak self] map in
//                dispatchPrecondition(condition: .onQueue(.main))
//                guard let self = self else {
//                    return
//                }
//                guard self.mapRendering == false else {
//                    return
//                }
//                self.mapRendering = true
//                self.mapImageQueue.async { [weak self] in
//                    guard let self = self else {
//                        return
//                    }
////                    let cgImage = self.mapImageRenderer.render(map: map)
//                    let cgImage = map.cgImage()
//                    DispatchQueue.main.async { [weak self] in
//                        guard let self = self else {
//                            return
//                        }
//                        let uiImage = cgImage.flatMap { UIImage(cgImage: $0) }
//                        self.mapImageView.image = uiImage
//                        print("ViewController: Map updated")
//                        self.mapRendering = false
//                    }
//                }
//            }
//            .store(in: &cancellables)
  
        mapper?
            .image
            .compactMap { $0 }
            .throttle(for: 0.200, scheduler: DispatchQueue.main, latest: true)
//            .receive(on: DispatchQueue.main)
            .sink { [weak self] cgImage in
                dispatchPrecondition(condition: .onQueue(.main))
                guard let self = self else {
                    return
                }
                let uiImage = UIImage(cgImage: cgImage)
                self.mapImageView.image = uiImage
            }
            .store(in: &cancellables)
        
        routeRenderer?
            .image
            .throttle(for: 0.200, scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] cgImage in
                dispatchPrecondition(condition: .onQueue(.main))
                guard let self = self else {
                    return
                }
                let uiImage = cgImage.flatMap { UIImage(cgImage: $0) }
                self.routeImageView.image = uiImage
            }
            .store(in: &cancellables)
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(onTapAction))
        sceneView.addGestureRecognizer(tapGesture)
        
        trackingStateButton.addTarget(self, action: #selector(onTrackingStateAction), for: .touchUpInside)

        robotEnableButton.addTarget(self, action: #selector(onRobotEnableAction), for: .touchUpInside)
        
        trackingState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard let self = self else {
                    return
                }
                let title: String
                let color: UIColor
                switch state {
                case .notAvailable:
                    title = "😵 Not available"
                    color = .lightGray
                case .normal:
                    title = "😎 Normal"
                    color = .systemGreen
                case .limited(.excessiveMotion):
                    title = "🥴 Excessive motion"
                    color = .systemOrange
                case .limited(.initializing):
                    title = "😴 Initializing"
                    color = .systemOrange
                case .limited(.insufficientFeatures):
                    title = "🙁 Insufficient features"
                    color = .systemOrange
                case .limited(.relocalizing):
                    title = "🧐 Relocalizing"
                    color = .systemRed
                }
                self.trackingStateButton.setTitle(title, for: .normal)
                self.trackingStateButton.backgroundColor = color
            }
            .store(in: &cancellables)
        
        hub?.connectionStatus
            .sink { [weak self] status in
                dispatchPrecondition(condition: .onQueue(.main))
                guard let self = self else {
                    return
                }
                let text: String
                let color: UIColor
                switch status {
                case .connected:
                    text = "😇 Connected"
                    color = .systemGreen
                case .connecting:
                    text = "🧐 Connecting..."
                    color = .systemOrange
                case .notConnected:
                    text = "🙁 Not connected"
                    color = .systemRed
                }
                self.robotConnectionButton.setTitle(text, for: .normal)
                self.robotConnectionButton.backgroundColor = color
            }
            .store(in: &cancellables)
        hub?.reconnect()
        robotConnectionButton.addAction(
            UIAction { [weak self] _ in
                guard let self = self else {
                    return
                }
                self.hub?.connect()
            },
            for: .touchUpInside
        )
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateRobotEnabled()
        startTracking()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        sceneView.scene.background.contents = UIColor.systemGray6
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneView.session.pause()
    }
    
    @objc func onRobotEnableAction(sender: UIButton) {
        guard let controller = controller else {
            return
        }
        controller.enabled.toggle()
        updateRobotEnabled()
    }
    
    @objc func onTrackingStateAction(sender: UIButton) {
        startTracking()
    }
    
    @objc func onTapAction(sender: UITapGestureRecognizer) {
        let location = sender.location(in: sceneView)
        guard let query = sceneView.raycastQuery(
            from: location,
            allowing: .estimatedPlane,
            alignment: .horizontal
        ) else {
            return
        }
        let results = sceneView.session.raycast(query)
        guard let result = results.first else {
            return
        }
        
        if let goalAnchor = self.goalAnchor {
            sceneView.session.remove(anchor: goalAnchor)
        }
        
        let goalAnchor = ARAnchor(transform: result.worldTransform)
        sceneView.session.add(anchor: goalAnchor)
        self.goalAnchor = goalAnchor
        
        let position = result.worldTransform * simd_float4(0, 0, 0, 1)
        let goal = WorldCoordinate(
            x: position.x / position.w,
            y: position.z / position.w
        )
        self.goal.send(goal)
    }
    
    private func startTracking() {

        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
//        configuration.planeDetection = [.horizontal, .vertical]
        configuration.planeDetection = [.horizontal]
//        configuration.sceneReconstruction = .meshWithClassification
        configuration.sceneReconstruction = .mesh
        configuration.frameSemantics = [.smoothedSceneDepth]
//        configuration.frameSemantics = [.sceneDepth]
        
//        let configuration = ARFaceTrackingConfiguration()
//        configuration.frameSemantics = [.smoothedSceneDepth]

        // Run the view's session
        sceneView.session.run(configuration, options: [.resetSceneReconstruction, .resetTracking, .removeExistingAnchors])
    }
    
    private func turnTorch(enabled: Bool) {
        guard let device = AVCaptureDevice.default(for: AVMediaType.video) else {
            return // Cant initiate avcapturedevice error
        }

        if device.hasTorch {
            do {
                try device.lockForConfiguration()

                if enabled && torchEnabled {
                    device.torchMode = .on
                } else {
                    device.torchMode = .off
                }
                self.isTorchOn = enabled // *** Add this line! ***

                device.unlockForConfiguration()
            } catch {
                return
            }

        } else {
            return
        }
    }
    
    private func updateRobotEnabled() {
        guard let controller = controller else {
            return
        }
        let title: String
        let color: UIColor
        if controller.enabled {
            title = "🤖 Robot Enabled"
            color = .systemGreen
        }
        else {
            title = "👾 Robot Disabled"
            color = .systemGray
        }
        robotEnableButton.setTitle(title, for: .normal)
        robotEnableButton.backgroundColor = color
    }
    
    // MARK: - ARSessionDelegate
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        dispatchPrecondition(condition: .onQueue(.main))
        if let depthData = frame.smoothedSceneDepth {
//            let pixelBuffer = depthData.depthDataMap
            let pixelBuffer = depthData.depthMap
            let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
            let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent)!
            let uiImage = UIImage(cgImage: cgImage, scale: 1.0, orientation: .right)
            self.depthImageView.image = uiImage
        }
        
        self.updateAnchors(anchors: frame.anchors)
    }
    
//    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
//        dispatchPrecondition(condition: .onQueue(.main))
//        guard case .normal = trackingState.value else {
//            return
//        }
//        self.updateAnchors(anchors: anchors)
//    }
    
//    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
//        dispatchPrecondition(condition: .onQueue(.main))
//        guard case .normal = trackingState.value else {
//            return
//        }
//        self.updateAnchors(anchors: anchors)
//    }
    
    // MARK: - ARSessionObserver
    
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        self.trackingState.send(camera.trackingState)
    }
    
    func sessionShouldAttemptRelocalization(_ session: ARSession) -> Bool {
        return true
    }
    
    // MARK: - ARSCNViewDelegate
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        // Place content only for anchors found by plane detection.
//        if let planeAnchor = anchor as? ARPlaneAnchor {
//            // Create a custom object to visualize the plane geometry and extent.
//            let plane = Plane(
//                anchor: planeAnchor,
//                in: sceneView,
//                material: planeMaterial
//            )
//            plane.position = SCNVector3(x: 0, y: -0.1, z: 0)
//
//            // Add the visualization to the ARKit-managed node so that it tracks
//            // changes in the plane anchor as plane estimation continues.
//            node.addChildNode(plane)
//        }
        
        if let meshAnchor = anchor as? ARMeshAnchor {
            let geometry = SCNGeometry(arGeometry: meshAnchor.geometry)
            geometry.firstMaterial = meshMaterial(for: meshAnchor)
            let meshNode = SCNNode(geometry: geometry)
            node.addChildNode(meshNode)
            
//            if let floorGeometry = SCNGeometry.from(meshAnchor.geometry, ofType: .floor) {
//                floorGeometry.firstMaterial = floorMaterial
//                let floorNode = SCNNode(geometry: floorGeometry)
//                 node.addChildNode(floorNode)
//            }

//            self.updateAnchor(meshAnchor)
//            let myMeshAnchor = meshAnchor.copy() as! ARMeshAnchor
//            DispatchQueue.main.async { [weak self] in
//                self?.updateAnchors(anchors: [myMeshAnchor])
//            }
        }
        
        if anchor.identifier == goalAnchor?.identifier {
            let geometry = SCNBox(width: 0.2, height: 0.2, length: 0.2, chamferRadius: 0)
            geometry.firstMaterial = goalMaterial
            let boxNode = SCNNode(geometry: geometry)
            node.addChildNode(boxNode)
        }
    }

    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
//        if let planeAnchor = anchor as? ARPlaneAnchor {
//            if let plane = node.childNodes.first as? Plane {
//                plane.updateMesh(from: planeAnchor.geometry)
//            }
//        }

        if
            let meshAnchor = anchor as? ARMeshAnchor,
            let meshNode = node.childNodes.first
        {
            
            let meshGeometry = SCNGeometry(arGeometry: meshAnchor.geometry)
            meshGeometry.firstMaterial = meshMaterial(for: meshAnchor)
            meshNode.geometry = meshGeometry

//            if node.childNodes.count > 1 {
//                let floorNode = node.childNodes[1]
//                if let floorGeometry = SCNGeometry.from(meshAnchor.geometry, ofType: .floor) {
//                    floorGeometry.firstMaterial = floorMaterial
//                    floorNode.geometry = floorGeometry
//                }
//            }

            node.simdTransform = anchor.transform
            
//            let myMeshAnchor = meshAnchor.copy() as! ARMeshAnchor
//            DispatchQueue.main.async { [weak self] in
//                self?.updateAnchors(anchors: [myMeshAnchor])
//            }
        }
        
        if anchor.identifier == goalAnchor?.identifier {
            node.simdTransform = anchor.transform
            
            let position = anchor.transform * simd_float4(0, 0, 0, 1)
            let goal = WorldCoordinate(
                x: position.x / position.w,
                y: position.z / position.w
            )
            self.goal.send(goal)
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didRemove node: SCNNode, for anchor: ARAnchor) {
        
    }
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        if let pointOfView = renderer.pointOfView {
            let worldPosition = pointOfView.worldPosition
            let worldOrientation: Float = {
                let o = pointOfView.worldOrientation
                let q = simd_quatf(ix: o.x, iy: o.y, iz: o.z, r: o.w)
                let m = simd_matrix4x4(q)
                let n = simd_float4(0, 0, 1, 1)
                let h = m * n
                let j = simd_normalize(h)
                let a = atan2(-j.z, -j.x)
                return a
            }()
            
            #warning("TODO: Apply inverse of sensor transform to accomodate the lidar position relative to the machine")
            
            let agent = Agent(
                position: WorldCoordinate(
                    x: worldPosition.x,
                    y: worldPosition.z
                ),
                elevation: worldPosition.y - agentCameraElevation,
                heading: worldOrientation,
                radius: agentRadius
            )
            self.agent.send(agent)
        }
    }
    
    private func updateAnchors(anchors: [ARAnchor]) {
        dispatchPrecondition(condition: .onQueue(.main))
        let meshAnchors = anchors.compactMap { anchor -> ARAnchor? in
            guard anchor is ARMeshAnchor else {
                return nil
            }
//            return anchor.copy() as? ARAnchor
            return anchor
        }
        scanner?.update(anchors: meshAnchors)
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
        print(error.localizedDescription)
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didRenderScene scene: SCNScene, atTime time: TimeInterval) {
        if self.sceneView.session.currentFrame != nil {
            if !isTorchOn {
                turnTorch(enabled: true)
            }
        }
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        #warning("TODO: Stop the robot")
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        #warning("TODO: Continue moving")
    }
}
