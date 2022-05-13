//
//  BluetoothManager.swift
//  StopwatchApp
//
//  Created by luhong on 2021/12/20.
//

import UIKit
import CoreBluetooth
import SwiftUI
class BluetoothManager: NSObject,CBCentralManagerDelegate,CBPeripheralDelegate{
    static let shared = BluetoothManager();
    var aPeripheral:CBPeripheral?
//    private var aPeripheral:CBPeripheral?
    private var aCharacteristic:CBCharacteristic?
    private var fitWriteCharacteristic:CBCharacteristic?
    private var setWriteCharacteristic:CBCharacteristic?
    private var otaWriteCharacteristic:CBCharacteristic?
    private var batteryWriteCharacteristic:CBCharacteristic?

    //蓝牙数据
    private(set) var bleInfoModel :BluetoothModel =  BluetoothModel();
    
    var centralM:CBCentralManager?
    private var peripheralArray:[CBPeripheral] = []
    
    //定义代理
    open var delegate:BluetoothDelegate?
    
    //FIXME: 蓝牙状态
    private(set) var bleState:ZeeBleState = .unauthorized{
        didSet{
            if(bleState == .poweredOff){
//                Common.showToast(title: "系统蓝牙关闭，无法连接蓝牙", success: false)
            }else if(bleState == .passwordFail){
//                Common.showToast(title: "蓝牙连接密码错误，请联系客服")
            }
            DispatchQueue.main.async { [unowned self] in
                self.delegate?.bleManagerDidUpdateState(bleState)
            }
        }
    }
    //FIXME: fit执行状态
//    private(set) var fitStatus:FitStatus = .star
    var fitDataSize = 0 //fit文件数据长度 这用于计算
    var sumFitDataSize = 0 //fit文件数据长度

    var fitData = Data() //fit文件数据
    var fitName =  "filelist.txt"//filelist.txt 获取fit列表 其他同步fit文件

    private var fitNameArray:[String] = []
    
    
    var sendFileStatus:ZeeBleFileSendState = .normal
    {
        didSet
        {
            if sendFileStatus == .normal || sendFileStatus == .end{
//                Common.dismissLoading()
            }
            DispatchQueue.main.async { [unowned self] in
                self.delegate?.sendFileStatus(self.sendFileStatus)
            }
        }
    }
    var sendFileData = Data() //发送文件数据
    var againFileData = Data() //发送文件数据


    func setZeeBleState(status:ZeeBleState)
    {
        self.bleState = status
    }
    
    //FIXME: 启动蓝牙/开始搜索
    func startBleService(){
        if(self.centralM == nil){
            self.initCentralM();
        }
        self.peripheralArray.removeAll()
        delegate?.blePeripherals(self.peripheralArray)
        
//        if self.bleState == .connected || self.bleState == .connecting
//        {
//            self.bleState = .connecting
            self.centralM!.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey : NSNumber.init(value: false)]);
//        }
    }
    //FIXME: 初始化中心管理器
    func initCentralM(){
        if(centralM == nil){
            self.centralM = CBCentralManager(delegate: self, queue:nil)
        }
    }
    //FIXME: 初始化中心管理器
    func connectPeripheral(peripheral:CBPeripheral){
        if(centralM != nil){
            self.aPeripheral = peripheral;
            self.centralM!.connect(self.aPeripheral!, options: nil)
        }
    }
    //FIXME: 关闭蓝牙资源
    func stopBleService(){
        if(self.aPeripheral != nil){
            self.centralM!.cancelPeripheralConnection(self.aPeripheral!);
            self.aPeripheral = nil
            self.aCharacteristic = nil
            self.fitWriteCharacteristic = nil
            self.setWriteCharacteristic = nil
            self.otaWriteCharacteristic = nil
            self.batteryWriteCharacteristic = nil

        }else{
            self.centralM?.stopScan()
        }
        if self.sendFileStatus != .normal
        {
            self.sendFileStatus = .normal
        }
    }
    
}
//MARK: -- 中心管理器的代理
extension BluetoothManager {
    // FIXME: 检查运行这个App的设备是不是支持BLE。
    func centralManagerDidUpdateState(_ central: CBCentralManager){
        switch central.state {
        case .unknown:
            print("蓝牙状态未知，需要更新")
            self.bleState = .unauthorized
            break;
        case .resetting:
            //            print("与系统服务的连接暂时丢失，需要更新")
            self.bleState = .unauthorized
            break;
            
        case .unsupported:
            print("该平台不支持蓝牙低能耗")
            self.bleState = .unauthorized
            break;
        case .unauthorized:
            print("该应用不被授权支持蓝牙低能耗")
            self.stopBleService();
            self.bleState = .unauthorized
            
            break;
            
        case .poweredOff:
            print(" ＃＃ 系统蓝牙关 ＃＃ ")
            self.stopBleService();
            self.bleState = .poweredOff
            break;
            
        case .poweredOn:
            print(" ＃＃ 系统蓝牙开 ＃＃ ")
            if self.bleState != .connecting
            {
                self.bleState = .connecting;
                self.centralM!.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey : NSNumber.init(value: false)]);
            }
            
            break;
            
