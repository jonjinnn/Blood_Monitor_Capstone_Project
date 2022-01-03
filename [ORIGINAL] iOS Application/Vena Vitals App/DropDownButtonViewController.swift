//
//  DropDownButtonController.swift
//  Vena Vitals App
//
//  Created by Felicia Hou on 5/23/20.
//  Copyright © 2020 VenaVitals. All rights reserved.
//

import UIKit
import CoreBluetooth

public var selection = "5 SEC"
let servicesUUIDString = "71EE1400-1232-11EA-8D71-362B9E155667"
let servicesUUID = CBUUID(string : servicesUUIDString)
var globalCentralManager: CBCentralManager!
var globalBPPeripheral: CBPeripheral!
var dac1ControlCharacteristic : CBCharacteristic?
var cap1Characteristic : CBCharacteristic?
var cap2Characteristic : CBCharacteristic?





class DropDownButtonViewController: UIViewController, CBPeripheralDelegate {

    @IBOutlet weak var recordButton: UIButton!
    
    var alertController: UIAlertController?
    var alertTimer: Timer?
    var remainingTime = 0
    var baseMessage: String?
    
    
    override func viewWillAppear(_ animated: Bool) {
        UIApplication.shared.isIdleTimerDisabled = false
        super.viewWillAppear(animated)

       }
      
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationController?.navigationBar.shadowImage = UIImage()
        
        recordButton.isEnabled = false
        recordButton.alpha = 0.5
        
        //BLE Central init
        let centralManager = CBCentralManager(delegate: self, queue: nil)
        globalCentralManager = centralManager
        if(globalBPPeripheral != nil)
        {
            globalCentralManager.cancelPeripheralConnection(globalBPPeripheral!)
        }

        // Do any additional setup after loading the view.
        
//        button = dropDownBtn.init(frame: CGRect(x: 0, y: 0, width: 0, height: 0))
//        button.setTitle("5 SEC", for: .normal)
//        button.setTitleColor(UIColor.black, for: .normal)
//        //button.backgroundColor = .clear
//      //  button.layer.cornerRadius = 10
//        button.clipsToBounds = true
//        button.translatesAutoresizingMaskIntoConstraints = false
//
//        self.view.addSubview(button)
//
//       // button.centerXAnchor.constraint(equalTo: self.view.centerXAnchor, constant: -100).isActive = true
//      //  button.centerYAnchor.constraint(equalTo: self.view.centerYAnchor, constant: -300).isActive = true
//        button.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: 50).isActive = true
//        button.topAnchor.constraint(equalTo:self.view.topAnchor, constant: 80).isActive = true
////        button.centerXAnchor.constraint(equalTo: self.view.centerXAnchor).isActive = true
//
////        button.centerYAnchor.constraint(equalTo: self.view.centerYAnchor).isActive = true
//
//        button.widthAnchor.constraint(equalToConstant: 120).isActive = true
//        button.heightAnchor.constraint(equalToConstant: 40).isActive = true
//
//        button.dropView.dropDownOptions = ["5 SEC", "10 SEC", "20 SEC", "30 SEC", "5 MIN"]

    }
    
    
    override func viewDidDisappear(_ animated: Bool) {
        UIApplication.shared.isIdleTimerDisabled = true
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else {return}
        for service in services{
            if(service.uuid == servicesUUID)
            {
                peripheral.discoverCharacteristics(nil, for: service)
            }
        }
      }

      func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService,
                      error: Error?) {
        guard let characteristics = service.characteristics else { return }

        for characteristic in characteristics {
           // print(characteristic)
          if characteristic.properties.contains(.notify){
            print("\(characteristic.uuid): properties contains .notify")
            if(characteristic.uuid == CAP1_CHAR_UUID)
            {
                cap1Characteristic = characteristic
            }
            else{
                cap2Characteristic = characteristic
            }
          }
            else if(characteristic.uuid == DAC1_CHAR_UUID)
          {
            print("dac1 detected")
            dac1ControlCharacteristic = characteristic
            } //only 1 DAC control is implemented as the other is useless
        }
      }
    
    
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}

protocol dropDownProtocol {
    func dropDownPressed(string : String)
}

class dropDownBtn: UIButton, dropDownProtocol{
   
    func dropDownPressed(string: String) {
        self.setTitle(string, for: .normal)
        self.dismissDropDown()
    }
    
    
    var dropView = dropDownView()
    
