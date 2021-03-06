//
//  OSCParser.swift
//  OSCKit
//
//  Created by Sam Smallman on 29/10/2017.
//  Copyright © 2017 Sam Smallman. http://sammy.io
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

import Foundation

// MARK: Parser

public class OSCParser {
    
    private enum slipCharacter: Int {
        case END = 0o0300       /* indicates end of packet */
        case ESC = 0o0333       /* indicates byte stuffing */
        case ESC_END = 0o0334   /* ESC ESC_END means END data byte */
        case ESC_ESC = 0o0335   /* ESC ESC_ESC means ESC data byte */
    }
    
    public enum streamFraming {
        case SLIP
        case PLH
    }
    
    public func process(OSCDate data: Data, for destination: OSCPacketDestination, with replySocket: Socket) {
        if !data.isEmpty {
            let firstCharacter = data.prefix(upTo: 1)
            guard let string = String(data: firstCharacter, encoding: .utf8) else { return }
            if string == "/" { // OSC Messages begin with /
                process(OSCMessageData: data, for: destination, with: replySocket)
            } else if string == "#" { // OSC Bundles begin with #
                process(OSCBundleData: data, for: destination, with: replySocket)
            } else {
                debugPrint("Error: Unrecognized data \(data)")
            }
        }
    }
    
    private func process(OSCMessageData data: Data, for destination: OSCPacketDestination, with replySocket: Socket) {
        var startIndex = 0
        guard let message = parseOSCMessage(with: data, startIndex: &startIndex) else {
            debugPrint("Error: Unable to parse OSC Message Data")
            return
        }
        message.replySocket = replySocket
        destination.take(message: message)
    }
    
    private func process(OSCBundleData data: Data, for destination: OSCPacketDestination, with replySocket: Socket) {
        guard let  bundle = parseOSCBundle(with: data) else {
            debugPrint("Unable to parse OSC Bundle Data")
            return
        }
        bundle.replySocket = replySocket
        destination.take(bundle: bundle)
    }
    
    public func translate(OSCData tcpData: Data, streamFraming: streamFraming, to data: NSMutableData, with state: NSMutableDictionary, andDestination destination: OSCPacketDestination) {
        // There are two versions of OSC. OSC 1.1 frames messages using the SLIP protocol: http://www.rfc-editor.org/rfc/rfc1055.txt
        if streamFraming == .SLIP {
            guard let socket = state.object(forKey: "socket") as? Socket else {
                print("Error: Unable to parse SLIP data without a socket.")
                return
            }
            guard var dangling_ESC = state.object(forKey: "dangling_ESC") as? Bool else {
                print("Error: Unable to confirm dangling_ESC value")
                return
            }
            
            let end = UInt8(slipCharacter.END.rawValue)
            let esc = UInt8(slipCharacter.ESC.rawValue)
            
            let length = tcpData.count
            let buffer = tcpData
            for (index, byte) in buffer.enumerated() {
                if dangling_ESC {
//                    dangling_ESC = false
                    state.setValue(false, forKey: "dangling_ESC")
                    if byte == UInt8(slipCharacter.ESC_END.rawValue) {
                        data.append(Data(bytes: [end]))
                    } else if byte == UInt8(slipCharacter.ESC_ESC.rawValue) {
                        data.append(Data(bytes: [esc]))
                    } else {
                        // Protocol violation. Pass the byte along and hope for the best.
                        print("Error: Protocol violation. Pass the byte along and hope for the best.")
                        data.append(Data(bytes: [buffer[index]]))
                    }
                } else if byte == end {
                    // The data is now a complete message.
                    let newData = data as Data
                    process(OSCDate: newData, for: destination, with: socket)
                    data.setData(Data())
                } else if byte == esc {
                    if index + 1 < length {
                        if buffer[index + 1] == UInt8(slipCharacter.ESC_END.rawValue) {
                            data.append(Data(bytes: [end]))
                        } else if buffer[index + 1] == UInt8(slipCharacter.ESC_ESC.rawValue) {
                            data.append(Data(bytes: [esc]))
                        } else {
                            // Protocol violation. Pass the byte along and hope for the best.
                            print("Error: Protocol violation. Pass the byte along and hope for the best.")
                            data.append(Data(bytes: [buffer[index + 1]]))
                        }
                    } else {
                        // The incoming raw data stopped in the middle of an escape sequence.
                        print("Error: Incoming raw data stopped in the middle of an escape sequence.")
                        state.setValue(true, forKey: "dangling_ESC")
                    }
                } else {
                    data.append(Data(bytes: [buffer[index]]))
                }
            }
        }
    }
    
