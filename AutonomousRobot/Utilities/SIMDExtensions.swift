//
//  SIMDExtensions.swift
//  ARSelfDrivingRobot
//
//  Created by Luke Van In on 2021/04/18.
//

import Foundation
import simd


extension Float {
    
}


/// See: https://developer.apple.com/documentation/accelerate/working_with_matrices

extension simd_float3x3 {
    
    static func rotate(angle: Float) -> simd_float3x3 {
        let p = cos(angle)
        let q = sin(angle)
        let r = -q
        return simd_matrix_from_rows(
            simd_float3(p, r, 0),
            simd_float3(q, p, 0),
            simd_float3(0, 0, 1)
        )
    }
    
    static func translate(_ vector: simd_float2) -> simd_float3x3 {
        translate(x: vector.x, y: vector.y)
    }
    
    static func translate(x: Float, y: Float) -> simd_float3x3 {
        return simd_matrix_from_rows(
            simd_float3(1, 0, x),
            simd_float3(0, 1, y),
            simd_float3(0, 0, 1)
        )
    }
    
    static func scale(_ vector: simd_float2) -> simd_float3x3 {
        scale(x: vector.x, y: vector.y)
    }

    static func scale(_ factor: Float) -> simd_float3x3 {
        scale(x: factor, y: factor)
    }

    static func scale(x: Float, y: Float) -> simd_float3x3 {
        return simd_matrix_from_rows(
            simd_float3(x, 0, 0),
            simd_float3(0, y, 0),
            simd_float3(0, 0, 1)
        )
    }
}


extension simd_float4x4 {
    
    static func rotate(angle: Float, axis: simd_float3) -> simd_float4x4 {
        let q = simd_quaternion(angle, axis)
        return simd_matrix4x4(q)
    }
    
    static func scale(_ scale: simd_float3) -> simd_float4x4 {
        simd_float4x4(diagonal: simd_float4(scale, 1))
    }
    
    static func scale(x: Float, y: Float, z: Float) -> simd_float4x4 {
        simd_float4x4(diagonal: simd_float4(x, y, z, 1))
    }

    static func translate(_ delta: simd_float3) -> simd_float4x4 {
        translate(x: delta.x, y: delta.y, z: delta.z)
    }
    
    static func translate(x: Float, y: Float, z: Float) -> simd_float4x4 {
        simd_matrix_from_rows(
            simd_float4(1, 0, 0, x),
            simd_float4(0, 1, 0, y),
            simd_float4(0, 0, 1, z),
            simd_float4(0, 0, 0, 1)
        )
    }
}
