//
//  ViewController.swift
//  逃逸闭包demo
//
//  Created by luhong on 2022/4/19.
//

import UIKit
import CoreBluetooth

class ViewController: UIViewController {

    
    var peripheral:CBPeripheral?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
//        getData { (data) in
//            print("闭包结果返回--\(data)--\(Thread.current)")
//        }
        
//        handleData { (data) in
//            print("闭包结果返回--\(data)--\(Thread.current)")
//        }
        
        
        
    }
    
    @IBAction func nextButton(_ sender: Any) {
        print("进入下一页")
        
        if BluetoothManager.shared.aPeripheral == nil
        {
            BluetoothManager.shared.startBleService()
        }
        if peripheral != nil
        {
            BluetoothManager.shared.connectPeripheral(peripheral: peripheral!)
        }
        
//        let nextVC = NextViewController()
//
//        self.present(nextVC, animated: true) {
//
//        }
        
    }
    func getData(closure: @escaping (Any) ->Void){
        print("函数开始执行--\(Thread.current)")
        DispatchQueue.global().async {
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now()+2, execute: {
                
                print("执行了闭包----\(Thread.current)")
                closure("235")
            })
           
        }
        print("函数执行结束----\(Thread.current)")
        
        
    }
    
    func handleData(closure:(Any)->()){
        print("函数开始执行--\(Thread.current)")
        print("执行了闭包----\(Thread.current)")
        closure("80000")
        print("函数执行结束----\(Thread.current)")
    }
    
    func delay(_ millisecond: Double) {
        var current = Date.timeIntervalSinceReferenceDate * 1000

        let end = Date.timeIntervalSinceReferenceDate * 1000 + millisecond

        repeat {
            Thread.sleep(forTimeInterval: 0.00002)
            current = Date.timeIntervalSinceReferenceDate * 1000
        } while current < end
    }

    func delay(_ delayTime: TimeInterval, _ qosClass: DispatchQoS.QoSClass? = nil, _ closure: @escaping () -> Void) {
        let dispatchQueue = qosClass != nil ? DispatchQueue.global(qos: qosClass!) : .main
        dispatchQueue.asyncAfter(deadline: DispatchTime.now() + delayTime, execute: closure)
    }


}