    private func parseOSCMessage(with data: Data, startIndex firstIndex: inout Int)->OSCMessage? {
        guard let addressPattern = oscString(with: data, startIndex: &firstIndex) else {
            print("Error: Unable to parse OSC Address Pattern.")
            return nil
        }
        guard let typeTagString = oscString(with: data, startIndex: &firstIndex) else {
            print("Error: Unable to parse Type Tag String.")
            return nil
        }
        // If the Type Tag String starts with "," and has 1 or more characters after, we possibly have some arguments.
        var arguments: [Any] = []
        if typeTagString.first == "," && typeTagString.count > 1 {
            // Remove "," as we will iterate over the different type of tags.
            var typeTags = typeTagString
            typeTags.removeFirst()
            for tag in typeTags {
                switch tag {
                case "s":
                    guard let stringArgument = oscString(with: data, startIndex: &firstIndex) else {
                        print("Error: Unable to parse String Argument.")
                        return nil
                    }
                    arguments.append(stringArgument)
                case "i":
                    guard let intArgument = oscInt(with: data, startIndex: &firstIndex) else {
                        print("Error: Unable to parse Int Argument.")
                        return nil
                    }
                    arguments.append(intArgument)
                case "f":
                    guard let floatArgument = oscFloat(with: data, startIndex: &firstIndex) else {
                        print("Error: Unable to parse Float Argument.")
                        return nil
                    }
                    arguments.append(floatArgument)
                case "b":
                    guard let blobArgument = oscBlob(with: data, startIndex: &firstIndex) else {
                        print("Error: Unable to parse Blob Argument.")
                        return nil
                    }
                    arguments.append(blobArgument)
                case "t":
                    guard let timeTagArgument = oscTimeTag(withData: data, startIndex: &firstIndex) else {
                        print("Error: Unable to parse Time Tag Argument.")
                        return nil
                    }
                    arguments.append(timeTagArgument)
                default:
                    continue
                }
            }
        }
        return OSCMessage(messageWithAddressPattern: addressPattern, arguments: arguments)
    }
    
    private func parseOSCBundle(with data: Data)->OSCBundle? {
        // Check the Bundle has a string prefix of "#bundle#
        if "#bundle".oscStringData() == data.subdata(in: Range(0...7)) {
            var startIndex = 8
            // All Bundles have a Time Tag, even if its just immedietly - Seconds 0, Fractions 1.
            guard let timeTag = oscTimeTag(withData: data, startIndex: &startIndex) else {
                debugPrint("Error: Unable to parse Parent OSC Bundle time tag.")
                return nil
            }
            // Does the Bundle have any data in it? Bundles could be empty with no messages or bundles within.
            if startIndex < data.endIndex {
                let bundleData = data.subdata(in: Range(startIndex..<data.endIndex))
                let size = Int32(data.count - startIndex)
                let elements = parseOSCBundleElements(with: 0, data: bundleData, andSize: size)
                return OSCBundle(bundleWithElements: elements, timeTag: timeTag)
            } else {
                return OSCBundle(bundleWithElements: [], timeTag: timeTag)
            }
        } else {
            debugPrint("Error: Unable to parse Parent OSC Bundle: \(data).")
            return nil
        }
    }
    
