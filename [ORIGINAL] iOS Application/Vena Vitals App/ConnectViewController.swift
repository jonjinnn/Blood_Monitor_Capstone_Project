//
//  ConnectViewController.swift
//  Vena Vitals App
//
//  Created by Felicia Hou on 8/3/20.
//  Copyright © 2020. All rights reserved.
//

import UIKit
import CoreBluetooth



class Device{
    var name: String?

    init(name: String) {
        self.name = name
    }
}

class ConnectViewController: UIViewController, UITableViewDataSource, UITableViewDelegate{


    var devices = [Device]()
    var centralManager: CBCentralManager!

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var recordButton: UIButton!


    override func viewDidLoad() {
        super.viewDidLoad()
        

        recordButton.isEnabled = false
        recordButton.alpha = 0.5

        tableView.dataSource = self
        tableView.delegate = self
        


            //    loadSampleDevices()
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
         return devices.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
         let cell = tableView.dequeueReusableCell(withIdentifier: "cellReuseIdentifier") as! ConnectTableViewCell //1.

        let text = devices[indexPath.row].name //2.

         cell.deviceLabel?.text = text //3.

         return cell //4.
    }


    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {

//         let alertController = UIAlertController(title: "Hint", message: "You have selected row \(indexPath.row).", preferredStyle: .alert)
//
//         let alertAction = UIAlertAction(title: "Ok", style: .cancel, handler: nil)
//
//         alertController.addAction(alertAction)
//
//         present(alertController, animated: true, completion: nil)
//
    }





    //MARK: Private Methods

//    private func loadSampleDevices() {
//        guard let device1: Device = Device(name: "Device 1") else {
//            fatalError("Unable to instantiate Device")
//        }
//
//        devices += [device1]
//    }

}