        default:
            break;
        }
    }
    // 开始扫描之后会扫描到蓝牙设备，扫描到之后走到这个代理方法
    // FIXME: 中心管理器扫描到了设备
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        
        if peripheral.name != nil && (peripheral.name?.contains("664") == true || peripheral.name?.contains("OTA") == true){
            
            print("找到蓝牙名字:\(String(describing:peripheral.name))")
            for peri in self.peripheralArray //如果相同就直接返回
            {
                if peri.name == peripheral.name
                {
                    return
                }
            }
            self.peripheralArray.append(peripheral)
            delegate?.blePeripherals(self.peripheralArray)
        }
//        && (peripheral.name?.contains("LXQ") == true || peripheral.name?.contains("OTA") == true)
    }
    // FIXME: 连接外设成功，开始发现服务
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("连接成功")
//        print("----------\(peripheral.description)-------")

        self.bleState = .connected;
        self.aPeripheral = peripheral;
        self.aPeripheral!.delegate = self;
        self.aPeripheral!.discoverServices(nil);
        self.centralM!.stopScan()
        self.getRSSI(perip: peripheral)
        if peripheral.name?.contains("OTA") == false
        {
//            let arr = FMDBManager.shared.selectList(model: DeviceModel()) {return DeviceModel()} as! [DeviceModel]
//            for model in arr
//            {
//                if model.deviceName == self.aPeripheral?.name
//                {
//                    return
//                }
//            }
//            let model = DeviceModel()
//            model.deviceName = self.aPeripheral?.name ?? "--"
//            FMDBManager.shared.insert(model: model)
        }

        
    }
    // FIXME: 获取蓝牙信号值
    func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
//        if self.aPeripheral != nil
//        {
//            self.perform(#selector(self.getRSSI(perip:)), with: peripheral, afterDelay: 2)
//        }
        if error == nil
        {
            let power = Double(labs(RSSI.intValue) - 59) / (10.0 * 2.0)
            print("根据信号值计算出的距离：\(Float(powf(10.0, Float(power))))")
        }
    }
    
    @objc func getRSSI(perip:CBPeripheral)
    {
        perip.readRSSI()
    }
    
    // FIXME: 连接外设失败
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("连接失败\(String(describing:error))")
        self.centralM!.connect(peripheral, options: nil)
    }
    // FIXME: 连接断开
    //连接断开
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        
        print("连接断开\(String(describing:error))")
        //连接断开清空蓝牙资源
        if(self.aPeripheral != nil){
            stopBleService();
        }
        self.bleState = .connectFail;
//        if(self.bleState == .connected && self.aPeripheral != nil){
//            self.bleState = .connectFail;
////            Common.showToast(title: "蓝牙连接已断开")
//        }
    }
    
    
    // MARK: CBPeripheralDelegate
    
    //FIXME: 获取服务\连接服务
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        print("获取服务/连接服务：")
        let services = peripheral.services
        if(services != nil){
            for service in services! {
//                if( service.uuid.uuidString == BLE_UUID_UART_SERVICE){
////                    print("连接到UDID(fit)：",service.uuid.uuidString);
//                    self.aPeripheral?.discoverCharacteristics(nil, for: service)
//                }
//                if( service.uuid.uuidString == DFU_SERVICE_UUID){
////                    print("连接到UDID(OTA)：",service.uuid.uuidString);
//                    self.aPeripheral?.discoverCharacteristics(nil, for: service)
//                }
//                if(service.uuid.uuidString.contains("180F")){
////                    print("连接到UDID(电量)：",service.uuid.uuidString);
//                    self.aPeripheral?.discoverCharacteristics(nil, for: service)
//                }
            }
        }
    }
    
    
    //FIXME: 获取服务特征\连接服务特征
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        print("获取服务特征/连接服务特征")
         
    }
    
    //FIXME: 接受指定特性发来的数据
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        print("接受指定特性发来的数据",characteristic.uuid.uuidString,characteristic.value! as NSData)
        let bytes = [UInt8](characteristic.value!)
        let characteristicData:Data = characteristic.value!;
        var str = "蓝牙数据ble:"
        var resultArr = [Int]()
        for i in 0..<characteristicData.count {
            resultArr.append(Int(bytes[i]))
            str = str + " \(Int(bytes[i]))"
        }
        print(str)

        
    }
    //7d 7e 转译处理
    func dataTranslationHandle(data:Data) -> Data
    {
        
//        print(data as NSData)
        let bytes = [UInt8](data[1...(data.count-2)])
        var newBytes:[UInt8] = [];
        var isTranslation = false
        newBytes.append(0x7e)
        for byte in bytes {
            if isTranslation == true
            {
                isTranslation = false
                
                if byte != 0x01 &&  byte != 0x02
                {
                    newBytes.append(byte)
                }
            }else
            {
                
                if byte == 0x7e
                {
                    isTranslation = true
                    newBytes.append(0x7d)

                }else
                {
                    if byte == 0x7d
                    {
                        isTranslation = true

                    }
                    newBytes.append(byte)

                }
            }
//            print(byte)
        }
        newBytes.append(0x7e)
        
        return Data(newBytes)
    }
    
}
//MARK: 协议发送
extension BluetoothManager
{
    
    //获取电池
    func writeBattery()
    {
        if (self.aPeripheral != nil),(self.batteryWriteCharacteristic != nil)
        {
            self.aPeripheral?.readValue(for: self.batteryWriteCharacteristic!)
        }else
        {
            
        }
    }
    //获取版本号
    func writeGetDeviceVersion()
    {
        var bytes:[UInt8] = [];
        bytes.append(0x03) //标识符
        bytes.append(0x01)
        bytes.append(0x01)
        self.writeSetData(data: self.conversionData(bys: bytes))
    }
    //恢复出厂设置
    func writeResetSys()
    {
        var bytes:[UInt8] = [];
        bytes.append(0x06) //标识符
        bytes.append(0x01)
        bytes.append(0x01)
        self.writeSetData(data: self.conversionData(bys: bytes))
    }
    
