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

/**
 This view talks to a Characteristic
 */
class CharacteristicViewController: UIViewController, CBCentralManagerDelegate, BlePeripheralDelegate, NotifyCustomDelegate, NotifyFotaDelegate {

    // MARK: UI elements
    @IBOutlet weak var advertizedNameLabel: UILabel!
    @IBOutlet weak var identifierLabel: UILabel!
    @IBOutlet weak var characteristicUuidlabel: UILabel!

    @IBOutlet weak var waveformArea: WaveformView!
    @IBOutlet weak var signal1Value: UILabel!
    @IBOutlet weak var signal2Value: UILabel!
    @IBOutlet weak var writeCharacteristicButton: UIButton!
    @IBOutlet weak var writeFOTAButton: UIButton!
    @IBOutlet weak var writeCharacteristicTextField: UITextField!

    @IBOutlet weak var accelerXLabel: UILabel!
    @IBOutlet weak var accelerYLabel: UILabel!
    @IBOutlet weak var accelerZLabel: UILabel!

    @IBOutlet weak var fileIndexTextFiled: UITextField!
    @IBOutlet weak var startTimeTextField: UITextField!
    @IBOutlet weak var durationTimeTextField: UITextField!

    @IBOutlet weak var consoleTextView: UITextView!

    // MARK: Connected devices

    // Central Bluetooth Radio
    var centralManager: CBCentralManager!

    // Bluetooth Peripheral
    var blePeripheral: BlePeripheral!

    // Connected Characteristic
    var connectedService: CBService!

    // Connected Characteristic
    var connectedCharacteristic: CBCharacteristic!

    // DOGP Characteristic for FOTA
    var dogpReadCharacteristic: CBCharacteristic!
    var dogpWriteCharacteristic: CBCharacteristic!
    var dogpCharFind: Bool = false

    // Info Characteristic
    var batteryCharacteristic: CBCharacteristic!
    var commandCharacteristic: CBCharacteristic!
    var systemInfoCharacteristic: CBCharacteristic!

    // BtNotify Library
    var btNotify: BtNotify!

    // Fota Type
    var FotaType: Int32 = 5 // Full bin

    /**
     UIView loaded
     */
    override func viewDidLoad() {
        super.viewDidLoad()
        loadUI()
        printToConsole("Will connect to device \(blePeripheral.peripheral.identifier.uuidString)")
        printToConsole("Will connect to characteristic \(connectedCharacteristic.uuid.uuidString)")

        centralManager.delegate = self
        blePeripheral.delegate = self

        FotaSetting()
        readSystemInfo()
    }

    @IBAction func notifyCharacteristic(_ sender: UISwitch) {
        printToConsole("notify the characteristic is \(sender.isOn)")
        blePeripheral.peripheral.setNotifyValue(sender.isOn, for: commandCharacteristic)
    }
    /* Load UI elements */
    func loadUI() {
        advertizedNameLabel.text = blePeripheral.advertisedName
        identifierLabel.text = blePeripheral.peripheral.identifier.uuidString
        characteristicUuidlabel.text = connectedCharacteristic.uuid.uuidString

        // characteristic is not writeable
        /*if !BlePeripheral.isCharacteristic(isWriteable: connectedCharacteristic) {
            writeCharacteristicTextField.isEnabled = false
            writeCharacteristicButton.isEnabled = false
        }*/
        writeFOTAButton.isEnabled = false
        startTimeTextField.isEnabled = false
        durationTimeTextField.isEnabled = false
        consoleTextView.isEditable = false
        consoleTextView.isSelectable = false
        blePeripheral.peripheral.setNotifyValue(true, for: commandCharacteristic)
        blePeripheral.peripheral.setNotifyValue(true, for: systemInfoCharacteristic)
    }

    func readSystemInfo() {
        if let battery = batteryCharacteristic {blePeripheral.readValue(from: battery)}
        if let systemInfo = systemInfoCharacteristic {
            blePeripheral.readValue(from: systemInfo)
            printToConsole("Read systemInfo from \(systemInfo.uuid.uuidString) !")
        }
    }

