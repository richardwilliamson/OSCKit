//
//  OSCMessage.swift
//  OSCKit
//
//  Created by Sam Smallman on 29/10/2017.
//  Copyright © 2017 Artifice Industries Ltd. http://artificers.co.uk
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

public class OSCMessage {
    
    public var addressPattern: String = "/"
    public var addressParts: [String] { // Address pattern are components seperated by "/"
        get {
            var parts = self.addressPattern.components(separatedBy: "/")
            parts.removeFirst()
            return parts
        }
    }
    public var arguments: [Any] = []
    public var typeTagString: String = ","
    public var replySocket: Socket?
    
    
    init(messageWithAddressPattern addressPattern: String, arguments: [Any]) {
        message(with: addressPattern, arguments: arguments, replySocket: nil)
    }
    
    init(messageWithAddressPattern addressPattern: String, arguments: [Any], replySocket: Socket?) {
        message(with: addressPattern, arguments: arguments, replySocket: replySocket)
    }
    
    private func message(with addressPattern: String, arguments: [Any], replySocket: Socket?) {
        set(addressPattern: addressPattern)
        set(arguments: arguments)
        self.replySocket = replySocket
    }
    
    private func set(addressPattern: String) {
        if addressPattern.isEmpty || addressPattern.count == 0 || addressPattern.first != "/" {
            self.addressPattern = "/"
        } else {
            self.addressPattern = addressPattern
        }
    }
    
    private func set(arguments: [Any]) {
        var newArguments: [Any] = []
        var newTypeTagString: String = ","
        for argument in arguments {
            if argument is String {
                newTypeTagString.append("s")
                newArguments.append(argument)
            } else if argument is Data {
                newTypeTagString.append("b")
                newArguments.append(argument)
            } else if argument is Int32 {
                newTypeTagString.append("i")
                newArguments.append(argument)
            } else if argument is Float32 {
                newTypeTagString.append("f")
                newArguments.append(argument)
            }
        }
        self.arguments = newArguments
        self.typeTagString = newTypeTagString
    }
    
}

extension String {
    func oscStringData()->Data {
        return Data()
    }
}