    //设置自定义显示 page 1~6页
//    func writeShowDataSet(model:CustemShowDataModel?, _ count: Int = 0)
//    {
//        var bytes:[UInt8] = [];
//        bytes.append(0x1F) //标识符
//        bytes.append(0x01)//消息长度
//        bytes.append(UInt8(count))//总页数
//        bytes.append(UInt8(model?.modelIndex ?? "0") ?? 0)//当前页
//
//        var dataCount = 0
//        let dataArr = [UInt8(model?.firstValue ?? "0")!,UInt8(model?.secondValue ?? "0")!,UInt8(model?.thirdValue ?? "0")!,UInt8(model?.fourValue ?? "0")!,UInt8(model?.fifthValue ?? "0")!,UInt8(model?.sixValue ?? "0")!]
//        for dataByte in dataArr
//        {
//            bytes.append(dataByte)
//            dataCount += 1
////            if dataByte == 0x7e
////            {
////                bytes.append(0x02)
////                dataCount += 1
////            }
////            if dataByte == 0x7d
////            {
////                bytes.append(0x01)
////                dataCount += 1
////            }
//        }
//        bytes[1] = UInt8(dataCount+2)
//
//        self.writeSetData(data: self.conversionData(bys: bytes))
//    }
    
    //背光设置
//    func writeSyncbacklightSet(status: Int, delayStr: String, startTime: String, endTime: String)
//    {
//        var time = ""
//        if delayStr.contains(find: "分钟") {
//            let timeStr = (Int(delayStr.replacingOccurrences(of: "分钟", with: "")) ?? 1) * 60
//            time = "\(timeStr)"
//        }else {
//            time = delayStr.replacingOccurrences(of: "秒", with: "")
//        }
//
//        let delay = Int(time) ?? 5
//
//        var bytes:[UInt8] = [];
//        bytes.append(0x20) //标识符
//        bytes.append(0x01)//消息长度
//        bytes.append(contentsOf: self.dataConversion(occupy: 1, info: status))//背光状态(02永久关闭 03自定义时间)
//        bytes.append(contentsOf: self.dataConversion(occupy: 1, info: delay))//背光延迟关闭
//        let starArr = startTime.components(separatedBy: ":")
//        if let starHour = Int(starArr[0]), let starMinute = Int(starArr[1]) {
//            bytes.append(contentsOf: self.dataConversion(occupy: 1, info: starHour))//开始小时
//            bytes.append(contentsOf: self.dataConversion(occupy: 1, info: starMinute))//开始分钟
//        }
//
//        let endArr = endTime.components(separatedBy: ":")
//        if  let endHour = Int(endArr[0]), let endMinute = Int(endArr[1]) {
//            bytes.append(contentsOf: self.dataConversion(occupy: 1, info: endHour))//开始小时
//            bytes.append(contentsOf: self.dataConversion(occupy: 1, info: endMinute))//开始分钟
//        }
//
//        bytes[1] = UInt8(bytes.count-2)
//        self.writeSetData(data: self.conversionData(bys: bytes))
//    }
    
    //自动查询外设
    func writeAutomationPeripherals()
    {
        var bytes:[UInt8] = [];
        bytes.append(0x09) //标识符
        bytes.append(0x01)//消息长度
        bytes.append(0x01)
        self.writeSetData(data: self.conversionData(bys: bytes))
    }
    
    //获取已连接过的外设
    func writeGetPeripherals()
    {
        var bytes:[UInt8] = [];
        bytes.append(0x13) //标识符
        bytes.append(0x05)
        bytes.append(0x00)
        bytes.append(0x00)
        bytes.append(0x00)
        bytes.append(0x00)
        bytes.append(0x00)
        bytes[1] = UInt8(bytes.count-2)
        self.writeSetData(data: self.conversionData(bys: bytes))
    }
    
    //连接外设
//    func writeConnectPeripherals(model: PeripheralModel)
//    {
//        var bytes:[UInt8] = [];
//        bytes.append(0x11) //标识符
//        bytes.append(0x01)//消息长度
//
//        let type = Int(model.type) ?? 0//设备类型
//        bytes.append(contentsOf: self.dataConversion(occupy: 1, info: type))
//        let agreementType = Int(model.agreementType) ?? 0//设备协议类型
//        bytes.append(contentsOf: self.dataConversion(occupy: 1, info: agreementType))
//
//        let idData = model.deviceId.components(separatedBy: ":")
//        for idByte in idData {
//            bytes.append(contentsOf: self.dataConversion(occupy: 1, info: idByte.HexToDecimal()))
//        }
//
//        bytes[1] = UInt8(bytes.count-2)
//        self.writeSetData(data: self.conversionData(bys: bytes))
//    }
    