    func FotaSetting() {
        if let dogpRead = dogpReadCharacteristic, let dogpWrite = dogpWriteCharacteristic {
            printToConsole("dogpReadCharacteristic find ! uuid is \(dogpRead.uuid.uuidString)")
            printToConsole("dogpWriteCharacteristic find ! uuid is \(dogpWrite.uuid.uuidString)")
            dogpCharFind = true
            printToConsole("dogpCharFind is \(dogpCharFind)")
        }
        if dogpCharFind {
            printToConsole("The FOTA characteristic is found (\(dogpReadCharacteristic.uuid.uuidString),\(dogpWriteCharacteristic.uuid.uuidString)), FOTA setting is running.")
        } else {
            printToConsole("The FOTA characteristic not found, FOTA setting is quit !")
            return
        }

        btNotify = (BtNotify.sharedInstance() as! BtNotify)
        btNotify.register(self as NotifyCustomDelegate)
        btNotify.register(self as NotifyFotaDelegate)

        if dogpCharFind {
            btNotify.setGattParameters(blePeripheral.peripheral,
                                       write: dogpWriteCharacteristic,
                                       read: dogpReadCharacteristic)
            printToConsole("btNotify.setGattParameters run succeed ! ")
        }
        btNotify.updateConnectionState(Int32(CBPeripheralState.connected.rawValue))

        writeFOTAButton.isEnabled = dogpCharFind
    }

    @IBAction func writeFOTA(_ sender: UIButton) {
        let fileName = "ITRI_HDK_FW_Fota_09252018_Non-Resp_filename"
        let bundlePath = Bundle.main.url(forResource: fileName, withExtension: "bin")
        printToConsole("bundlePath of \(fileName) is " + (bundlePath?.path)!)

        let response = btNotify.sendFotaTypeGetCmd()
        printToConsole("btNotify.sendFotaTypeGetCmd() response is \(response)")
        checkReturnValue(response)

        do {
            let data = try Data(contentsOf: bundlePath!)
            printToConsole("The content size of \(fileName).bin is (Data) : \(data.count)")
            btNotify.sendFotaData(FotaType, firmwareData: data)
            printToConsole("btNotify.sendFotaData() run !")
        } catch {
            printToConsole("Parse image.bin string Error !")
        }
        writeFOTAButton.isEnabled = false
    }

    func checkReturnValue(_ returnValue: Int32) {
        var message: String
        switch returnValue {
        case ERROR_CODE_OK:
            message = "ERROR_CODE_OK"
        case ERROR_CODE_NOT_INITED:
            message = "ERROR_CODE_NOT_INITED"
        case ERROR_CODE_NOT_STARTED:
            message = "ERROR_CODE_NOT_STARTED"
        case ERROR_CODE_NOT_HANDSHAKE_DONE:
            message = "ERROR_CODE_NOT_HANDSHAKE_DONE"
        case ERROR_CODE_FOTA_WRONG_TYPE:
            message = "ERROR_CODE_FOTA_WRONG_TYPE"
        default:
            message = "not found"
        }
        printToConsole("returnValue \(returnValue) means \(message) !")
    }

    /* Implement function for NotifyCustomDelegete */
    func onDataArrival(_ receiver: String!, arrivalData data: Data!) {
        printToConsole("onDataArrival: the receiver : \(receiver), arrivalData length : \(data.count))")
    }

    func onReady(toSend ready: Bool) {
        printToConsole("FOTA onReady is \(ready)")
    }

    func onProgress(_ sender: String!, newProgress progress: Float) {
        printToConsole("onProgress: the sender is \(sender), progress: \(progress)")
    }

