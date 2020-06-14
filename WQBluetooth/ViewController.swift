//
//  ViewController.swift
//  WQBluetooth
//
//  Created by chenweiqiang on 2020/6/5.
//  Copyright © 2020 chenweiqiang. All rights reserved.
//

import UIKit
import CoreBluetooth

//前面可加0x可不加
let heartRateServiceUUID = CBUUID(string: "201D")
let controlPointCharacteristicUUID = CBUUID(string: "2A39")//可写特征
let sensorLocationCharacteristicUUID = CBUUID(string: "2A38")//可读特征
let measurementCharacteristicUUID = CBUUID(string: "2A37")//可通知特征

class ViewController: UIViewController {

    @IBOutlet weak var controlPointTextField: UITextField!
    @IBOutlet weak var sensorLocationTextField: UITextField!
    @IBOutlet weak var heartRateTextField: UITextField!
    
    var centralManager: CBCentralManager!
    var heartRatePeripheral: CBPeripheral!
    var controlPointCharacteristic: CBCharacteristic?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        //创建中心设备管理器--立即调用centralManagerDidUpdateState
        centralManager = CBCentralManager(delegate: self, queue: nil)
        
        // Do any additional setup after loading the view.
    }

    //动态的给外设写入数据--给外设传数据
    @IBAction func write(_ sender: Any) {
        guard let controlPointCharacteristic = controlPointCharacteristic else{return}
        heartRatePeripheral.writeValue(controlPointTextField.text!.data(using: .utf8)!, for: controlPointCharacteristic, type: .withResponse)
    }
    

}
extension ViewController: CBCentralManagerDelegate{
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        //确保本中心设备支持蓝牙低能耗（BLE）并开启时才能继续操作
        switch central.state{
        case .unknown:
            print("未知")
        case .resetting:
            print("蓝牙重置中")
        case .unsupported:
            print("本机不支持BLE")
        case .unauthorized:
            print("未授权")
        case .poweredOff:
            print("蓝牙未开启")
        case .poweredOn:
            print("蓝牙开启")
            //扫描正在广播的外设--每当发现外设时都会调用didDiscover peripheral方法
            //withServices:[xx]--只扫描正在广播xx服务的外设，若nil则扫描所有外设（费电，不推荐）
//            let uuid = "8C27293D-B88C-4A2D-8EF3-736532F1CAD4"
//            central.scanForPeripherals(withServices: [heartRateServiceUUID])
            central.scanForPeripherals(withServices: [heartRateServiceUUID], options: [CBCentralManagerScanOptionAllowDuplicatesKey:false])
        @unknown default:
            print("来自未来的错误")
        }
    }
    
    //发现外设
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        
        //如果想连接这个外设的话，一定要赋给某个变量（弄了个强引用）
        //不然系统不会把当前发现的这个外设分配给下面钩子函数里面的peripheral参数
        heartRatePeripheral = peripheral
        
        //一旦找到想要连接的外设，就停止扫描其他设备-省电
        central.stopScan()
        
        //连接外设--若连接成功则调用didConnect peripheral方法
        central.connect(peripheral)
        
    }
   
//    //连接成功
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        //即将要使用peripheral的delegate方法，所以先委托self
        peripheral.delegate = self
        //寻找服务--立即（由已连接上的peripheral来）调用didDiscoverServices方法
        //指定服务而不写nil，理由同上
        peripheral.discoverServices([heartRateServiceUUID])
    }
    //连接失败
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("连接失败")
    }
    //连接断开
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        central.connect(peripheral)//重连
    }
}
extension ViewController: CBPeripheralDelegate{
    
    //已发现服务（或发现失败）
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error{
            print("没找到服务，原因是：\(error.localizedDescription)")
        }
        guard let service = peripheral.services?.first else{return}
        //寻找特征--立即调用didDiscoverCharacteristicsFor方法
        peripheral.discoverCharacteristics([
            controlPointCharacteristicUUID,
            sensorLocationCharacteristicUUID,
            measurementCharacteristicUUID
            ], for: service)
    }
    
    //已发现特征（或发现失败）---重要方法
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error{
            print("没找到特征，原因是：\(error.localizedDescription)")
        }
        guard let characteristics = service.characteristics else{return}
        for characteristic in characteristics{
            //type--若需要反馈，则调用didWriteValueForCharacteristic方法
            if characteristic.properties.contains(.write){
                peripheral.writeValue("100".data(using: .utf8)!, for: characteristic, type: .withResponse)
                controlPointCharacteristic = characteristic
            }
            if characteristic.properties.contains(.read){
                //读取外设的数据(其实就是读取外设里某个特征的值value)--立即调用didUpdateValueFor
                //若读取成功则可通过characteristic.value取出值
                //适合读取静态值
                peripheral.readValue(for: characteristic)
            }
            if characteristic.properties.contains(.notify){
                //订阅外设的某个数据（某个特征的值）--达到实时更新数据的目的
                //订阅后会先调用didUpdateNotificationStateFor
                //若订阅成功，则每当特征值变化时都会（若true）调用didUpdateValueFor
                //适合读动态值--一直在变化的值--如：心率
                peripheral.setNotifyValue(true, for: characteristic)
            }
            //这里可以继续发现特征下面的描述--也可不做for循环而单独指定某个特征
            //peripheral.discoverDescriptors(for: characteristic)
            //之后会立即调用didDiscoverDescriptorsFor，可在里面获取描述值
        }
    }
    
    //写入时指定tpye为withResponse时会调用--写入成功与否的反馈
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error{
            print("写入失败，原因是：\(error.localizedDescription)")
            return
        }
        print("写入成功")
    }
    //订阅状态
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error{
            print("订阅失败，原因是：\(error.localizedDescription)")
        }
    }
    
    //特征值已更新--1.读取特征值时调用 2.订阅特征值成功后，每当这个值变化时都会调用
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error{
            print("读取失败，原因是：\(error.localizedDescription)")
            return
        }
        //1.读取成功,2.订阅成功后值变化时---会执行以下代码
        switch characteristic.uuid {
        case sensorLocationCharacteristicUUID:
            print("characteristic==\(String(data: characteristic.value!, encoding: .utf8) ?? "空数据")")
            sensorLocationTextField.text = String(data: characteristic.value!, encoding: .utf8)
        case measurementCharacteristicUUID:
            guard let heartRate = Int(String(data: characteristic.value!, encoding: .utf8)!)else{return}
            print("heartRate==\(heartRate)")
            heartRateTextField.text = "\(heartRate)"
        default:
            break
        }
    }

}