    //删除外设
//    func writeDeletePeripherals(model: PeripheralModel)
//    {
//        var bytes:[UInt8] = [];
//        bytes.append(0x12) //标识符
//        bytes.append(0x01)
//        let type = Int(model.type) ?? 0//设备类型
//        bytes.append(contentsOf: self.dataConversion(occupy: 1, info: type))
//        let agreementType = Int(model.agreementType) ?? 0//设备协议类型
//        bytes.append(contentsOf: self.dataConversion(occupy: 1, info: agreementType))
//
//        let idData = model.deviceId.components(separatedBy: ":")
//        for idByte in idData {
//            bytes.append(contentsOf: self.dataConversion(occupy: 1, info: idByte.HexToDecimal()))
//        }
//
//        bytes[1] = UInt8(bytes.count-2)
//        self.writeSetData(data: self.conversionData(bys: bytes))
//    }
    
    //获得设备当前设置
    func writeGetDeviceInfo(type:Int,_ totalPage: Int = 0,_ page:Int = 0) {
        var bytes:[UInt8] = []
        bytes.append(0x18) //标识符
        bytes.append(0x01)//消息长度
        bytes.append(contentsOf: self.dataConversion(occupy: 1, info: type))//配置类型
        bytes.append(contentsOf: self.dataConversion(occupy: 1, info: totalPage))//配置数量
        bytes.append(contentsOf: self.dataConversion(occupy: 1, info: page))//配置索引号
        bytes.append(0x00)//配置数据
        bytes[1] = UInt8(bytes.count-2)
        self.writeSetData(data: self.conversionData(bys: bytes))
    }
    
    
    //用户数据设置（身高体重）
    func writeUserInfo(weight:Int,height:Int)
    {
        
        let weightNum = weight * 10
        let heightNum = height * 10
        
        var bytes:[UInt8] = [];
        bytes.append(0x04) //标识符
        bytes.append(0x01)//消息长度
        bytes.append(0x01)//01 体重 02 身高
        bytes.append(contentsOf: self.dataConversion(occupy: 2, info: weightNum))
        bytes.append(0x02)
        bytes.append(contentsOf: self.dataConversion(occupy: 2, info: heightNum))
        bytes[1] = UInt8(bytes.count-2)
        self.writeSetData(data: self.conversionData(bys: bytes))
    }
    //轮径设置
    func writeGirthSet(girth:Int,fps:Int)
    {
        var bytes:[UInt8] = [];
        bytes.append(0x05) //标识符
        bytes.append(0x01)//消息长度
        bytes.append(0x01)//01 轮径 02 ftp
        bytes.append(contentsOf: self.dataConversion(occupy: 2, info: girth))
        bytes.append(0x02)
        bytes.append(contentsOf: self.dataConversion(occupy: 2, info: fps))
        bytes[1] = UInt8(bytes.count-2)
        self.writeSetData(data: self.conversionData(bys: bytes))
    }
    
    //海拔校正
    func writeElevationSet(elevation:Int)
    {
        var bytes:[UInt8] = [];
        bytes.append(0x02) //标识符
        bytes.append(0x01)//消息长度
        bytes.append(contentsOf: self.dataConversion(occupy: 2, info: elevation))
        bytes[1] = UInt8(bytes.count-2)
        self.writeSetData(data: self.conversionData(bys: bytes))
    }
    
    //功率校正
    func writePowerRevise()
    {
        var bytes:[UInt8] = [];
        bytes.append(0x08) //标识符
        bytes.append(0x01)//消息长度         bytes.append(0x01)//消息长度

        self.writeSetData(data: self.conversionData(bys: bytes))
    }
    //星历校正
//    func writeSyncEphemeris()
//    {
//
//        var bytes:[UInt8] = [];
//        bytes.append(0x19) //标识符
//        bytes.append(0x01)//消息长度         bytes.append(0x01)//消息长度
//        self.writeSetData(data: self.conversionData(bys: bytes))
////        Common.showLoading(title: "星历同步中")
////        Common.showLoading(title: "")
//        if CLLocationManager.authorizationStatus() == .denied {
//            Common.showToast(title: "星历同步失败，请在设置中打开定位权限")
//            return
//        }
//        BleEphemerisFileSend.shared.startConnected()
//
//    }
    
    //删除fit文件
    func writeDeleteFit(fitName:String)
    {
        var bytes:[UInt8] = [];
        bytes.append(0x07) //标识符
        bytes.append(0x01)//消息长度         bytes.append(0x01)//消息长度
        
        let name = fitName.replacingOccurrences(of: ".fit", with: "")
        
        let data = name.data(using: .utf8)!
        let dataByte = [UInt8](data)
        bytes.append(contentsOf: dataByte)
        bytes[1] = UInt8(bytes.count-2)
        self.writeSetData(data: self.conversionData(bys: bytes))
    }
    func dataConversion(occupy:Int,info:Int) ->[UInt8]
    {
        var bytes:[UInt8] = [];
        for i in stride(from: (occupy-1), through: 0, by: -1) { //逆序
            let by = UInt8((info >> (((occupy-1)-i)*8) & 0xff))
            bytes.append(by)
//            if by == 0x7e
//            {
//                bytes.append(0x02)
//            }
//            if by == 0x7d
//            {
//                bytes.append(0x01)
//            }
        }
        
        return bytes
    }
    //发送设置数据
    func writeSetData(data:Data)
    {
        print("发送设置数据:\((data as! NSData))")
        if self.bleState != .connected
        {
//            Common.showToast(title: "蓝牙已断开连接，请重新连接后再尝试")
            return
        }
        if (self.aPeripheral != nil),(self.setWriteCharacteristic != nil)
        {
            self.aPeripheral?.writeValue(data, for: self.setWriteCharacteristic!, type: .withoutResponse)
        }
    }
    //计算校验码
    func conversionData(bys:[UInt8] = []) ->Data
    {
        var bytes:[UInt8] = [];
        
        bytes.append(0x7e)

        for byte in bys {
            bytes.append(byte)
        }
        var crc = 0
        for i in 1...bytes.count-1
        {
            crc = crc^Int(bytes[i])
        }
        let crcByte = UInt8(crc & 0xFF)
        bytes.append(crcByte)
        bytes.append(0x7e)

        return self.sendDataTranslationHandle(data: Data(bytes))
    }
    //7d 7e 发送转译处理
    func sendDataTranslationHandle(data:Data) -> Data
    {
        let bytes = [UInt8](data[1...(data.count-2)])
        var newBytes:[UInt8] = [];
        newBytes.append(0x7e)
        for byte in bytes {
            if byte == 0x7e
            {
                newBytes.append(0x7d)
                newBytes.append(0x02)
            }else
            {
                newBytes.append(byte)
                if byte == 0x7d
                {
                    newBytes.append(0x01)
                }
            }
            
        }
        newBytes.append(0x7e)
        return Data(newBytes)
    }
}