    /* Implement function for NotifyFotaDelegete */
    func onFotaTypeReceived(_ fotaType: Int32) {
        printToConsole("onFotaTypeReceived: the fotaType is \(fotaType)")
        FotaType = fotaType
        var message: String
        switch fotaType {
        case REDBEND_FOTA_UPDATE:
            message = "REDBEND_FOTA_UPDATE"
        case SEPARATE_BIN_FOTA_UPDATE:
            message = "SEPARATE_BIN_FOTA_UPDATE"
        case ROCK_FOTA_UPDATE:
            message = "ROCK_FOTA_UPDATE"
        case FBIN_FOTA_UPDATE:
            message = "FBIN_FOTA_UPDATE"
        default:
            message = "not found"
        }
        printToConsole("returnValue: \(fotaType) means \(message) !")
    }

    func onFotaStatusReceived(_ status: Int32) {
        printToConsole("onFotaStatusReceived: the status is \(status)")
        var message: String
        switch status {
        case FOTA_UPDATE_VIA_BT_TRANSFER_SUCCESS:
            message = "FOTA_UPDATE_VIA_BT_TRANSFER_SUCCESS"
        case FOTA_UPDATE_VIA_BT_UPDATE_SUCCESS:
            message = "FOTA_UPDATE_VIA_BT_UPDATE_SUCCESS"
        case FOTA_UPDATE_VIA_BT_COMMON_ERROR:
            message = "FOTA_UPDATE_VIA_BT_COMMON_ERROR"
        case FOTA_UPDATE_VIA_BT_WRITE_FILE_FAILED:
            message = "FOTA_UPDATE_VIA_BT_WRITE_FILE_FAILED"
        case FOTA_UPDATE_VIA_BT_DISK_FULL:
            message = "FOTA_UPDATE_VIA_BT_DISK_FULL"
        case FOTA_UPDATE_VIA_BT_TRANSFER_FAILED:
            message = "FOTA_UPDATE_VIA_BT_TRANSFER_FAILED"
        case FOTA_UPDATE_VIA_BT_TRIGGER_FAILED:
            message = "FOTA_UPDATE_VIA_BT_TRIGGER_FAILED"
        case FOTA_UPDATE_VIA_BT_UPDATE_FAILED:
            message = "FOTA_UPDATE_VIA_BT_UPDATE_FAILED"
        case FOTA_UPDATE_VIA_BT_TRIGGER_FAILED_CAUSE_LOW_BATTERY:
            message = "FOTA_UPDATE_VIA_BT_TRIGGER_FAILED_CAUSE_LOW_BATTERY"
        default:
            message = "not found"
        }
        printToConsole("status: \(status) means \(message) !")
    }

    func onFotaProgress(_ progress: Float) {
        printToConsole("onFotaProgress: progress is \(String(format: "%.2f", progress*100)) %")
    }

    func onFotaVersionReceived(_ version: FotaVersion!) {
        printToConsole("onFotaVersionReceived: FotaVersion is \(version)")
    }

    var fileDurationTime: [UInt32] = [UInt32](repeating: 0, count: 32)
    let header: UInt32 = 0x49545249
    let cmdType: [UInt16] = [0xAB01, 0xAB02, 0xAB03, 0xAB04, 0xAB05, 0xAB06, 0xAB07, 0xAB08, 0xAB09]
    var cmdData: [Bool] = [false, false, false, false, false, false, false, false, false]
    let comment = "FFFFFFFF"
    var lastPressBtn: Int = 0

    @IBAction func writeCharacteristic(_ sender: UIButton) {
        printToConsole("write button pressed")
        writeCharacteristicButton.isEnabled = false

        let stringValue = generateCommandString()
        blePeripheral.writeValue(value: stringValue, to: commandCharacteristic)
        writeCharacteristicTextField.text = ""
        writeCharacteristicButton.isEnabled = true
    }

