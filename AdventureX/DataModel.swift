//
//  DataModel.swift
//  AdventureX
//
//  Created by GH on 7/16/24.
//

import simd
import Foundation
import Observation

struct Frame: Equatable, Identifiable {
    let id = UUID()
    let positions: [SIMD3<Float>] // 3D 浮点数向量
    
    static func ==(lhs: Frame, rhs: Frame) -> Bool {
        return lhs.id == rhs.id
    }
}

@Observable
class PositionData {
    static let shared = PositionData(frameCount: 10)
    
    private(set) var frames: [Frame] = []
    private var ringBuffer: RingBuffer<Frame>
    private var updateQueue = DispatchQueue(label: "PositionDataUpdateQueue")
    
    private init(frameCount: Int) {
        ringBuffer = RingBuffer(size: frameCount)
    }
    
    func generatePoints(from json: [String: Any]) {
        updateQueue.async {
            guard let pointCloud = json["pointCloud"] as? [[Double]] else {
                print("Invalid JSON format")
                return
            }
            
            let positions: [SIMD3<Float>] = pointCloud.compactMap {
                guard $0.count >= 3 else { return nil }
                return SIMD3<Float>(
                    Float($0[0]),
                    Float($0[1]),
                    Float($0[2])
                )
            }
            
            let frame = Frame(positions: positions)
            self.ringBuffer.write(frame)
            
            let frames = self.ringBuffer.read()
            DispatchQueue.main.async {
                self.frames = frames
                self.removeOldestFrame()
                print("Generated frame with \(frame.positions.count) positions")
            }
        }
    }
    
    private func removeOldestFrame() {
        if frames.count > 10 {
            frames.removeFirst(frames.count - 10)
        }
    }
    
    func clearFrames() {
        updateQueue.async {
            self.ringBuffer = RingBuffer(size: self.ringBuffer.size)
            DispatchQueue.main.async {
                self.frames.removeAll()
            }
        }
    }
}

class RingBuffer<T> {
    private var buffer: [T?]
    private var readIndex = 0
    private var writeIndex = 0
    let size: Int // 缓冲区大小
    private var count = 0
    
    init(size: Int) {
        self.size = size
        self.buffer = [T?](repeating: nil, count: size)
    }
    
    func write(_ element: T) {
        buffer[writeIndex] = element
        writeIndex = (writeIndex + 1) % size
        if count < size {
            count += 1
        } else {
            readIndex = (readIndex + 1) % size
        }
    }
    
    func read() -> [T] {
        var result = [T]()
        for i in 0..<count {
            let index = (readIndex + i) % size
            if let element = buffer[index] {
                result.append(element)
            }
        }
        return result
    }
    
    func latest() -> T? {
        return buffer[(writeIndex + size - 1) % size]
    }
}


//{
//    "error": 0,
//    "frameNum": 378,
//    "pointCloud": [
//        [
//            6.587018726512154,
//            3.485026624592355,
//            1.0662452587170637,
//            0.0,
//            24.0,
//            38.6,
//            255.0
//        ],
//        [
//            6.710140673460906,
//            3.606407398236248,
//            0.881641003247777,
//            -0.1471865475177765,
//            20.6,
//            39.0,
//            255.0
//        ]
//    ],
//    "numDetectedPoints": 12
//}
