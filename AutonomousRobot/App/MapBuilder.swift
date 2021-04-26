//
//  MapBuilder.swift
//  ARSelfDrivingRobot
//
//  Created by Luke Van In on 2021/04/14.
//

import Foundation
import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins
import simd

private let mapFade = Float(0.1)
private let roofThreshold = Float(1.800)
private let floorVariance = Float(0.063)
//private let outputMapResolution = Float(0.050)
//private let outputMapScale = 1 / outputMapResolution

final class MapBuilder {
    
    let dimensions: MapCoordinate
    var space: MapCoordinateSpace
    let margin: Float
    var oldData: UnsafeMutableBufferPointer<Float>
    var data: UnsafeMutableBufferPointer<Float>
    let mapBufferPool: BufferPool<Float>
    let ciContext: CIContext
    
    init(
        dimensions: MapCoordinate,
        space: MapCoordinateSpace,
        margin: Float
    ) {
        self.dimensions = dimensions
        self.space = space
        self.margin = margin
        self.oldData = UnsafeMutableBufferPointer.allocate(capacity: dimensions.x * dimensions.y)
        self.data = UnsafeMutableBufferPointer.allocate(capacity: dimensions.x * dimensions.y)
        self.mapBufferPool = BufferPool(ageOutPeriod: 2.0)
        self.ciContext = CIContext(
            options: [
//                CIContextOption.allowLowPower: false,
                CIContextOption.cacheIntermediates: false,
                CIContextOption.highQualityDownsample: true,
                CIContextOption.useSoftwareRenderer: false,
//                CIContextOption.outputColorSpace: CGColorSpaceCreateDeviceGray(),
//                CIContextOption.workingColorSpace: CGColorSpaceCreateDeviceGray(),
                CIContextOption.outputColorSpace: NSNull(),
                CIContextOption.workingColorSpace: NSNull(),
            ]
        )
        data.assign(repeating: -1)
        oldData.assign(repeating: 0)
        reset()
    }
    
    deinit {
        data.deallocate()
        oldData.deallocate()
    }
    
    func reset() {
        let oldData = self.data
        let newData = self.oldData
        self.oldData = oldData
        self.data = newData
        self.data.assign(repeating: -1)
    }
    
    func addField(_ field: Field) {
        for i in 0 ..< field.count {
            let b = field[i]
            let t = field.transform
            addBlob(b, transform: t)
        }
    }
    
    func addBlob(_ blob: Blob, transform: simd_float4x4) {
        #warning("TODO: Disambiguate between objects below the ceiling and objects that extend to the ceiling")
        let p = transform * blob.center
        precondition(p.w != 0)
        let h = (p.y / p.w) - space.elevationMin
        guard h >= 0 && h < roofThreshold else {
            return
        }
        let w = WorldCoordinate(x: p.x / p.w, y: p.z / p.w)
        let m = space.toMap(w)
        let r = space.toMap(blob.radius)

        let cost = h / roofThreshold
        addCircle(
            at: m,
            radius: r,
            cost: cost
        )
    }
    
    func addCircle(at origin: MapCoordinate, radius: Int, cost: Float) {
        let c = origin
        let r = radius + 1
        
        // Don't draw the circle if the radius is too small
        guard r > 0 else {
            return
        }

        // Draw a single pixel if the radius is 1
        guard r > 1 else {
            setCost(cost, at: MapCoordinate(x: c.x, y: c.y))
            return
        }

        // Don't draw the circle if it is outside the map
        if
            c.x - r >= dimensions.x
        ||
            c.x + r < 0
        ||
            c.y - r >= dimensions.y
        ||
            c.y + r < 0
        {
            return
        }

        var d = 3 - (2 * r)
        var y = r
        for x in 0 ..< r {
            draw(c.x - x, c.x + x, c.y + y, c.y - y, cost)
            draw(c.x - y, c.x + y, c.y + x, c.y - x, cost)
            if d <= 0 {
                d += (4 * x) + 6
            }
            else {
                y -= 1
                d += (4 * (x - y)) + 10
            }
        }
    }
    
    private func draw(_ ax: Int, _ bx: Int, _ ay: Int, _ by: Int, _ cost: Float) {
        let ux = min(max(ax, 0), dimensions.x)
        let vx = min(max(bx, 0), dimensions.x)
        let dx = vx - ux
        if ay >= 0 && ay < dimensions.y {
            setRangeUnsafe(cost, x: ux, y: ay, length: dx)
        }
        if by >= 0 && by < dimensions.y {
            setRangeUnsafe(cost, x: ux, y: by, length: dx)
        }
    }
    
    func setCostUnsafe(_ cost: Float, x: Int, y: Int) {
        let i = indexUnsafe(x: x, y: y)
        data[i] = max(data[i], cost)
    }
    
    func setRangeUnsafe(_ cost: Float, x: Int, y: Int, length: Int) {
        let i = indexUnsafe(x: x, y: y)
        for j in 0 ..< length {
            let k = i + j
            data[k] = max(data[k], cost)
        }
    }

    func setCost(_ cost: Float, x: Int, y: Int) {
        setCost(cost, at: MapCoordinate(x: x, y: y))
    }

    func setCost(_ cost: Float, at coordinate: MapCoordinate) {
        guard let i = index(at: coordinate) else {
            return
        }
        data[i] = max(data[i], cost)
    }

