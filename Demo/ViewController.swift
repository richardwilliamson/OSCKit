//
//  ViewController.swift
//  Demo
//
//  Created by Sam Smallman on 29/10/2017.
//  Copyright © 2017 artificeindustries. All rights reserved.
//

import Cocoa
import OSCKit


class ViewController: NSViewController, ClientDelegate {
    
    //    let server = Server()
    //    let parser = Parser()
    @IBOutlet var textView: NSTextView!
    
    let client = Client()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        interfacse()
        
        //        server.port = 24601
        //        server.delegate = parser
        //        do {
        //            try server.startListening()
        //        } catch let error as NSError {
        //            print(error.localizedDescription)
        //        }
    }
    
    override func viewDidAppear() {
//        client.interface = "192.168.1.102"
        client.host = "172.16.6.62"
        client.port = 24601
        client.useTCP = false
        client.delegate = self
//        do {
//            try client.connect()
//            print("Connecting")
//        } catch let error as NSError {
//            print(error.localizedDescription)
//        }
        let data = Data(bytes: [0x00, 0x01, 0x02, 0x03])
        let message = OSCMessage(messageWithAddressPattern: "/hey", arguments: ["Jerry",2147483647,-2,3,3.142,-246.81,"Tom",data])
        client.sendPacket(with: message)
        textView.string += "\n*** Sending OSC Message ***\n"
        textView.string += "Address Pattern: /hey\n"
        textView.string += "Arguments: something\n"
    }
    
    deinit {
        client.disconnect()
    }
    
    override var representedObject: Any? {
        didSet {
            // Update the view, if already loaded.
        }
    }
    
    func clientDidConnect(client: Client) {
        print("CLient Did Connect")
    }
    
    func clientDidDisconnect(client: Client) {
        print("Client did Disconnect")
    }
    
    func interfacse() {
        for interface in Interface.allInterfaces() where !interface.isLoopback && interface.family == .ipv4 && interface.isRunning {
            textView.string += "\n*** Network Interface ***\n"
            textView.string += "Display Name: \(interface.displayName)\n"
            textView.string += "Name: \(interface.name)\n"
            textView.string += "IP Address: \(interface.address ?? "")\n"
            textView.string += "Subnet Mask: \(interface.netmask ?? "")\n"
            textView.string += "Broadcast Address: \(interface.broadcastAddress ?? "")\n"
            textView.string += "Display Text: \(interface.displayText)\n"
        }
    }
    
    
}