    // Generate the command string by bigEndian.
    func generateCommandString() -> String {

        var commandStr = ""

        let cmdDataValue = cmdData[lastPressBtn] ? UInt16(0x0002) : UInt16(0x0001)

        let Header = String(format: "%08X", header.bigEndian)

        let CMDType = String(format: "%04X", cmdType[lastPressBtn].bigEndian)

        let CMDDataValue = String(format: "%04X", cmdDataValue.bigEndian)

        if (lastPressBtn == 2) || (lastPressBtn == 3) || (lastPressBtn == 4) {
            let Comment = String(repeating: comment, count: 3)
            commandStr = Header + CMDType + CMDDataValue + getFileCommandString() + Comment
        } else if lastPressBtn == 6 {
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

    @IBAction func writeTestText(_ sender: UIButton) {

        let cmdDataValue = cmdData[sender.tag] ? "0002" : "0001"

        if (sender.tag == 2) || (sender.tag == 3) || (sender.tag == 4) {
            let fileIndex = UInt32(fileIndexTextFiled.text!) ?? 0
            let startTime = UInt32(startTimeTextField.text!) ?? 0
            let durationTime = UInt32(durationTimeTextField.text!) ?? 0

            if !((fileIndex >= 1) && (fileIndex <= 32)) {
                printToConsole("fileIndex error !! Need to follow the condition: >= 1 && <= 32")
            } else if !((startTime >= 0) && (durationTime >= 0)) {
                printToConsole("startTime or durationTime error !! Need to follow the condition: >= 0")
            } else if !(startTime + durationTime <= fileDurationTime[Int(fileIndex)-1]) {
                printToConsole("Exceed maximum file time error !! The startTime: \(startTime) + durationTime: \(durationTime) need to <= maximum of \(fileIndex) file: \(fileDurationTime[Int(fileIndex)-1]) ")
            } else {
                writeCharacteristicTextField.text = String(header, radix: 16) +
                    String(cmdType[sender.tag], radix: 16) + cmdDataValue +
                    getFileCommandString() + String(repeating: comment, count: 3)
                printToConsole("The input format is valid !! write command text succeed !!")
            }
        } else if sender.tag == 6 {
            writeCharacteristicTextField.text = String(header, radix: 16) +
                String(cmdType[sender.tag], radix: 16) + cmdDataValue + getCurrentDate() + String(repeating: comment, count: 5)
        } else {
            writeCharacteristicTextField.text = String(header, radix: 16) +
                String(cmdType[sender.tag], radix: 16) + cmdDataValue + String(repeating: comment, count: 6)
        }

        lastPressBtn = sender.tag
    }
    // MARK: BlePeripheralDelegate

    /*
     Characteristic was write
     */
    func blePeripheral(characteristicWrite peripheral: CBPeripheral, characteristic: CBCharacteristic, blePeripheral: BlePeripheral, error: Error?) {
        if characteristic.uuid.uuidString == dogpWriteCharacteristic.uuid.uuidString {
            btNotify.handleWriteResponse(characteristic, error: error)
        }
    }

    /**
     Characteristic was read.  Update UI
     */
    func blePeripheral(characteristicRead byteArray: [UInt8], characteristic: CBCharacteristic, blePeripheral: BlePeripheral, error: Error?) {

        switch characteristic.uuid.uuidString {
        case "2AA0":
            btNotify.handleReadReceivedData(characteristic, error: error)
        case "2A19":
            printToConsole("Battery characteristic received! battery is \(byteArray[0])%")
        case "4AA0":
            var mode: Int = 0

            let headerCheck: Bool = (byteArray[0] == 73) && (byteArray[1] == 82) &&
                (byteArray[2] == 84) && (byteArray[3] == 73)

            if lastPressBtn == 1 {
                printToConsole("signal 1 Max : \(waveformArea.signal1Max), Min : \(waveformArea.signal1Min)")
                printToConsole("signal 2 Max : \(waveformArea.signal2Max), Min : \(waveformArea.signal2Min)")
            }
            if  headerCheck && byteArray[5] == 171 {
                mode = Int(byteArray[4])
            }

            switch mode {
            case 2:
                let dataArray = [UInt8](byteArray[12...])
                if dataArray.count == 212 { parseRealTimeMode(dataArray: dataArray) }
            case 3:
                let dataArray = [UInt8](byteArray[12...])
                if dataArray.count == 212 { parseRPeakMode(dataArray: dataArray) }
            case 6:
                let dataArray = [UInt8](byteArray[12...])
                let dataLength = Int(byteArray[7]) << 8 + Int(byteArray[6])
                parseGetFileListDate(dataArray: dataArray, dataLength: dataLength)
            case 9:
                let dataArray = [UInt8](byteArray[8...])
                parseSystemInfo(dataArray: dataArray)
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

    func parseSystemInfo (dataArray: [UInt8]) {
        guard dataArray.count == 24 else {
            printToConsole("[parseSystemInfoError] dataArray length is: \(dataArray.count) not 24 bytes")
            return
        }

        let systemTime = parseTime(time: [UInt8](dataArray[0...3]))
        let ststemStatus = byteToUInt32(bytes: [UInt8](dataArray[4...7]) )
        let recFileIndex = byteToUInt32(bytes: [UInt8](dataArray[8...11]) )
        let recFileCreateTime = parseTime(time: [UInt8](dataArray[12...15]) )
        let recFileDurationTime = byteToUInt32(bytes: [UInt8](dataArray[16...19]) )
        let systemError = byteToUInt32(bytes: [UInt8](dataArray[20...23]) )

        printToConsole("""
        Read systemInfo success! :
        systemTime : \(systemTime)
        ststemStatus : \(ststemStatus)
        recFileIndex : \(recFileIndex)
        recFileCreateTime : \(recFileCreateTime)
        recFileDurationTime : \(recFileDurationTime)
        systemError : \(systemError)
        """)

    }

    func parseTime(time: [UInt8]) -> String {
        guard time.count == 4 else {return "Time array need 4 byte format!"}
        let year: UInt8 = time[3] >> 2
        let month: UInt8 = (time[3] % 4) << 2 + time[2] >> 6
        let day: UInt8 = (time[2] >> 1) % 32
        let hour: UInt8 = (time[2] % 2) << 4 + time[1] >> 4
        let min: UInt8 = (time[1] % 16) << 2 + time[0] >> 6
        let sec: UInt8 = time[0] % 64
        return "\(Int(year)+2000)-\(month)-\(day) \(hour):\(min):\(sec)"
    }

    func byteToUInt32 (bytes: [UInt8]) -> UInt32 {
         if bytes.count == 4 {
            let data = Data(bytes: bytes)
            return UInt32(littleEndian: data.withUnsafeBytes { $0.pointee })
        } else {
            printToConsole("the bytes length is \(bytes.count)")
            return UInt32(littleEndian: 0)
        }
    }

    func parseGetFileListDate (dataArray: [UInt8], dataLength: Int) {

        let dataInRange = dataArray.count > dataLength

        let message = """
        Parse GetFileList Mode :
        The array length is \(dataArray.count)
        The data length is \(dataLength)
        dataInRange is \(dataInRange)
        """
        printToConsole(message)

        if dataLength >= 12 {
            for i in 1...(dataLength/12) {
                let year: UInt8 = dataArray[i*12-5] >> 2
                //printToConsole("The year byte is : \(dataArray[i*12-5])")
                //printToConsole("in binary : " + String(dataArray[i*12-5], radix: 2))
                let month: UInt8 = (dataArray[i*12-5] % 4) << 2 + dataArray[i*12-6] >> 6
                let day: UInt8 = (dataArray[i*12-6] >> 1) % 32
                let hour: UInt8 = (dataArray[i*12-6] % 2) << 4 + dataArray[i*12-7] >> 4
                let min: UInt8 = (dataArray[i*12-7] % 16) << 2 + dataArray[i*12-8] >> 6
                let sec: UInt8 = dataArray[i*12-8] % 64

                let durationTime: UInt32 = UInt32(dataArray[i*12-1]) << 24 +
                                            UInt32(dataArray[i*12-2]) << 16 +
                                            UInt32(dataArray[i*12-3]) << 8 +
                                            UInt32(dataArray[i*12-4])

                let fileIndex: UInt32 = UInt32(dataArray[i*12-9]) << 24 +
                                         UInt32(dataArray[i*12-10]) << 16 +
                                         UInt32(dataArray[i*12-11]) << 8 +
                                         UInt32(dataArray[i*12-12])

                if (fileIndex >= 1) && (fileIndex <= 32) {
                    fileDurationTime[Int(fileIndex)-1] = durationTime
                }
                let message = "The date of \(fileIndex) file : \(Int(year)+2000)-\(month)-\(day) \(hour):\(min):\(sec)  Duration Time: \(durationTime)"
                printToConsole(message)
            }
        }
        startTimeTextField.isEnabled = true
        durationTimeTextField.isEnabled = true
        durationTimeTextField.text = String(fileDurationTime[0])
        printToConsole("duration times is saved in array: \(fileDurationTime)")
    }

    func parseRealTimeMode (dataArray: [UInt8]) {

        let message = "Parse Real-Time Mode Data: dataArray length is \(dataArray.count)"
        printToConsole(message)

        func updateAccelerLabel(isFirst: Bool) {
            let offset = isFirst ? 0 : 6
            let accelerXValue = Int16(dataArray[1+offset]) << 8 + Int16(dataArray[0+offset])
            accelerXLabel.text = String(accelerXValue)
            let accelerYValue = Int16(dataArray[3+offset]) << 8 + Int16(dataArray[2+offset])
            accelerYLabel.text = String(accelerYValue)
            let accelerZValue = Int16(dataArray[5+offset]) << 8 + Int16(dataArray[4+offset])
            accelerZLabel.text = String(accelerZValue)
        }
        updateAccelerLabel(isFirst: true)

        for i in 1...50 {
            if i == 26 { updateAccelerLabel(isFirst: false) }

            // Update the signal value of channel 1
            let ch1Value = Int16(dataArray[11+i*2]) << 8 + Int16(dataArray[10+i*2])
            waveformArea.pushSignal1BySliding(newValue: CGFloat(ch1Value))
            signal1Value.text = String(ch1Value)
            // Update the signal value of channel 2
            let ch2Value = Int16(dataArray[111+i*2]) << 8 + Int16(dataArray[110+i*2])
            waveformArea.pushSignal2BySliding(newValue: CGFloat(ch2Value))
            signal2Value.text = String(ch2Value)
        }
        printToConsole("signal 2 max: \(waveformArea.signal2Max), min : \(waveformArea.signal2Min)")
    }

    func parseRPeakMode (dataArray: [UInt8]) {
        let message = "Parse R-Peak Mode Data: dataArray length is \(dataArray.count)"
        printToConsole(message)
        
    }

    func printToConsole (_ message: String) {
        DispatchQueue.main.async {
            print(message)
            self.consoleTextView.insertText(message + "\n")
            let stringLength = self.consoleTextView.text.count
            self.consoleTextView.scrollRangeToVisible(NSRange(location: stringLength-1, length: 0))
        }
    }

    func getFileCommandString() -> String {
        let fileIndex = UInt32(fileIndexTextFiled.text!) ?? 0
        let startTime = UInt32(startTimeTextField.text!) ?? 0
        let durationTime = UInt32(durationTimeTextField.text!) ?? 0
        printToConsole("getFileCommandString : fileIndex: \(fileIndex), startIndex: \(startTime), durationTime: \(durationTime)")
        let commandString = String(format: "%08X", fileIndex.bigEndian) +
                            String(format: "%08X", startTime.bigEndian) +
                            String(format: "%08X", durationTime.bigEndian)
        printToConsole("commandString is \(commandString)")
        return commandString
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