//MARK: OTA
extension BluetoothManager {
    /**OTA数据写入*/
    func writeOTAData(data:Data)
    {
        print("发送OTA数据:\((data as NSData))")

        if self.bleState != .connected
        {
//            Common.showToast(title: "蓝牙已断开连接，请重新连接后再尝试")
            return
        }
        if (self.aPeripheral != nil),(self.otaWriteCharacteristic != nil)
        {
            self.aPeripheral?.writeValue(data, for: self.otaWriteCharacteristic!, type: .withResponse)
        }
    }
    
    //获取OTAmac地址
    func getOTAMacAddress()
    {
        var bytes:[UInt8] = [];
        bytes.append(0x14) //标识符
        bytes.append(0x01)//消息长度
        bytes.append(0x01)
        self.writeSetData(data: self.conversionData(bys: bytes))
    }
    
    //进入OTA模式
    func enterOtaMode()
    {
        var bytes:[UInt8] = [];
        bytes.append(0x01) //
        bytes.append(0x02)//
        bytes.append(0x03)
        self.writeOTAData(data: Data(bytes))
    }
    
}

//MARK: fit文件获取处理
extension BluetoothManager
{
    
    func writeGetAllFitFileName()
    {
        fitName = "filelist.txt"
        let str = "filelist.txt"
        let data = str.data(using: .utf8)!
        self.writeFitData(data: data)
    }
    func writeSyncFitData(name:String)
    {
        fitName = name

        let str = "TX"+name
        let data = str.data(using: .utf8)!
        self.writeFitData(data: data)
    }
    //发送C
    func writeWithC()
    {
        print("发送C -- 63")

        let str = "C"
        let data = str.data(using: .utf8)!
        self.writeFitData(data: data)
    }
    //发送ACK
    func writeWithACK()
    {
        print("发送ACK - 06")
        var bytes:[UInt8] = [];
        bytes.append(0x06)
        self.writeFitData(data: Data(bytes))
    }
    //发送NAK
    func writeWithNAK()
    {
        print("发送NAK")

        let str = "NAK"
        let data = str.data(using: .utf8)!
        self.writeFitData(data: data)
    }
    
