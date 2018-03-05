//
//  CharacteristicViewController.swift
//  ReadCharacteristic
//
//  Created by Created by Created by HengJay on 2017/12/04.
//  Copyright © 2017 ITRI All rights reserved.
//

import UIKit
import CoreBluetooth
import Foundation
/*
extension FileManager {
    static var documentDirectoryURL: URL {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
}*/

/**
 This view talks to a Characteristic
 */
class CharacteristicViewController: UIViewController, CBCentralManagerDelegate, BlePeripheralDelegate {
    
    // MARK: UI elements
    @IBOutlet weak var advertizedNameLabel: UILabel!
    @IBOutlet weak var identifierLabel: UILabel!
    @IBOutlet weak var characteristicUuidlabel: UILabel!
    
    @IBOutlet weak var waveformArea: WaveformView!
    @IBOutlet weak var signal1Value: UILabel!
    @IBOutlet weak var signal2Value: UILabel!
    @IBOutlet weak var writeCharacteristicButton: UIButton!
    @IBOutlet weak var writeCharacteristicTextField: UITextField!
    
    
    // MARK: Connected devices
    
    // Central Bluetooth Radio
    var centralManager: CBCentralManager!
    
    // Bluetooth Peripheral
    var blePeripheral: BlePeripheral!
    
    // Connected Characteristic
    var connectedService: CBService!
    
    // Connected Characteristic
    var connectedCharacteristic: CBCharacteristic!
    
    // Received Data Buffer
    var receivedData = [UInt8]()
    
    // URL for save the received Data
    /*
    let receivedDataURL = URL(
        fileURLWithPath: "receivedData",
        relativeTo: FileManager.documentDirectoryURL
    )*/
    
    /**
     UIView loaded
     */
    override func viewDidLoad() {
        super.viewDidLoad()
        
        print("Will connect to device \(blePeripheral.peripheral.identifier.uuidString)")
        print("Will connect to characteristic \(connectedCharacteristic.uuid.uuidString)")
        
        centralManager.delegate = self
        blePeripheral.delegate = self
        
        loadUI()
        
    }
    
    @IBAction func notifyCharacteristic(_ sender: UISwitch) {
        print("notify the characteristic is \(sender.isOn)")
        blePeripheral.peripheral.setNotifyValue(sender.isOn, for: connectedCharacteristic)
        
    }
    /**
     Load UI elements
     */
    func loadUI() {
        advertizedNameLabel.text = blePeripheral.advertisedName
        identifierLabel.text = blePeripheral.peripheral.identifier.uuidString
        characteristicUuidlabel.text = connectedCharacteristic.uuid.uuidString
        
        // characteristic is not writeable
        if !BlePeripheral.isCharacteristic(isWriteable: connectedCharacteristic) {
            writeCharacteristicTextField.isHidden = true
            writeCharacteristicButton.isHidden = true
        }
        
    }

    let header : UInt32 = 0x49545249
    let cmdType : [UInt16] = [0xAB01, 0xAB02, 0xAB03, 0xAB04, 0xAB05, 0xAB06, 0xAB07]
    var cmdData : [Bool] = [false, false, false, false, false, false, false]
    let comment = "FFFFFFFF"
    var lastPressBtn : Int = 0
    
    @IBAction func writeCharacteristic(_ sender: UIButton) {
        print("write button pressed")
        writeCharacteristicButton.isEnabled = false
       
        let stringValue = generateCommandString()
        print("stringValue is \(stringValue)")
        blePeripheral.writeValue(value: stringValue, to: connectedCharacteristic)
        writeCharacteristicTextField.text = ""
        
        writeCharacteristicButton.isEnabled = true
    }
    
    // Generate the command string by bigEndian.
    func generateCommandString() -> String {
        let cmdDataValue = cmdData[lastPressBtn] ? UInt16(0x0002) : UInt16(0x0001)
        
        let Header = String(header.bigEndian, radix: 16)
        print("Header is \(Header) length is \(Header.count)")
        
        let CMDType = "0" + String(cmdType[lastPressBtn].bigEndian, radix: 16) // Add missing "0"
        print("CMDType is \(CMDType) length is \(CMDType.count)")
        
        let CMDDataValue = "0" + String(cmdDataValue.bigEndian, radix: 16) // Add missing "0"
        print("CMDDataValue is \(CMDDataValue) length is \(CMDDataValue.count)")
        
        let Comment = String(repeating:comment, count: 6)
        print("Comment is \(Comment) length is \(Comment.count)")
        
        let commandStr = Header + CMDType + CMDDataValue + Comment
        
        return commandStr
    }
        
    @IBAction func writeTestText(_ sender: UIButton) {
        
        let cmdDataValue = cmdData[sender.tag] ? "0002" : "0001"
        
        writeCharacteristicTextField.text = String(header, radix: 16) +
            String(cmdType[sender.tag], radix: 16) + cmdDataValue + String(repeating:comment, count: 6)
        
        cmdData[sender.tag] = !cmdData[sender.tag]
        cmdData[5] = false
        cmdData[6] = false
        lastPressBtn = sender.tag
    }
    // MARK: BlePeripheralDelegate
    
    /**
     Characteristic was read.  Update UI
     */
    func blePeripheral(characteristicRead byteArray: [UInt8], characteristic: CBCharacteristic, blePeripheral: BlePeripheral) {
    
        receivedData += byteArray
        
        for i in 1...(byteArray.count/4) {
            // Update the signal value of channel 1
            let ch1Value = Int16(byteArray[i*4-3]) << 8 + Int16(byteArray[i*4-4])
            waveformArea.pushSignal1BySliding(newValue: CGFloat(ch1Value))
            signal1Value.text = String(ch1Value)
            // Update the signal value of channel 2
            let ch2Value = Int16(byteArray[i*4-1]) << 8 + Int16(byteArray[i*4-2])
            waveformArea.pushSignal2BySliding(newValue: CGFloat(ch2Value))
            signal2Value.text = String(ch2Value)
        }
    }

    
    
    // MARK: CBCentralManagerDelegate
    
    /**
     Peripheral disconnected
     
     - Parameters:
     - central: the reference to the central
     - peripheral: the connected Peripheral
     */
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        // disconnected.  Leave
        print("disconnected")
        if let navController = navigationController {
            navController.popToRootViewController(animated: true)
            dismiss(animated: true, completion: nil)
        }
        
    }
    
    
    /**
     Bluetooth radio state changed
     
     - Parameters:
     - central: the reference to the central
     */
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        print("Central Manager updated: checking state")
        
        switch (central.state) {
        case .poweredOn:
            print("bluetooth on")
        default:
            print("bluetooth unavailable")
        }
    }
    

    
    
    // MARK: - Navigation
    
    /**
     Animate the segue
     */
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
        if let connectedBlePeripheral = blePeripheral {
            centralManager.cancelPeripheralConnection(connectedBlePeripheral.peripheral)
        }
    }
    

}
