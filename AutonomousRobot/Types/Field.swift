//
//  Mesh.swift
//  ARSelfDrivingRobot
//
//  Created by Luke Van In on 2021/04/14.
//

import Foundation
import ARKit
import simd


///
/// Direction of the sky or ceiling relative to the ground. ARKit defines the positive Y-axis as "up".
///
private let upVector = simd_float3(0, 1, 0)


///
/// Represents the position and radius of a disc which circumscribes the coordinates of a triangle projected
/// onto a 2D plane. The disc is rendered into an occupancy grid to indicate the approximate position and size
/// of a triangle.
///
struct Blob: Hashable {
    var center: SIMD4<Float>
    var radius: Float
}


///
/// Approximation of a 3D mesh represented as a point cloud. Each face in the mesh is represented by disc
/// circumscribing the coordinates of the face projected onto a 2D plane. Used to render a 2D _height map_
/// representative of the mesh, which is then used to produce an occupancy grid describing the obstacles and
/// navigable space in the world.
///
class Field {

    fileprivate(set) var hash: Int
    fileprivate(set) var count: Int
    fileprivate(set) var bounds: Volume
    fileprivate(set) var transform: simd_float4x4
    fileprivate var buffer: PoolObject<FlexibleBuffer<Blob>>
    
    init(buffer: PoolObject<FlexibleBuffer<Blob>>) {
        self.buffer = buffer
        self.bounds = .undefined
        self.count = 0
        self.hash = 0
        self.transform = matrix_identity_float4x4
    }
    
    subscript(index: Int) -> Blob {
        precondition(index >= 0)
        precondition(index < buffer.subject.capacity)
        return buffer.subject[index]
    }
}


extension Field {
    
    ///
    /// Convenience method used to initialize a field (point cloud) from an _ARMeshAnchor_. Each
    /// triangle is approximated by a disc. Computes the bounding volume of the resulting point cloud.
    ///
    convenience init(anchor: ARMeshAnchor, buffer: PoolObject<FlexibleBuffer<Blob>>) {
        precondition(anchor.geometry.faces.bytesPerIndex == MemoryLayout<UInt32>.size, "Expected one UInt32 (four bytes) per vertex index")
        precondition(anchor.geometry.vertices.format == MTLVertexFormat.float3, "Expected three floats (twelve bytes) per vertex.")
        precondition(anchor.geometry.normals.format == MTLVertexFormat.float3, "Expected three floats (twelve bytes) per vertex.")
        precondition(anchor.geometry.faces.indexCountPerPrimitive == 3, "Expected 3 vertices per face")
        precondition(anchor.geometry.vertices.componentsPerVector == 3, "Expected 3 components per vertex vector")
        self.init(buffer: buffer)
        
        let blobs = buffer.subject
        let geometry = anchor.geometry
        let vertexCountPerFace = geometry.faces.indexCountPerPrimitive
        let faceCount = geometry.faces.count
        var bounds = self.bounds
        var count = 0

        self.transform = anchor.transform
        
        guard faceCount > 0 else {
            // No faces
            return
        }

        // Allocate enough space for all the faces (even though we might discard some).
        if faceCount > blobs.capacity {
            blobs.reallocate(capacity: faceCount)
        }
        
        let vertexIndicesPointer = geometry.faces.buffer.contents()
        let vertices = geometry.vertices
        let verticesBuffer = geometry.vertices.buffer.contents()
        let normals = geometry.normals
        let normalsBuffer = normals.buffer.contents()
        var vectors = Array<SIMD3<Float>>(repeating: .zero, count: vertexCountPerFace)
        for faceIndex in 0 ..< faceCount {

            // Compute centroid of the face
            var center = SIMD3<Float>(0, 0, 0)
            for vertexOffset in 0 ..< vertexCountPerFace {
                let vertexIndexPointer = vertexIndicesPointer.advanced(by: (faceIndex * vertexCountPerFace + vertexOffset) * MemoryLayout<UInt32>.size)
                let index = vertexIndexPointer.assumingMemoryBound(to: UInt32.self).pointee
                let vertexPointer = verticesBuffer.advanced(by: vertices.offset + (vertices.stride * Int(index)))
                let vertex = vertexPointer.assumingMemoryBound(to: (Float, Float, Float).self).pointee
                let vector = SIMD3<Float>(vertex.0, vertex.1, vertex.2)
                center += vector
                vectors[vertexOffset] = vector
            }
            
            // Check if the face is facing "up". Reject faces pointing
            // downwards (ignore ceilings).
            let va = vectors[1] - vectors[0]
            let vb = vectors[2] - vectors[0]
            let normal = simd_normalize(simd_cross(va, vb))

            let dotproduct = simd_dot(normal, upVector)
            if dotproduct < 0 {
                // Face is oriented in the opposite direction to the "up"
                // vector. Reject the face
                continue
            }
            
            // Center is average of the three vectors for the face.
            center = center / Float(vertexCountPerFace)
            // Radius is the length of the longest vector in the x-z plane.
            var radius = Float(0)
            for j in 0 ..< vertexCountPerFace {
                let v = vectors[j]
                let p = SIMD2<Float>(v.x - center.x, v.z - center.z)
                let r = simd_length(p)
                radius = max(radius, r)
            }

            guard radius > 0 else {
                // Skip degenerate triangle.
                continue
            }

            let origin = SIMD4(center, 1)
            let blob = Blob(
                center: origin,
                radius: radius
            )
            blobs[count] = blob
            count += 1
            
            bounds.min.x = min(bounds.min.x, origin.x - radius)
            bounds.min.y = min(bounds.min.y, origin.y)
            bounds.min.z = min(bounds.min.z, origin.z - radius)

            bounds.max.x = max(bounds.max.x, origin.x + radius)
            bounds.max.y = max(bounds.max.y, origin.y)
            bounds.max.z = max(bounds.max.z, origin.z + radius)
        }
        self.bounds = bounds
        self.count = count
    }
}