    var height = NSLayoutConstraint()

    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        self.backgroundColor = hexStringToUIColor(hex: "#e5e5e5")
        
        
        dropView = dropDownView.init(frame: CGRect.init(x: 0, y: 0, width: 0, height: 0))
        
        dropView.delegate = self
        
        dropView.translatesAutoresizingMaskIntoConstraints = false
        
    }
    
    override func didMoveToSuperview() {
        self.superview?.addSubview(dropView)
        

        
        /*/ change this depending on how want dropview to appear */
        self.superview?.bringSubviewToFront(dropView)
        

        height = dropView.heightAnchor.constraint(equalToConstant: 0)
    }
    
    var isOpen = false
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        
        dropView.topAnchor.constraint(equalTo: self.bottomAnchor).isActive = true
        dropView.centerXAnchor.constraint(equalTo: self.centerXAnchor).isActive = true
        dropView.widthAnchor.constraint(equalTo: self.widthAnchor).isActive = true
        
        if isOpen == false {
            
            isOpen = true
            
            NSLayoutConstraint.deactivate([self.height])
            
            if self.dropView.tableView.contentSize.height > 125{
                self.height.constant = 125
            } else {
                self.height.constant = self.dropView.tableView.contentSize.height
            }
            
            NSLayoutConstraint.activate([self.height])
            
            
            UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.5, initialSpringVelocity: 0.5, options: .curveEaseInOut, animations: {
                self.dropView.layoutIfNeeded()
                self.dropView.center.y += self.dropView.frame.height / 2

            }, completion: nil)
            
        } else {
            isOpen = false
            
            NSLayoutConstraint.deactivate([self.height])
                      self.height.constant = 0
                      NSLayoutConstraint.activate([self.height])
                      
                      
                      UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.5, initialSpringVelocity: 0.5, options: .curveEaseInOut, animations: {
                        self.dropView.center.y -= self.dropView.frame.height / 2
                        self.dropView.layoutIfNeeded()
                      }, completion: nil)
        }
    }
    
    func dismissDropDown() {
          isOpen = false
        NSLayoutConstraint.deactivate([self.height])
                             self.height.constant = 0
                             NSLayoutConstraint.activate([self.height])
                             
                             
                             UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.5, initialSpringVelocity: 0.5, options: .curveEaseInOut, animations: {
                               self.dropView.center.y -= self.dropView.frame.height / 2
                               self.dropView.layoutIfNeeded()
                             }, completion: nil)
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}

class dropDownView: UIView, UITableViewDelegate, UITableViewDataSource{
    
   // var selection: String = ""
    
    var dropDownOptions = [String]()
    
    var tableView = UITableView()
    
    var delegate : dropDownProtocol!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        tableView.backgroundColor = hexStringToUIColor(hex: "#e5e5e5")
        self.backgroundColor = hexStringToUIColor(hex: "#e5e5e5")
        
        tableView.delegate = self
        tableView.dataSource = self
        
        tableView.translatesAutoresizingMaskIntoConstraints = false
        
        self.addSubview(tableView)
        
        tableView.leftAnchor.constraint(equalTo: self.leftAnchor).isActive = true
        tableView.topAnchor.constraint(equalTo: self.topAnchor).isActive = true
        tableView.rightAnchor.constraint(equalTo: self.rightAnchor).isActive = true
        tableView.bottomAnchor.constraint(equalTo: self.bottomAnchor).isActive = true

        
    }
    
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dropDownOptions.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell = UITableViewCell()
        
        cell.textLabel?.text = dropDownOptions[indexPath.row]
        cell.backgroundColor = hexStringToUIColor(hex: "#e5e5e5")
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
//       pass along selected item from drop down menu
        
        self.delegate.dropDownPressed(string: dropDownOptions[indexPath.row])
        self.tableView.deselectRow(at: indexPath, animated: true)
        selection = dropDownOptions[indexPath.row]
     //   selection = dropDownOptions[indexPath.row]
        //print(selection)
    }
}

func hexStringToUIColor (hex:String) -> UIColor {
        var cString:String = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        if (cString.hasPrefix("#")) {
            cString.remove(at: cString.startIndex)
        }

        if ((cString.count) != 6) {
            return UIColor.gray
        }

        var rgbValue:UInt64 = 0
        Scanner(string: cString).scanHexInt64(&rgbValue)

        return UIColor(
            red: CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0,
            green: CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0,
            blue: CGFloat(rgbValue & 0x0000FF) / 255.0,
            alpha: CGFloat(1.0)
        )
    }