    //发送fit数据
    func writeFitData(data:Data)
    {
        print("发送 长度：\(data.count) 数据:\((data as NSData)) " )
        if self.bleState != .connected
        {
//            Common.showToast(title: "蓝牙已断开连接，请重新连接后再尝试")
            return
        }
        if (self.aPeripheral != nil),(self.fitWriteCharacteristic != nil)
        {
            self.aPeripheral?.writeValue(data, for: self.fitWriteCharacteristic!, type: .withoutResponse)
        }
    }
    
    
    
//    func handleFitData(data:Data,tag:Int)
//    {
//        switch tag {
//        case 0x01:  //头部
////            print("-----:\((data as NSData))")
////            print(Data(bytes) as NSData)
//            let bytes = ([UInt8](data))[1...(data.count-3)]
//            let calcCrc = self.getCrcCodeFromFileData(data: Data(bytes))
//            let verifyCrc = Int((data[(data.count-2)...(data.count-1)]).hexadecimal().HexToDecimal())
//            //CRC校验
//            if calcCrc == verifyCrc
//            {
//                let byte = [UInt8](data)
////                let  by1 =  ((byte[13+3] << 24) & 0xff);
////                let  by2 =  ((byte[13+2] << 16) & 0x00ff);
////                let  by3 =  ((byte[13+1] << 8) & 0x0000ff);
////                let  by4 =  (byte[13] & 0x000000ff);
//
//                var sizeBytes:[UInt8] = [];
//                sizeBytes.append(byte[16])
//                sizeBytes.append(byte[15])
//                sizeBytes.append(byte[14])
//                sizeBytes.append(byte[13])
//                self.fitDataSize = bytesToInt(bytes: sizeBytes)
//                self.sumFitDataSize = self.fitDataSize
//
//                //保存数据有效长度
////                self.fitDataSize = Int((by4+by3+by2+by1))
//                print("有效数据长度：\(self.fitDataSize)")
//
//
//
//                self.fitData = Data()
//
//                self.writeWithACK()
//                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
//                    self.writeWithC()
//                }
//
//            }else
//            {
//                print("头部信息crc校验失败")
//            }
//            break
//        case 0x02:  //数据返回
//
////            crc检验
////            3...239
//            let bytes = data[3...(data.count-3)]
//            let calcCrc = self.getCrcCodeFromFileData(data: Data(bytes))
//            let verifyCrc = Int((data[(data.count-2)...(data.count-1)]).hexadecimal().HexToDecimal())
//            if calcCrc == verifyCrc
//            {
//                if self.fitName == "filelist.txt"
//                {
//                    if self.fitDataSize >= 24
//                    {
//                        let dataSize = data.count-5;
//                        if self.fitDataSize <= dataSize
//                        {
//                            if fitDataSize != 0
//                            {
//                                self.fitData.append(data[3...(self.fitDataSize+2)])
//                                self.fitDataSize = 0
//                            }
//                        }else
//                        {
//                            self.fitData.append(data[3...(dataSize+2)])
//                            self.fitDataSize = self.fitDataSize - dataSize
//                        }
//                        //所有拼接完成后开始数据解析
//                        if self.fitDataSize == 0
//                        {
//                            //每个名字是24个字节，小于24就是数据错误了，不需要处理直接下一步
//                            if self.fitData.count < 24
//                            {
//    //                            self.writeWithACK()
//                            }else
//                            {
//                                self.fitNameArray = []
//                                let k = self.fitData.count/24
////                                let fitBytes = [UInt8](self.fitData)
//
//                                for i in 0...(k-1)
//                                {
//                                    var fitNameBytes:[UInt8] = [];
//                                    for j in 0...17
//                                    {
//                                        print(self.fitData.count,(i*24)+j)
//                                        fitNameBytes.append(self.fitData[(i*24)+j])
//                                    }
//
////                                    let fitNameData = self.fitData[3+i*24...(22 + i*24)]
//                                    print(fitNameBytes)
//                                    if let str = String(data:Data(fitNameBytes),encoding:.utf8)
//                                    {
//                                        print(str)
//                                        self.fitNameArray.append(str)
//                                    }
//                                }
//                                self.delegate?.bleFitName(self.fitNameArray)
//                            }
//                        }
//                    }
//                }else
//                {
//                    if self.fitDataSize > 0
//                    {
//                        let dataSize = data.count-5;
//                        if self.fitDataSize <= dataSize
//                        {
//                            if fitDataSize != 0
//                            {
//                                self.fitData.append(data[3...(self.fitDataSize+2)])
//                                self.fitDataSize = 0
//                                self.delegate?.bleFitSync(self.fitName, progress: 1)
//                            }
//                        }else
//                        {
//                            self.fitData.append(data[3...(dataSize+2)])
//                            self.fitDataSize = self.fitDataSize - dataSize
//                            self.delegate?.bleFitSync(self.fitName, progress: Float(fitDataSize)/Float(sumFitDataSize))
//
//                        }
//                        print(self.fitDataSize)
//                        //所有拼接完成后开始数据解析
//                        if self.fitDataSize == 0
//                        {
//                            if self.fitData.count > 0
//                            {
////                                NSLog("这是fit所有数据%@", self.fitData as NSData)
//                                let array = FMDBManager.shared.selectList(model: FitModel()) { return FitModel() } as? [FitModel] ?? []
//                                var isFitExist = false
//                                for model in array
//                                {
//                                    if model.fitName == self.fitName
//                                    {
//                                        isFitExist = true
//                                    }
//                                }
//                                //存fit数据到数据库
//                                if isFitExist == false
//                                {
//                                    NSLog("储存fit所有数据:%@", self.fitData as NSData)
//                                    let model = FitModel()
//                                    model.fitData = self.fitData
//                                    model.fitName = self.fitName
//                                    FMDBManager.shared.insert(model: model)
//                                    self.fitData = Data()
//                                }
//                            }
//                        }
//                    }else {
//                        if self.sumFitDataSize == 0
//                        {
//                            Common.showToast(title: "同步失败")
//                        }
//
//                    }
//                }
//            }else
//            {
//                print("数据信息crc校验失败")
//            }
//            if ([UInt8](data))[1] == 0x08
//            {
//                self.writeWithACK()
////                if self.fitDataSize == 0
////                {
////                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
////                        self.writeWithC()
////                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
////                            self.writeWithNAK()
////                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
////                                self.writeWithACK()
////                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
////                                    self.writeWithC()
////                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
////                                        self.writeWithACK()
////                                    }
////                                }
////                            }
////                        }
////                    }
////                }
//            }
//
//
//            break
//        case 0x04:
//            if self.fitDataSize == 0
//            {
//                self.writeWithC()
//                self.writeWithNAK()
//                self.writeWithACK()
//                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
//                    self.writeWithC()
//                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
//                        self.writeWithACK()
//                    }
//                }
//            }
//            break
//        default:
//            break
//        }
//    }
    
    //FIXME: 获取文件的crc码
    private func getCrcCodeFromFileData(data:Data) ->Int{
        
        let bytes = [UInt8](data)

        var crc  = 0x0000; // 初始化
        for i:Int in 0..<bytes.count {
            crc = ((crc << 8) ^ tabCrc[((crc >> 8) ^ (0xff & Int(bytes[i])))]) & 0xFFFF;
        }
        return crc; // 取反
    }
    func bytesToInt(bytes: [UInt8]) -> Int {
            var value = 0
            for i in 0..<bytes.count {
                let shift = (bytes.count - 1 - i) * 8
                value += (Int(bytes[i]) & 0x000000FF) << shift
            }
            return value
        }
}

