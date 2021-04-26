//
//  Scanner.swift
//  ARSelfDrivingRobot
//
//  Created by Luke Van In on 2021/04/08.
//

import ARKit
import Combine


typealias Fields = [UUID : Field]


private class AnyState {
    weak var context: Scanner!
    
    func update(anchors: [ARAnchor]) {
    }
    
    func enter() {
    }
}


private final class ReadyState: AnyState {
    
    override func update(anchors: [ARAnchor]) {
        dispatchPrecondition(condition: .onQueue(.main))
        context.gotoWorkingState(anchors: anchors)
    }
}

private final class WorkingState: AnyState {
    
    private var pendingAnchors = [ARAnchor]()
    private let anchors: [ARAnchor]
    
    init(anchors: [ARAnchor]) {
        self.anchors = anchors
    }
    
    override func update(anchors: [ARAnchor]) {
        dispatchPrecondition(condition: .onQueue(.main))
        pendingAnchors = anchors
    }
    
    override func enter() {
        dispatchPrecondition(condition: .onQueue(.main))
        let start = Date()
        var count = 0
        var fields = Fields()
        for anchor in self.anchors {
            guard let meshAnchor = anchor as? ARMeshAnchor else {
                continue
            }
            let buffer = self.context.bufferPool.allocate()
            let field = Field(anchor: meshAnchor, buffer: buffer)
            if field.count > 0 {
                fields[anchor.identifier] = field
            }
            fields[anchor.identifier] = field
            count += field.count
        }
        let elapsed = Date().timeIntervalSince(start)
        self.context.internalFields = fields
        print("Scanner: Time", String(format: "%0.3f", elapsed), "points:", count)
        self.context.fields.send(fields)
        if self.pendingAnchors.count > 0 {
            self.context.gotoWorkingState(anchors: self.pendingAnchors)
        }
        else {
            self.context.gotoReadyState()
        }
    }
}


///
/// Converts mesh anchors provided by ARKit to a`Field` array, used for rending the map.
///
final class Scanner {
    
    let fields = CurrentValueSubject<Fields, Never>([:])
    
    fileprivate var internalFields = Fields()
    fileprivate let bufferPool = Pool<FlexibleBuffer<Blob>>(
        count: 10,
        make: { FlexibleBuffer<Blob>(capacity: 4096) },
        recycle: { _ in }
    )

    private var currentState: AnyState?
    
    init() {
        gotoReadyState()
    }
    
    func update(anchors: [ARAnchor]) {
        dispatchPrecondition(condition: .onQueue(.main))
        currentState?.update(anchors: anchors)
    }
    
    fileprivate func gotoReadyState() {
        setState(ReadyState())
    }
    
    fileprivate func gotoWorkingState(anchors: [ARAnchor]) {
        setState(WorkingState(anchors: anchors))
    }

    private func setState(_ state: AnyState?) {
        currentState = state
        currentState?.context = self
        currentState?.enter()
    }
}