//MARK: BLE Code
extension DropDownButtonViewController: CBCentralManagerDelegate {


    
    func createAlert (title:String, message:String){
        let alert = UIAlertController(title: title, message: message, preferredStyle: UIAlertController.Style.alert)

        alert.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: { (action) in alert.dismiss(animated: true, completion: nil)}))

        self.present(alert, animated: true, completion: nil)
    }
    
    func showAlertMsg(title: String, message: String, time: Int) {

        guard (self.alertController == nil) else {
            print("Alert already displayed")
            return
        }

        self.baseMessage = message
        self.remainingTime = time

        self.alertController = UIAlertController(title: title, message: self.alertMessage(), preferredStyle: .alert)

        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { (action) in
            print("Alert was cancelled")
            self.alertController=nil;
            self.alertTimer?.invalidate()
            self.alertTimer=nil
        }

        self.alertController!.addAction(cancelAction)

        self.alertTimer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(DropDownButtonViewController.countDown), userInfo: nil, repeats: true)

        self.present(self.alertController!, animated: true, completion: nil)
    }
    
     @objc func countDown() {

            self.remainingTime -= 1
            if (self.remainingTime < 1) {
                self.alertTimer?.invalidate()
                self.alertTimer = nil
                self.alertController!.dismiss(animated: true, completion: {
                    self.alertController = nil
                    self.recordButton.isEnabled = true
                    self.recordButton.alpha = 1.0
                })
            } else {
                self.alertController!.message = self.alertMessage()
            }

        }

        func alertMessage() -> String {
            var message=""
            if let baseMessage=self.baseMessage {
                message=baseMessage+" "
            }
            return(message+"\(self.remainingTime)")
        }

  func centralManagerDidUpdateState(_ central: CBCentralManager) {
    switch central.state {
      case .unknown:
        createAlert(title: "Uh oh!", message: "The Bluetooth Device is not connected, please try again!")
        print("central.state is .unknown")
      case .resetting:
        createAlert(title: "Uh oh!", message: "The Bluetooth Device is not connected, please try again!")
        print("central.state is .resetting")
      case .unsupported:
        createAlert(title: "Uh oh!", message: "The Bluetooth Device is unsupported, please try again!")
        print("central.state is .unsupported")
      case .unauthorized:
        createAlert(title: "Uh oh!", message: "The Bluetooth Device is unauthorized, please try again!")
        print("central.state is .unauthorized")
      case .poweredOff:
        createAlert(title: "Uh oh!", message: "The Bluetooth Device is not powered on, please try again!")
        print("central.state is .poweredOff")
      case .poweredOn:
        print("central.state is .poweredOn")
        globalCentralManager.scanForPeripherals(withServices: nil)
    }

  }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        print("updated")
    }
    
func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                  advertisementData: [String: Any], rssi RSSI: NSNumber) {
  print(peripheral.name ?? "un-named")
  if(peripheral.name == "DRGcBP") //DRGcBP is the name of the BLE(PCB), so this block is to check if the peripheral at hand is the PCB and connect to it.
  {
    print("detected drgcbp")
    globalBPPeripheral = peripheral
    globalBPPeripheral.delegate = self
    globalCentralManager.stopScan()
    globalCentralManager.connect(globalBPPeripheral!)
  }
}

func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
    //createAlert(title: "Yay!", message: "The Bluetooth Device is connected!")
    self.showAlertMsg(title: "Connected!", message: "Begin recording in", time: 4)

    print("Connected!")
    print("looking for services")
    print(globalBPPeripheral!)
    globalBPPeripheral.discoverServices(nil)
  }
    


func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
    
    // Create the alert controller
    let alertController = UIAlertController(title: "Uh oh!", message: "The Bluetooth Device disconnected, redirecting to Connection Page", preferredStyle: .alert)

        // Create the actions
    let okAction = UIAlertAction(title: "OK", style: UIAlertAction.Style.default) {

        UIAlertAction in
        let secondViewController = self.storyboard?.instantiateViewController(withIdentifier: "DropDownButtonViewController") as! DropDownButtonViewController
        self.navigationController?.pushViewController(secondViewController, animated: true)
            NSLog("OK Pressed")
        }

        // Add the actions
        alertController.addAction(okAction)

        // Present the controller
    self.present(alertController, animated: true, completion: nil)
 // createAlert(title: "Uh oh!", message: "The Bluetooth Device disconnected, please try again!")
    recordButton.isEnabled = false
    recordButton.alpha = 0.5
    print("disconnected")
    
}




}