//MARK: 文件发送
extension BluetoothManager
{
    func startSendFile(data:Data)
    {
        self.sendFileData = data
        sendFileStatus = .star
        let str = "AGPS_DATA_Transfer"
        let data = str.data(using: .utf8)!
        self.writeFitData(data: data)
//        startSendSyncFileData()
//        sendFileHeader()
    }
    
    func sendFileHeader()
    {
        sendFileStatus = .star
        let str = "AGPS.txt"
        
        var bytes:[UInt8] = [];
        bytes.append(0x01) //标识符
        bytes.append(0x01) //长度
        bytes.append(0x00) //长度 这个协议这个字节基本上不会用到

        bytes.append(contentsOf: self.dataConversion(occupy: 4, info: self.sendFileData.count))
        let data = str.data(using: .utf8)!
        let nameBytes = [UInt8](data)
        bytes.append(contentsOf: nameBytes)//文件名
        bytes[1] = UInt8(bytes.count-3)
        self.sendFileStatus = .header
//        let aaa = self.sendFileConversionData(bys: bytes) as NSData
//        print("\(aaa)")
        self.writeFitData(data: self.sendFileConversionData(bys: bytes))
    }
    
    func startSendSyncFileData()
    {
        if self.sendFileData.count > 150
        {
            var bytes:[UInt8] = [];
            bytes.append(0x02) //标识符
            bytes.append(0x00) //长度
            bytes.append(0x00) //长度
            let nsData = self.sendFileData as NSData
            let dataBytes = [UInt8](nsData.subdata(with: NSRange(location: 0, length: 150)) as Data)
            bytes.append(contentsOf: dataBytes)
            bytes[1] = UInt8((bytes.count-3) & 0xff)

            bytes[2] = UInt8((bytes.count-3) >> 8 & 0xff)
            self.sendFileStatus = .file
            self.sendFileData.removeFirst(150)
            let sendData = self.sendFileConversionData(bys: bytes)
            self.againFileData = sendData
            self.writeFitData(data: sendData)
        }else
        {
            var bytes:[UInt8] = [];
            bytes.append(0x03) //标识符
            bytes.append(0x00) //长度
            bytes.append(0x00) //长度
            let dataBytes = [UInt8](self.sendFileData)
            bytes.append(contentsOf: dataBytes)
            bytes[1] = UInt8((bytes.count-3) & 0xff)
            bytes[2] = UInt8((bytes.count-3) >> 8 & 0xff)
            self.sendFileStatus = .last
            self.sendFileData.removeAll()
            let sendData = self.sendFileConversionData(bys: bytes)
            self.againFileData = sendData
            self.writeFitData(data: sendData)
        }
    }
    func sendSyncFileDataEnd()
    {
        var bytes:[UInt8] = [];
        bytes.append(0x04) //标识符
        sendFileStatus = .end
        self.writeFitData(data: Data(bytes))
    }
    func sendFileConversionData(bys:[UInt8] = []) ->Data
    {
        var bytes:[UInt8] = [];
        for byte in bys {
            bytes.append(byte)
        }

        var crc  = 0x0000; // 初始化
        for i:Int in 1..<bytes.count {
            crc = ((crc << 8) ^ tabCrc[((crc >> 8) ^ (0xff & Int(bytes[i])))]) & 0xFFFF;
        }
//        4a 9c  b6 ac fd39
        let bas = self.dataConversion(occupy: 2, info: crc)
        let a = (UInt8(crc >> 8 & 0xff))
        let b = (UInt8(crc & 0xff))
//        bytes.append(contentsOf: )
        bytes.append(a)
        bytes.append(b)
        return Data(bytes)
    }
    
}
extension String{
   func HexToDecimal() -> Int {
       var sum:Int = 0
       if let str = self.uppercased() as? String
       {
           for i in str.utf8 {
               //0-9：从48开始
               sum = sum * 16 + Int(i) - 48
               //A-Z：从65开始
                if i >= 65 {
                    sum -= 7
                }
            }
        }
        return sum
    }
    
 }
extension Data {

    /// Create hexadecimal string representation of `Data` object.
    ///
    /// - returns: `String` representation of this `Data` object.

    func hexadecimal() -> String {
        return map { String(format: "%02x", $0) }
            .joined(separator: "")
    }
}

//
protocol BluetoothDelegate:NSObjectProtocol{
    func blePeripherals( _ list:[CBPeripheral]);
    func bleRespond(_ state: ZeeBleRespondResult, info: BluetoothModel?);
    func bleManagerDidUpdateState( _ state:ZeeBleState);
    
    func bleFitName( _ list:[String]);
    func bleFitSync( _ name:String,progress:Float);
    func handlePeripheralData(_ data:Data)
    func sendFileStatus(_ status:ZeeBleFileSendState)

   
//    func otaUpdateProgress(_ progress:Int)
//    func otaDidUpdateState(_ state:OTAUpgradeState)
    
}
//MARK: 蓝牙状态
public enum ZeeBleState : Int {
    case unauthorized
    case poweredOff
    case connected
    case connecting
    case passwordFail
    case connectFail
    
}

