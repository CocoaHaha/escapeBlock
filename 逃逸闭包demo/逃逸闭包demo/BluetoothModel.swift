//
//  BluetoothModel.swift
//  StopwatchApp
//
//  Created by luhong on 2021/12/20.
//

import UIKit

class BluetoothModel: NSObject {

    @objc var battery:Int64 = 0xFFFFFFFF
    
    @objc var version = "1.0.0"
    
    @objc var macAdddress = ""
    @objc var rawMac = ""
    
    @objc var deviceInfoArr:[Int] = []

    
}

//fit文件服务
let BLE_UUID_UART_SERVICE = "6E400001-B5A3-F393-E0A9-E50E24DCCA9E"
//OTA服务
let DFU_SERVICE_UUID = "8E400001-F315-4F60-9FB8-838830DAEA50"
//电量服务
let BATTERY_SERVICE_UUID = "0000180F-0000-1000-8000-00805F9B34FB"


//fit文件发送特征
let SERVICE_CHANGED_UUID = "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"
//fit文件接收
let NOTICE_UUID = "6E400003-B5A3-F393-E0A9-E50E24DCCA9E"
//设置模块接收
let DISPLAY_VALUE_TYPE_UUID = "6E400004-B5A3-F393-E0A9-E50E24DCCA9E"
//获取外设
let GET_PERIPHERAL_VALUE_UUID = "6E400004-B5A3-F393-E0A9-E50E24DCCA9E"
//OTA接收
let  DFU_CHARACTERISTIC_UUID = "8E400001-F315-4F60-9FB8-838830DAEA50"
//电量接收
let BATTERY_CHARACTERISTIC_UUID = "00002A19-0000-1000-8000-00805F9B34FB"


