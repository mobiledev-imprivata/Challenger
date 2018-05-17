//
//  ChunkUtils.swift
//  Challenger
//
//  Created by Jay Tucker on 5/17/18.
//  Copyright © 2018 Imprivata. All rights reserved.
//

import Foundation

enum ChunkFlag: UInt8, CustomStringConvertible {
    case first  = 1
    case middle = 0
    case last   = 2
    case only   = 3
    
    var description: String {
        switch self {
        case .first:  return "F"
        case .middle: return "M"
        case .last:   return "L"
        case .only:   return "O"
        }
    }
}

final class Chunker {
    class func makeChunks(_ bytes: [UInt8], chunkSize: Int) -> Array< Array<UInt8> > {
        var chunkSize = chunkSize
        if chunkSize < 1 || chunkSize > 0x1fff {
            chunkSize = 0x1fff
        }
        var chunks = Array<Array<UInt8>>()
        let totalSize = bytes.count
        var begIdx = 0
        while begIdx < totalSize {
            let nextBegIdx = begIdx + chunkSize
            let endIdx = min(nextBegIdx, totalSize)
            var flag: ChunkFlag
            if chunks.isEmpty {
                if nextBegIdx < totalSize {
                    flag = ChunkFlag.first
                } else {
                    flag = ChunkFlag.only
                }
            } else {
                if nextBegIdx < totalSize {
                    flag = ChunkFlag.middle
                } else {
                    flag = ChunkFlag.last
                }
            }
            let chunkDataBytes = Array<UInt8>(bytes[begIdx..<endIdx])
            let length = chunkDataBytes.count
            let header: [UInt8]
            var byte0 = flag.rawValue << 6
            if length <= 0x1f {
                byte0 += UInt8(length)
                header = [byte0]
            } else {
                byte0 |= 0x20
                byte0 += UInt8(length >> 8)
                let byte1 = UInt8(length & 0xff)
                header = [byte0, byte1]
            }
            chunks.append(header + chunkDataBytes)
            begIdx = nextBegIdx
        }
        return chunks
    }
}

final class Dechunker {
    fileprivate var buffer: [UInt8]
    fileprivate var nChunksAdded: Int
    fileprivate var startTime = Date()
    
    init() {
        buffer = [UInt8]()
        nChunksAdded = 0
    }
    
    func addChunk(_ bytes: [UInt8]) -> (isSuccess: Bool, finalResult: [UInt8]?) {
        log("dechunker attempting to add chunk of \(bytes.count) bytes")
        
        if bytes.isEmpty {
            log("dechunker failed: too few bytes")
            return (false, nil)
        }
        
        let flagRawValue = bytes[0] >> 6
        let flag = ChunkFlag(rawValue: flagRawValue)!
        let length: Int
        let data: [UInt8]
        if bytes[0] & 0x20 == 0 {
            length = Int(bytes[0] & 0x1f)
            data = Array<UInt8>(bytes[1..<bytes.count])
        } else {
            if bytes.count < 2 {
                log("dechunker failed: too few bytes")
                return (false, nil)
            }
            length = (Int(bytes[0] & 0x1f) << 8) + Int(bytes[1])
            data = Array<UInt8>(bytes[2..<bytes.count])
        }
        
        if length != data.count {
            log("dechunker failed: bad length")
            return (false, nil)
        }
        
        switch flag {
        case .first, .only:
            startTime = Date()
            buffer = data
            nChunksAdded = 1
            log("dechunker created buffer with \(data.count) bytes (\(flag))")
        case .middle, .last:
            let oldCount = buffer.count
            buffer += data
            nChunksAdded += 1
            log("dechunker enlarged buffer to \(data.count)+\(oldCount)=\(buffer.count) bytes (\(nChunksAdded) chunks) (\(flag))")
        }
        
        switch flag {
        case .last, .only:
            let timeInterval = startTime.timeIntervalSinceNow
            log("dechunker complete, \(nChunksAdded) chunk(s), \(buffer.count) bytes, \(-timeInterval) secs")
            return (true, buffer)
        case .first, .middle:
            return (true, nil)
        }
    }
    
}