//MARK: 蓝牙发送文件状态
public enum ZeeBleFileSendState : Int {
    case normal
    case star
    case header
    case file
    case last
    case end
}
//MARK: 协议(代理)
public enum ZeeBleRespondResult : Int {
    case elevation = 0x02
    case version = 0x03
    case userinfo = 0x04
    case girth = 0x05
    case resetSys = 0x06
    case power = 0x08
    case custom = 0x1f
    case mac = 0x014
    case ephemeris = 0x019
    case backlight = 0x20
    case batteryInfo = 0x180F
    case error = 0xe0
    case otamodel = 0x200101
    case deviceInfo = 0x18
    
}


//MARK: 协议(代理)
public enum FitStatus : Int {
    case star = 0x00 //开始获取
    case header = 0x01 //返回头部
    case userinfo = 0x02
}
let tabCrc = [0x0000, 0x1021, 0x2042, 0x3063, 0x4084, 0x50A5, 0x60C6, 0x70E7,
              0x8108, 0x9129, 0xA14A, 0xB16B, 0xC18C, 0xD1AD, 0xE1CE, 0xF1EF,
              0x1231, 0x0210, 0x3273, 0x2252, 0x52B5, 0x4294, 0x72F7, 0x62D6,
              0x9339, 0x8318, 0xB37B, 0xA35A, 0xD3BD, 0xC39C, 0xF3FF, 0xE3DE,
              0x2462, 0x3443, 0x0420, 0x1401, 0x64E6, 0x74C7, 0x44A4, 0x5485,
              0xA56A, 0xB54B, 0x8528, 0x9509, 0xE5EE, 0xF5CF, 0xC5AC, 0xD58D,
              0x3653, 0x2672, 0x1611, 0x0630, 0x76D7, 0x66F6, 0x5695, 0x46B4,
              0xB75B, 0xA77A, 0x9719, 0x8738, 0xF7DF, 0xE7FE, 0xD79D, 0xC7BC,
              0x48C4, 0x58E5, 0x6886, 0x78A7, 0x0840, 0x1861, 0x2802, 0x3823,
              0xC9CC, 0xD9ED, 0xE98E, 0xF9AF, 0x8948, 0x9969, 0xA90A, 0xB92B,
              0x5AF5, 0x4AD4, 0x7AB7, 0x6A96, 0x1A71, 0x0A50, 0x3A33, 0x2A12,
              0xDBFD, 0xCBDC, 0xFBBF, 0xEB9E, 0x9B79, 0x8B58, 0xBB3B, 0xAB1A,
              0x6CA6, 0x7C87, 0x4CE4, 0x5CC5, 0x2C22, 0x3C03, 0x0C60, 0x1C41,
              0xEDAE, 0xFD8F, 0xCDEC, 0xDDCD, 0xAD2A, 0xBD0B, 0x8D68, 0x9D49,
              0x7E97, 0x6EB6, 0x5ED5, 0x4EF4, 0x3E13, 0x2E32, 0x1E51, 0x0E70,
              0xFF9F, 0xEFBE, 0xDFDD, 0xCFFC, 0xBF1B, 0xAF3A, 0x9F59, 0x8F78,
              0x9188, 0x81A9, 0xB1CA, 0xA1EB, 0xD10C, 0xC12D, 0xF14E, 0xE16F,
              0x1080, 0x00A1, 0x30C2, 0x20E3, 0x5004, 0x4025, 0x7046, 0x6067,
              0x83B9, 0x9398, 0xA3FB, 0xB3DA, 0xC33D, 0xD31C, 0xE37F, 0xF35E,
              0x02B1, 0x1290, 0x22F3, 0x32D2, 0x4235, 0x5214, 0x6277, 0x7256,
              0xB5EA, 0xA5CB, 0x95A8, 0x8589, 0xF56E, 0xE54F, 0xD52C, 0xC50D,
              0x34E2, 0x24C3, 0x14A0, 0x0481, 0x7466, 0x6447, 0x5424, 0x4405,
              0xA7DB, 0xB7FA, 0x8799, 0x97B8, 0xE75F, 0xF77E, 0xC71D, 0xD73C,
              0x26D3, 0x36F2, 0x0691, 0x16B0, 0x6657, 0x7676, 0x4615, 0x5634,
              0xD94C, 0xC96D, 0xF90E, 0xE92F, 0x99C8, 0x89E9, 0xB98A, 0xA9AB,
              0x5844, 0x4865, 0x7806, 0x6827, 0x18C0, 0x08E1, 0x3882, 0x28A3,
              0xCB7D, 0xDB5C, 0xEB3F, 0xFB1E, 0x8BF9, 0x9BD8, 0xABBB, 0xBB9A,
              0x4A75, 0x5A54, 0x6A37, 0x7A16, 0x0AF1, 0x1AD0, 0x2AB3, 0x3A92,
              0xFD2E, 0xED0F, 0xDD6C, 0xCD4D, 0xBDAA, 0xAD8B, 0x9DE8, 0x8DC9,
              0x7C26, 0x6C07, 0x5C64, 0x4C45, 0x3CA2, 0x2C83, 0x1CE0, 0x0CC1,
              0xEF1F, 0xFF3E, 0xCF5D, 0xDF7C, 0xAF9B, 0xBFBA, 0x8FD9, 0x9FF8,
              0x6E17, 0x7E36, 0x4E55, 0x5E74, 0x2E93, 0x3EB2, 0x0ED1, 0x1EF0];
