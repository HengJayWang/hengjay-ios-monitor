//
//  ViewController.swift
//  Bootstrapping
//
//  Created by Created by HengJay on 2017/12/04.
//  Copyright © 2017 ITRI All rights reserved.
//

import UIKit
import CoreBluetooth

/**
 This view lists the GATT profile of a connected characteristic
 */
class PeripheralViewController: UIViewController, CBCentralManagerDelegate, BlePeripheralDelegate {

    // MARK: UI Elements
    @IBOutlet weak var advertisedNameLabel: UILabel!
    @IBOutlet weak var identifierLabel: UILabel!
    @IBOutlet weak var consoleTextView: UITextView!
    @IBOutlet weak var waveformView: WaveformView!
    @IBOutlet weak var messageLabel: UILabel!
    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var batteryLabel: UILabel!
    @IBOutlet weak var batteryLevel: BatteryLevel!
    
    // MARK: Connected Peripheral Properties

    // Central Manager
    var centralManager: CBCentralManager!

    // connected Peripheral
    var blePeripheral: BlePeripheral!

    // DOGP Characteristic for FOTA
    var dogpReadCharacteristic: CBCharacteristic!
    var dogpWriteCharacteristic: CBCharacteristic!

    // Info Characteristic
    var batteryCharacteristic: CBCharacteristic!
    var commandCharacteristic: CBCharacteristic!
    var systemInfoCharacteristic: CBCharacteristic!
    
    // Button UI
    let gressColor = UIColor(red: 100.0/255.0, green: 221.0/255.0, blue: 23.0/255.0, alpha: 1.0)
    let redColor = UIColor(red: 1.0, green: 45.0/255.0, blue: 60.0/255.0, alpha: 1.0)
    
    var timer = Timer()
    var buttonState = false
    var timerCounter: Int = 1200
    var timerOn = false
    
    

    /**
     UIView loaded
     */
    override func viewDidLoad() {
        super.viewDidLoad()
        printToConsole("Will connect to \(blePeripheral.peripheral.identifier.uuidString)")
        loadUI()
        
        // Assign delegates
        blePeripheral.delegate = self
        centralManager.delegate = self
        centralManager.connect(blePeripheral.peripheral)
    }

    // MARK: BlePeripheralDelegate

    /**
     Characteristics were discovered.  Update the UI
     */
    func blePerihperal(discoveredCharacteristics characteristics: [CBCharacteristic], forService: CBService, blePeripheral: BlePeripheral) {
        
    }

    /**
     RSSI discovered.  Update UI
     */
    func blePeripheral(readRssi rssi: NSNumber, blePeripheral: BlePeripheral) {
        
    }
    