    func getCost(at coordinate: MapCoordinate) -> Float? {
        guard let i = index(at: coordinate) else {
            return nil
        }
        return data[i]
    }

    func build(floorLocation: MapCoordinate) -> Map {

        saveState()
        let floorHeight = getCost(at: floorLocation) ?? 0
        applyFloorThreshold(floorHeight)
        
//        blend()
        
        let elementSize = MemoryLayout<Float>.size
        
        // Create the map

        let inputCIImage = CIImage(
            bitmapData: Data(
                bytesNoCopy: data.baseAddress!,
                count: data.count * elementSize,
                deallocator: .none
            ),
            bytesPerRow: dimensions.x * elementSize,
            size: CGSize(
                width: dimensions.x,
                height: dimensions.y
            ),
            format: .Lf,
            colorSpace: nil
        )
        let bounds = inputCIImage.extent

//        let blurredCIImage = inputCIImage
//            .clampedToExtent()
//            .applyingGaussianBlur(
//                sigma: Double(space.toMap(margin))
//            )
//            .cropped(to: bounds)
        
//        let filter = CIFilter.morphologyMaximum()
        
        let minFilter = CIFilter.morphologyMinimum()
//        filter.radius = space.toMapLength(margin)
        minFilter.radius = 3.0
        minFilter.inputImage = inputCIImage.clampedToExtent()
        let dilatedCIImage = minFilter.outputImage!

//        let blurredCIImage = dilatedCIImage.applyingGaussianBlur(sigma: 4.0)
        
        let blurFilter = CIFilter.gaussianBlur()
        blurFilter.inputImage = dilatedCIImage
        blurFilter.radius = 6.0
        let blurredCIImage = blurFilter.outputImage!

        let thresholdFilter = CIFilter.minimumCompositing()
        thresholdFilter.backgroundImage = blurredCIImage.cropped(to: bounds)
        thresholdFilter.inputImage = dilatedCIImage.cropped(to: bounds)
//
        let outputCIImage = thresholdFilter.outputImage!
//        let outputCIImage = dilatedCIImage

//        let minFilter = CIFilter.minimumCompositing()
//        minFilter.backgroundImage = blurredCIImage
//        minFilter.inputImage = inputCIImage
        
//        let outputCIImage = minFilter.outputImage!

        let outputCGImage = ciContext.createCGImage(
            outputCIImage,
            from: bounds,
            format: .Lf,
            colorSpace: CGColorSpaceCreateDeviceGray()
        )!
        let imageData = outputCGImage.dataProvider!.data!
        let imagePointer = CFDataGetBytePtr(imageData)!

        let bytes = outputCGImage.bytesPerRow * outputCGImage.height
        let length = bytes / elementSize
        let buffer = mapBufferPool.allocate(count: length)
        let rawImagePointer = UnsafeRawPointer(imagePointer).bindMemory(to: Float.self, capacity: length)
        for y in 0 ..< outputCGImage.height {
            let i = y * outputCGImage.width
            for x in 0 ..< outputCGImage.width {
                let p = rawImagePointer[i + x]
                buffer.pointer[i + x] = p
            }
        }

        return Map(
            dimensions: dimensions,
            space: space,
            data: buffer
        )
    }
    
    private func saveState() {
        for i in 0 ..< data.count {
            oldData[i] = data[i]
        }
    }
    
    private func applyFloorThreshold(_ floor: Float) {
        for i in 0 ..< data.count {
            let c: Float
            if data[i] >= 1 || data[i] < 0 {
                c = 0.0
            }
            else {
                let h = abs(data[i] - floor)
                c = (h > floorVariance) ? 0.0 : 1.0
            }
            data[i] = c
        }
    }
    
    /// Blend new map with the old one
    private func blend() {
        let t = mapFade
        let s = 1.0 - t

        for i in 0 ..< data.count {
            let a = oldData[i]
            let b = data[i]
            if b < a {
                let c = (a * s) + (b * t)
                data[i] = c
            }
        }
    }
    
    private func index(at coordinate: MapCoordinate) -> Int? {
        guard coordinate.x >= 0, coordinate.x < dimensions.x, coordinate.y >= 0, coordinate.y < dimensions.y else {
            return nil
        }
        return indexUnsafe(x: coordinate.x, y: coordinate.y)
    }
    
    private func indexUnsafe(x: Int, y: Int) -> Int {
        return (y * dimensions.x) + x
    }
}

extension MapBuilder {
    func cgImage() -> CGImage? {
        let bytesPerComponent = MemoryLayout<Float>.size
        let bytesPerRow = dimensions.x * bytesPerComponent
        let bytes = bytesPerRow * dimensions.y
        let rawPointer = UnsafeRawPointer(oldData.baseAddress!)
        let pointer = rawPointer.bindMemory(to: UInt8.self, capacity: bytes)
//        let data = CFDataCreateWithBytesNoCopy(nil, pointer, bytes , nil)!
        let data = CFDataCreate(nil, pointer, bytes)!
        let dataProvider = CGDataProvider(data: data)!
        let bitmapInfo: CGBitmapInfo = [.byteOrder32Little, .floatComponents]
        let outputImage = CGImage(
            width: dimensions.x,
            height: dimensions.y,
            bitsPerComponent: bytesPerComponent * 8,
            bitsPerPixel: bytesPerComponent * 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: bitmapInfo,
            provider: dataProvider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )!
        return outputImage
    }
}