    func parseOSCBundleElements(with index: Int, data: Data, andSize size: Int32)->[OSCPacket] {
        var elements: [OSCPacket] = []
        var startIndex = 0
        var buffer: Int32 = 0
        repeat {
            print("Start Index: \(startIndex), Start Buffer: \(buffer), Size: \(size)")
            guard let elementSize = oscInt(with: data, startIndex: &startIndex) else {
                debugPrint("Error: Unable to parse size of next element.")
                return elements
            }
            buffer += 4
            guard let string = String(data: data.subdata(in: Range(startIndex..<data.endIndex)).prefix(upTo: 1), encoding: .utf8) else {
                debugPrint("Error: Unable to parse embedded elements.")
                return elements
            }
            if string == "/" { // OSC Messages begin with /
                guard let newElement = parseOSCMessage(with: data, startIndex: &startIndex) else {
                    debugPrint("Error: Unable to parse embedded OSC message.")
                    return elements
                }
                elements.append(newElement)
            } else if string == "#" { // OSC Bundles begin with #
                // #bundle takes up 8 bytes
                startIndex += 8
                // All Bundles have a Time Tag, even if its just immedietly - Seconds 0, Fractions 1.
                guard let timeTag = oscTimeTag(withData: data, startIndex: &startIndex) else {
                    debugPrint("Error: Unable to parse Parent OSC Bundle time tag.")
                    return elements
                }
                if startIndex < size {
                    print("Bundle -  Start Index: \(startIndex), Element Size: \(elementSize), End Index \(data.endIndex)")
                    let bundleData = data.subdata(in: Range(startIndex..<startIndex + Int(elementSize) - 16))
                    let bundleElements = parseOSCBundleElements(with: index, data: bundleData, andSize: Int32(bundleData.count))
                    elements.append(OSCBundle(bundleWithElements: bundleElements, timeTag: timeTag))
                } else {
                    elements.append(OSCBundle(bundleWithElements: [], timeTag: timeTag))
                }
            } else {
                debugPrint("Error: Unrecognized data \(data)")
            }
            buffer += elementSize
            print("Start Index: \(startIndex), End Buffer: \(buffer), Size: \(size)")
            startIndex = index + Int(buffer)
        } while buffer < size
        
        return elements
    }
    
    // TODO: for in loops copy on write. It would be more efficient to move along the data, one index at a time.
    private func oscString(with buffer: Data, startIndex firstIndex: inout Int) -> String? {
        // Read the data from the start index until you hit a zero, the part before will be the string data.
        for (index, byte) in buffer[firstIndex...].enumerated() where byte == 0 {
            guard let result = String(data: buffer[firstIndex...(firstIndex + index)], encoding: .utf8) else { return nil }
            /* An OSC String is a sequence of non-null ASCII characters followed by a null, followed by 0-3 additional null characters to make the total number of bits a multiple of 32 Bits, 4 Bytes.
             */
            firstIndex = (4 * Int(ceil(Double(firstIndex + index + 1) / 4)))
            return result
        }
        return nil
    }
    
    private func oscInt(with buffer: Data, startIndex firstIndex: inout Int) -> Int32? {
        // An OSC Int is a 32-bit big-endian two's complement integer.
        let result = buffer.subdata(in: firstIndex..<firstIndex + 4).withUnsafeBytes { (pointer: UnsafePointer<Int32>) -> Int32 in
            return pointer.pointee.bigEndian
        }
        firstIndex += 4
        return result
    }
    
    private func oscFloat(with buffer: Data, startIndex firstIndex: inout Int) -> Float32? {
        // An OSC Float is a 32-bit big-endian IEEE 754 floating point number.
        let result = buffer.subdata(in: firstIndex..<firstIndex + 4).withUnsafeBytes { (pointer: UnsafePointer<CFSwappedFloat32>) -> Float32 in
            return CFConvertFloat32SwappedToHost(pointer.pointee)
        }
        firstIndex += 4
        return result
    }
    
    private func oscBlob(with buffer: Data, startIndex firstIndex: inout Int) -> Data? {
        /* An int32 size count, followed by that many 8-bit bytes of arbitrary binary data, followed by 0-3 additional zero bytes to make the total number of bits a multiple of 32, 4 bytes
         */
        let blobSize = buffer.subdata(in: firstIndex..<firstIndex + 4).withUnsafeBytes { (pointer: UnsafePointer<Int32>) -> Int32 in
            return pointer.pointee.bigEndian
        }
        firstIndex += 4
        let result = buffer.subdata(in: firstIndex..<(firstIndex + Int(blobSize)))
        return result
    }
    
    private func oscTimeTag(withData data: Data, startIndex firstIndex: inout Int)-> OSCTimeTag? {
        let oscTimeTagData = data[firstIndex..<firstIndex + 8]
        firstIndex += 8
        return OSCTimeTag(withData: oscTimeTagData)
    }
    
}