    func blePeripheral(characteristicRead byteArray: [UInt8], characteristic: CBCharacteristic, blePeripheral: BlePeripheral, error: Error?) {
        
        switch characteristic.uuid.uuidString {
        case "2A19":
            printToConsole("Battery characteristic received! battery is \(byteArray[0])%")
            batteryLevel.level = CGFloat(byteArray[0]) / 100.0
            batteryLabel.text = "\(byteArray[0])%"
            if (byteArray[0]<=40) { batteryLevel.backgroundColor = UIColor.red }
        case "4AA0":
            var mode: Int = 0
            
            let headerCheck: Bool = (byteArray[0] == 73) && (byteArray[1] == 82) &&
                (byteArray[2] == 84) && (byteArray[3] == 73)
            
            if  headerCheck && byteArray[5] == 171 {
                mode = Int(byteArray[4])
            }
            
            switch mode {
            case 2:
                let dataArray = [UInt8](byteArray[12...])
                if dataArray.count == 212 {
                    parseRealTimeMode(dataArray: dataArray)
                } else {
                    printToConsole("Receive data array length : \(dataArray.count)")
                    if timerOn {
                        timer.invalidate()
                        timerCounter = 1200
                        timerOn = false
                    } else {
                        timer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(updateSecondLabel), userInfo: nil, repeats: true)
                        timerOn = true
                    }
                }
            default:
                printToConsole("Parse mode not find, mode value is \(mode)")
            }
        case "4AA1":
            printToConsole("SystemInfo characteristic received! byteArray length is \(byteArray.count)")
            if (byteArray.count == 96) {
                let venderName: String! = String(bytes: byteArray[0...31], encoding: .utf8 )
                let boardName: String! = String(bytes: byteArray[31...63], encoding: .utf8 )
                let fwVersion: String! = String(bytes: byteArray[64...95], encoding: .utf8 )
                printToConsole("System Info - Vender Name : \(venderName!)")
                printToConsole("System Info - Board Name : \(boardName!)")
                printToConsole("System Info - firmware Version : \(fwVersion!)")
            }
        default:
            printToConsole("Characteristic \(characteristic.uuid.uuidString) not found !byteArray length is \(byteArray.count) ")
        }
        
    }
    
    var fileDurationTime: [UInt32] = [UInt32](repeating: 0, count: 32)
    let header: UInt32 = 0x49545249
    let cmdType: [UInt16] = [0xAB01, 0xAB02, 0xAB03, 0xAB04, 0xAB05, 0xAB06, 0xAB07, 0xAB08, 0xAB09]
    var cmdData: [Bool] = [false, false, false, false, false, false, false, false, false]
    let comment = "FFFFFFFF"
    var lastPressBtn: Int = 6
    
    // Generate the command string by bigEndian.
    func generateCommandString() -> String {
        
        var commandStr = ""
        
        let cmdDataValue = cmdData[lastPressBtn] ? UInt16(0x0002) : UInt16(0x0001)
        
        let Header = String(format: "%08X", header.bigEndian)
        
        let CMDType = String(format: "%04X", cmdType[lastPressBtn].bigEndian)
        
        let CMDDataValue = String(format: "%04X", cmdDataValue.bigEndian)
        
        if lastPressBtn == 6 {
            let Comment = String(repeating: comment, count: 5)
            commandStr = Header + CMDType + CMDDataValue + getCurrentDate() + Comment
        } else {
            let Comment = String(repeating: comment, count: 6)
            commandStr = Header + CMDType + CMDDataValue + Comment
        }
    
        cmdData[lastPressBtn] = !cmdData[lastPressBtn]
        cmdData[5] = false
        cmdData[6] = false
        cmdData[7] = false
        cmdData[8] = false
        printToConsole("The string will be write to peripheral: \(commandStr)")
        return commandStr
    }
    
    func parseRealTimeMode (dataArray: [UInt8]) {
        for i in 1...50 {
            // Update the signal value of channel 1
            let ch1Value = Int16(dataArray[11+i*2]) << 8 + Int16(dataArray[10+i*2])
            waveformView.pushSignal1BySliding(newValue: CGFloat(ch1Value))
            // Update the signal value of channel 2
            let ch2Value = Int16(dataArray[111+i*2]) << 8 + Int16(dataArray[110+i*2])
            waveformView.pushSignal2BySliding(newValue: CGFloat(ch2Value))
        }
    }
    
    func getCurrentDate() -> String {
        
        let date = Date()
        let calender = Calendar.current
        let components = calender.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        
        let year = components.year
        let month = components.month
        let day = components.day
        let hour = components.hour
        let minute = components.minute
        let second = components.second
        
        let today_string = String(year!) + "-" + String(month!) + "-" + String(day!) + " " + String(hour!) + ":" + String(minute!) + ":"
            + String(second!)
        printToConsole(today_string)
        
        let byte1: UInt8 = UInt8(year!-2000) << 2 + UInt8(month!) >> 2
        let byte2: UInt8 = (UInt8(month!) % 4) << 6 + UInt8(day!) << 1 + UInt8(hour!) >> 4
        let byte3: UInt8 = (UInt8(hour!) % 16) << 4 + UInt8(minute!) >> 2
        let byte4: UInt8 = (UInt8(minute!) % 4) << 6 + UInt8(second!)
        
        let currentTime = String(format: "%02X", byte4) + String(format: "%02X", byte3) +
            String(format: "%02X", byte2) + String(format: "%02X", byte1)
        printToConsole("currentTime in 4 bytes format is : " + currentTime)
        return currentTime
    }

    // MARK: CBCentralManagerDelegate code

    /**
     Peripheral connected.  Update UI
     */
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        printToConsole("Connected Peripheral: \(String(describing: peripheral.name))")

        advertisedNameLabel.text = blePeripheral.advertisedName
        identifierLabel.text = blePeripheral.peripheral.identifier.uuidString

        blePeripheral.connected(peripheral: peripheral)
        timer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(findCharacteristic), userInfo: nil, repeats: false)
    }

    /**
     Connection to Peripheral failed.
     */
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        printToConsole("failed to connect")
        printToConsole(error.debugDescription)
    }

    /**
     Peripheral disconnected.  Leave UIView
     */
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        printToConsole("Disconnected Peripheral: \(String(describing: peripheral.name))")
        dismiss(animated: true, completion: nil)
    }

    /**
     Bluetooth radio state changed.
     */
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        printToConsole("Central Manager updated: checking state")

        switch (central.state) {
        case .poweredOn:
            printToConsole("bluetooth on")
        default:
            printToConsole("bluetooth unavailable")
        }
    }

    func loadUI() {
        playButton.layer.shadowColor = UIColor.black.cgColor
        playButton.layer.shadowOffset = CGSize(width: 0.0, height: 5.0)
        playButton.layer.masksToBounds = false
        playButton.layer.shadowRadius = 2.0
        playButton.layer.shadowOpacity = 0.5
        playButton.layer.cornerRadius = playButton.frame.width / 12
        playButton.backgroundColor = gressColor
        
        messageLabel.text = "Connecting... "
        
        consoleTextView.isEditable = false
        consoleTextView.isSelectable = false
    }
    
    
    @IBAction func recordButtonPressed(_ sender: UIButton) {
        if buttonState {
            let stringValue = generateCommandString()
            blePeripheral.writeValue(value: stringValue, to: commandCharacteristic)
            playButton.setTitle("Record!", for: .normal)
            playButton.backgroundColor = gressColor
            buttonState = !buttonState
        } else {
            let stringValue = generateCommandString()
            blePeripheral.writeValue(value: stringValue, to: commandCharacteristic)
            playButton.setTitle("Stop!", for: .normal)
            playButton.backgroundColor = redColor
            buttonState = !buttonState
        }
    }
    
    @objc func updateSecondLabel() {
        DispatchQueue.main.async {
            self.messageLabel.text = "Remaining seconds : \(Float(self.timerCounter)/10)"
        }
        if timerCounter == 0 {
            timer.invalidate()
            timerCounter = 1200
            buttonState = false
            cmdData[lastPressBtn] = true
            playButton.setTitle("Record!", for: .normal)
            playButton.backgroundColor = gressColor
        } else {
            timerCounter -= 1
        }
    }
    
    @objc func findCharacteristic() {
        printToConsole("findCharacteristic() !")
        for service in blePeripheral.gattProfile {
            if let chars = service.characteristics {
                for char in chars {
                    switch (char.uuid.uuidString) {
                    case "2AA0":
                        dogpReadCharacteristic = char
                        printToConsole("Find DOGP Read Characteristic ! uuid is \(dogpReadCharacteristic.uuid.uuidString)")
                    case "2AA1":
                        dogpWriteCharacteristic = char
                        printToConsole("Find DOGP Write Characteristic ! uuid is \(dogpWriteCharacteristic.uuid.uuidString)")
                    case "2A19":
                        batteryCharacteristic = char
                        printToConsole("Find Battery Characteristic ! uuid is \(batteryCharacteristic.uuid.uuidString)")
                    case "4AA0":
                        commandCharacteristic = char
                        printToConsole("Find Command Characteristic ! uuid is \(commandCharacteristic.uuid.uuidString)")
                    case "4AA1":
                        systemInfoCharacteristic = char
                        printToConsole("Find System Info Characteristic ! uuid is \(systemInfoCharacteristic.uuid.uuidString)")
                    default:
                        printToConsole("Characteristic \(char.uuid.uuidString) is not specific char !")
                    }
                }
            }
        }
        blePeripheral.peripheral.setNotifyValue(true, for: commandCharacteristic)
        blePeripheral.peripheral.setNotifyValue(true, for: systemInfoCharacteristic)
        readSystemInfo()
        if lastPressBtn != 6 { lastPressBtn = 6 }
        let stringValue = generateCommandString()
        blePeripheral.writeValue(value: stringValue, to: commandCharacteristic)
        lastPressBtn = 1
        messageLabel.text = "Ready!"
    }
    
    func readSystemInfo() {
        if let battery = batteryCharacteristic {blePeripheral.readValue(from: battery)}
        if let systemInfo = systemInfoCharacteristic {
            blePeripheral.readValue(from: systemInfo)
            //printToConsole("Read systemInfo from \(systemInfo.uuid.uuidString) !")
        }
    }
    
    func printToConsole (_ message: String) {
        DispatchQueue.main.async {
            self.consoleTextView.insertText(message + "\n")
            let stringLength = self.consoleTextView.text.count
            self.consoleTextView.scrollRangeToVisible(NSRange(location: stringLength-1, length: 0))
        }
    }
    
}
