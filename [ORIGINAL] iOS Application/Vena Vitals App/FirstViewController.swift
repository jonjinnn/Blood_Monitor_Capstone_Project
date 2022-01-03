//
//  FirstViewController.swift
//  Vena Vitals App
//
//  Created by Tiffany Tran on 5/8/20.
//  Copyright © 2020 Tiffany Tran. All rights reserved.
//

import UIKit
import CoreXLSX
import Charts
import TinyConstraints
import CoreBluetooth

//BLE CONSTANTS
let CAP1_CHAR_UUID = CBUUID(string: "71ee1401-1232-11ea-8d71-362b9e155667")
let CAP2_CHAR_UUID = CBUUID(string: "71ee1402-1232-11ea-8d71-362b9e155667")
let DAC1_CHAR_UUID = CBUUID(string: "71ee1406-1232-11ea-8d71-362b9e155667")
let DAC2_CHAR_UUID = CBUUID(string: "71ee1407-1232-11ea-8d71-362b9e155667")
let CLK_FREQ = 32768.0  // 32.768kHz
let CLK_PERIOD:Double = 1/CLK_FREQ
var dacControl = NSInteger(0)
var dacControlLabel = 0.0
var sessionFileName :String =  FirstViewController.getDateTimeSessionString()
var fileURLComponents = FileURLComponents(fileName: sessionFileName, fileExtension: "csv", directoryName: nil, directoryPath: .documentDirectory)
var logURLComponents = FileURLComponents(fileName: "logFile_" + FirstViewController.getDateTimeSessionString(), fileExtension: "csv", directoryName: nil, directoryPath: .documentDirectory)
var configFile = FileURLComponents(fileName: "config", fileExtension: "txt", directoryName: nil, directoryPath: .documentDirectory)
var didSetupFile = 0 //flag used to ensure that data written to file does not get overwritten whenever views are switched back and forth
let notificationFreq: Int = 92 //This param is not used in any notification of the PCB, it is just used to calculate approximately how many values are to be displayed on the window based on the chosen window length. This has to change in accordance with the sampling rate should it change.
//These constants are used to calculate the values acc,gyro, and mag reading from their raw form.
let accFullScale: Double = 4.0
let gyroFullScale: Double = Double(7.6e-3)
let magFullScale: Double = 1 / Double(16)
var prev_time:Double = 0.0

var graphFirstFour = true


//auxiliary extension
extension String {
    subscript(i: Int) -> String {
        return String(self[index(startIndex, offsetBy: i)])
    }
}


class FirstViewController: UIViewController, ChartViewDelegate, CBPeripheralDelegate {

    var button = dropDownBtn()
    var numOfDataToDisplay = 0 // will be adjusted according to chosen setting by the dropDownBtn "button" above
    var previousTime:Double = 0.0
    var maxTime:Double = 0.0
    var minCap1Reading = Double(Int.max) - 1.0
    var minCap2Reading = Double(Int.max) - 1.0
    var minCap3Reading = Double(Int.max) - 1.0
    var minCap4Reading = Double(Int.max) - 1.0
    var maxCap1Reading = 0.0
    var maxCap2Reading = 0.0
    var maxCap3Reading = 0.0
    var maxCap4Reading = 0.0
    var numOfCapsNotifying = 1 //this will be used to see how many values are to be displayed in the graph. Note that when two caps are on, the sum of the data counts of each of the caps' graphs need to be used i.e. half of how much data that would need to be displayed if only one cap was on. This is due to the fact that each cap will notify at notificationFreq/2 when both are on.
    var cap1Diff = 0.0
    var cap2Diff = 0.0
    var cap3Diff = 0.0
    var cap4Diff = 0.0
    var currentGraphWindowSize:Double = 5.0 //This will be used to sense changes in the window selection of the graph. It is initialized to 5.0 as the window starts off as 5 seconds
    var longPressTimer: Timer?

    var history = [Double]() //TODO: make this a circular array/a stack insetad to save ram memory

    // var selection: String = "None"

    @IBOutlet weak var chartView: LineChartView!
    @IBOutlet weak var chartView2: LineChartView!
    @IBOutlet weak var chartView3: LineChartView!
    @IBOutlet weak var chartView4: LineChartView!
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var DACLabel: UILabel!
    @IBOutlet weak var cap1MinValue: UILabel!
    @IBOutlet weak var cap1MaxValue: UILabel!
    @IBOutlet weak var cap2MinValue: UILabel!
    @IBOutlet weak var cap2MaxValue: UILabel!
//    @IBOutlet weak var cap1Toggle: UIButton!
//    @IBOutlet weak var cap2Toggle: UIButton!
    @IBOutlet weak var cap1Label: UILabel!
    @IBOutlet weak var cap2Label: UILabel!
    @IBOutlet weak var cap1MinLabel: UILabel!
    @IBOutlet weak var cap1MaxLabel: UILabel!
    @IBOutlet weak var cap2MinLabel: UILabel!
    @IBOutlet weak var cap2MaxLabel: UILabel!
    @IBOutlet weak var cap1DiffLabel: UILabel!
    @IBOutlet weak var cap1DiffValue: UILabel!
    @IBOutlet weak var cap2DiffLabel: UILabel!
    @IBOutlet weak var cap2DiffValue: UILabel!
    
    @IBOutlet weak var cap3MinLabel: UILabel!
    @IBOutlet weak var cap3MinValue: UILabel!
    @IBOutlet weak var cap3MaxLabel: UILabel!
    @IBOutlet weak var cap3MaxValue: UILabel!
    @IBOutlet weak var cap3DiffLabel: UILabel!
    @IBOutlet weak var cap3DiffValue: UILabel!
    
    @IBOutlet weak var cap4MinLabel: UILabel!
    @IBOutlet weak var cap4MinValue: UILabel!
    @IBOutlet weak var cap4MaxLabel: UILabel!
    @IBOutlet weak var cap4MaxValue: UILabel!
    @IBOutlet weak var cap4DiffLabel: UILabel!
    @IBOutlet weak var cap4DiffValue: UILabel!
    
    
    @IBOutlet weak var plusDACButton: UIButton!
    @IBOutlet weak var minusDACButton: UIButton!
    @IBOutlet weak var recordingButtonLabel: UILabel!
    @IBOutlet weak var newFileButtonLabel: UILabel!
    
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var contentView: UIView!
    
    @IBOutlet weak var graphSwitch: UISegmentedControl!
    
    @IBAction func clearButton(_ sender: Any) {
        clearCharts()
    }
    
    
    @IBAction func switchActivated(_ sender: Any) {
        switch graphSwitch.selectedSegmentIndex
        {
        case 0:
            graphFirstFour = true
            clearCharts()
        case 1:
           graphFirstFour = false
            clearCharts()
        default:
            break
        }
    }
    
    @IBAction func plusDAC(_ sender: UIButton) {
        //to change the baseline of the DAC by 0.5, 5 needs to be written to it.
        if(dacControlLabel < 15.5)
        {
            dacControl = NSInteger(dacControl+4)
            dacControlLabel += 0.5
            writeDACValue()
            DACLabel.text = String(dacControlLabel)
            do
            {
                if(dacControl > 10)
                {
                    let dacString = "DAC_CONTROLS \(dacControl)".utf8
                    try File.write(Data(dacString), to: configFile)
                }
                else{
                    let dacString = "DAC_CONTROLS 0\(dacControl)".utf8
                    try File.write(Data(dacString), to: configFile)
                }
                
            }
            catch{
                print("error writingt to config")
            }
        }
    }

    @IBAction func plusDACLongPress(_ sender: UILongPressGestureRecognizer) {
        if sender.state == .began {
             longPressTimer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(plusDAC), userInfo: nil, repeats: true)
         } else if sender.state == .ended || sender.state == .cancelled {
             longPressTimer?.invalidate()
             longPressTimer = nil
          }
    }


    @IBAction func minusDAC(_ sender: UIButton) {
        if dacControl == 0 {
            dacControl = NSInteger(0)
            dacControlLabel = 0.0
        }
        else {
            dacControl = NSInteger(dacControl-4)
            dacControlLabel -= 0.5
        }
        writeDACValue()
        DACLabel.text = String(dacControlLabel)
        do
        {
            if(dacControl > 10)
            {
                let dacString = "DAC_CONTROLS \(dacControl)".utf8
                try File.write(Data(dacString), to: configFile)
            }
            else{
                let dacString = "DAC_CONTROLS 0\(dacControl)".utf8
                try File.write(Data(dacString), to: configFile)
            }
        }
        catch{
            print("error writingt to config")
        }
    }

    
    @IBAction func minusDACLongPress(_ sender: UILongPressGestureRecognizer) {
        if sender.state == .began {
           longPressTimer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(minusDAC), userInfo: nil, repeats: true)
        } else if sender.state == .ended || sender.state == .cancelled {
            longPressTimer?.invalidate()
            longPressTimer = nil
         }
    }
    


    @IBAction func stopButton(_ sender: UIButton) {
        let refreshAlert = UIAlertController(title: "End Recording?", message: "Are you sure you want to stop recording?", preferredStyle: UIAlertController.Style.alert)

        refreshAlert.addAction(UIAlertAction(title: "Never Mind", style: .cancel, handler: { (action: UIAlertAction!) in
          print("Handle Cancel Logic here")
          }))
        
        refreshAlert.addAction(UIAlertAction(title: "Yes", style: .default, handler: { (action: UIAlertAction!) in
            print("Disabling notifications")
            globalBPPeripheral.setNotifyValue(false, for: cap1Characteristic!)
            globalBPPeripheral.setNotifyValue(false, for: cap2Characteristic!)
            let uivc = self.storyboard!.instantiateViewController(withIdentifier: "DropDownButtonViewController")
            self.navigationController!.pushViewController(uivc, animated: true)

          }))
        
        self.present(refreshAlert, animated: true, completion: nil)
      //  self.presentViewController(refreshAlert, animated: true, completion: nil)
//        if recordingButtonLabel.text == "Pause" {
//            recordingButtonLabel.text = "Start"
//            globalBPPeripheral.setNotifyValue(false, for: cap1Characteristic!)
//            globalBPPeripheral.setNotifyValue(false, for: cap2Characteristic!)
//           }
//        else if recordingButtonLabel.text == "Start" {
//            recordingButtonLabel.text = "Pause"
//            globalBPPeripheral.setNotifyValue(true, for: cap1Characteristic!)
//            globalBPPeripheral.setNotifyValue(true, for: cap2Characteristic!)
//           }
    }
    
    @IBAction func createNewFile(_ sender: Any) {
        sessionFileName = FirstViewController.getDateTimeSessionString()
        fileURLComponents = FileURLComponents(fileName: sessionFileName, fileExtension: "csv", directoryName: nil, directoryPath: .documentDirectory)
        do{
            try setupFileSaving()
            didSetupFile = 1
            createAlert(title: "Success!", message: "File created")
            print("succeeded making file")
        } catch{
            createAlert(title: "File Creation Failed", message: "Please restart app")
            print("error making file") //OPTIMIZATION: make this a user warning so that they reset the app. Saving data is the core importance so if it fails to do so then the user should know.
        }
    }
    
//    @IBAction func cap1Button(_ sender: UIButton) {
//        if cap1Toggle.alpha == 1.0 {
//            cap1Toggle.alpha = 0.5
//           }
//        else if cap1Toggle.alpha == 0.5 {
//            cap1Toggle.alpha = 1.0
//           }
//
//        if cap1MinValue.isHidden == false {
//            cap1MinValue.isHidden = true
//        }
//
//        else if cap1MinValue.isHidden == true {
//            cap1MinValue.isHidden = false
//        }
//
//        if cap1MaxValue.isHidden == false {
//            cap1MaxValue.isHidden = true
//        }
//
//        else if cap1MaxValue.isHidden == true {
//            cap1MaxValue.isHidden = false
//        }
//
//        if cap1Label.isHidden == false {
//            cap1Label.isHidden = true
//        }
//
//        else if cap1Label.isHidden == true {
//            cap1Label.isHidden = false
//        }
//
//        if cap1MinLabel.isHidden == false {
//            cap1MinLabel.isHidden = true
//        }
//
//        else if cap1MinLabel.isHidden == true {
//            cap1MinLabel.isHidden = false
//        }
//
//        if cap1MaxLabel.isHidden == false {
//            cap1MaxLabel.isHidden = true
//        }
//
//        else if cap1MaxLabel.isHidden == true {
//            cap1MaxLabel.isHidden = false
//        }
//
//        if cap1DiffLabel.isHidden == false {
//            cap1DiffLabel.isHidden = true
//        }
//
//        else if cap1DiffLabel.isHidden == true {
//            cap1DiffLabel.isHidden = false
//        }
//
//        if cap1DiffValue.isHidden == false {
//            cap1DiffValue.isHidden = true
//        }
//
//        else if cap1DiffValue.isHidden == true {
//            cap1DiffValue.isHidden = false
//
//        }
//
//        if chartView.isHidden == false {
//            chartView.isHidden = true
//            globalBPPeripheral.setNotifyValue(false, for: cap1Characteristic!)
//            if(numOfCapsNotifying == 2)
//            {
//                numOfCapsNotifying -= 1
//            }
//        }
//
//        else if chartView.isHidden == true {
//            chartView.isHidden = false
//            globalBPPeripheral.setNotifyValue(true, for: cap1Characteristic!)
//            if(numOfCapsNotifying == 1)
//            {
//                numOfCapsNotifying += 1
//            }
//            clearCharts()
//        }
//
//    }
//
//    @IBAction func cap2Button(_ sender: UIButton) {
//        if cap2Toggle.alpha == 1.0 {
//            cap2Toggle.alpha = 0.5
//           }
//        else if cap2Toggle.alpha == 0.5 {
//            cap2Toggle.alpha = 1.0
//           }
//
//        if cap2MinValue.isHidden == false {
//                   cap2MinValue.isHidden = true
//               }
//
//               else if cap2MinValue.isHidden == true {
//                   cap2MinValue.isHidden = false
//               }
//
//               if cap2MaxValue.isHidden == false {
//                   cap2MaxValue.isHidden = true
//               }
//
//               else if cap2MaxValue.isHidden == true {
//                   cap2MaxValue.isHidden = false
//               }
//
//               if cap2Label.isHidden == false {
//                   cap2Label.isHidden = true
//               }
//
//               else if cap2Label.isHidden == true {
//                   cap2Label.isHidden = false
//               }
//
//               if cap2MinLabel.isHidden == false {
//                   cap2MinLabel.isHidden = true
//               }
//
//               else if cap2MinLabel.isHidden == true {
//                   cap2MinLabel.isHidden = false
//               }
//
//               if cap2MaxLabel.isHidden == false {
//                   cap2MaxLabel.isHidden = true
//               }
//
//               else if cap2MaxLabel.isHidden == true {
//                   cap2MaxLabel.isHidden = false
//               }
//
//               if cap2DiffLabel.isHidden == false {
//                   cap2DiffLabel.isHidden = true
//               }
//
//               else if cap2DiffLabel.isHidden == true {
//                   cap2DiffLabel.isHidden = false
//               }
//
//               if cap2DiffValue.isHidden == false {
//                   cap2DiffValue.isHidden = true
//               }
//
//               else if cap2DiffValue.isHidden == true {
//                   cap2DiffValue.isHidden = false
//               }
//
//                if chartView2.isHidden == false {
//                    chartView2.isHidden = true
//                    globalBPPeripheral.setNotifyValue(false, for: cap2Characteristic!)
//                    if(numOfCapsNotifying == 2)
//                    {
//                        numOfCapsNotifying -= 1
//                    }
//                    self.chartView2.clearValues()
//                }
//
//                else if chartView2.isHidden == true {
//                    chartView2.isHidden = false
//                    globalBPPeripheral.setNotifyValue(true, for: cap2Characteristic!)
//                    if(numOfCapsNotifying == 1)
//                    {
//                        numOfCapsNotifying += 1
//                    }
//                    clearCharts()
//                }
//        }

    func createAlert (title:String, message:String){
        let alert = UIAlertController(title: title, message: message, preferredStyle: UIAlertController.Style.alert)

        alert.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: { (action) in alert.dismiss(animated: true, completion: nil)}))

        self.present(alert, animated: true, completion: nil)
    }

    
    var xlsxdata: [ChartDataEntry] = Array<ChartDataEntry>()
    var incr: Double = 0.0
    var currPosition: Double = 0.0

    // peak detection
    var yVals: [Double] = []
    var yCount: Int = 0
    var start: Int = -1
    var end: Int = -1


//    var sys: [Int] = [0, 0, 0]   // peak
//    var dia: [Int] = [0, 0, 0]   // dip
//    var signals: [Int] = []
//    var filteredY: [Double] = []
//    var avgFilter: [Double] = []
//    var stdFilter: [Double] = []


    //var seconds = 0

    //var timer: Timer?
   // var BPMtimer: Timer?
    var waveformRange = 1.0
    let component = 0
   // var bpmValue = 60

//    @objc func action(){
//        seconds += 1
//
//        if seconds == 59 {
//            seconds = 00
//            minutes += 1
//        }

//        let restTime = (String(minutes) + ":" + ((seconds<10) ? "0" : "") + String(seconds))
//        timeLabel.text = restTime

   // }

//    @objc func showBPM() {
//        bpmValue += 1
//
//        if bpmValue == 66 {
//            bpmValue = 60
//        }
//
//        BPM.text = String(bpmValue)
//
//    }
//
        func printDate(string: String) {
            let date = Date()
            let formatter = DateFormatter()
            formatter.dateFormat = "HH_mm_ss_SSSS"
            print(string + formatter.string(from: date))
        }

        static func getCurrentTimeAsString() -> String
        {
            let date = Date()
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss:SSSS"
            return formatter.string(from: date)
        }

        func writeDACValue(){
            if let blePeripheral = globalBPPeripheral{
                let data = NSData(bytes: &dacControl, length: 1)
                blePeripheral.writeValue(data as Data, for: dac1ControlCharacteristic!, type: CBCharacteristicWriteType.withResponse)
            }
        }


        func setupFileSaving() throws
        {
            let writeData = Data("Elapsed time(s),wall_clock(s),cap1(pF),cap2(pF),cap3(pF),cap4(pF),cap5(pF),cap6(pF),cap7(pF),cap8(pF),accx,accy,accz,gyrox,gyroy,gyroz,magx,magy,magz\n".utf8)
            do {
                _ = try File.write(writeData, to: fileURLComponents)
                _ = try File.write(Data("logData\n".utf8), to: logURLComponents)
            } catch {
                createAlert(title: "File Creation Failed", message: "Please restart app")
                throw error
            }
        }

        static func getDateTimeSessionString() -> String
        {
            //func to returns current session name in terms of date and time as a string
            let date = Date()
            let calendar = Calendar.current
            let month = calendar.component(.month, from: date)
            let day = calendar.component(.day, from: date)
            let year = calendar.component(.year, from: date)
            let formatter = DateFormatter()
            formatter.dateFormat = "HH_mm_ss"
            let dateTimeString = "session_\(month)_\(day)_\(year)_\(formatter.string(from: date))"
            return dateTimeString
        }

    func writeDataToFile(_ dataToAdd: Array<Double>) throws
    {
        let wallTime = FirstViewController.getCurrentTimeAsString() //NOTE: The milliseconds produced by Swift will not match the one that is generated by the PCB. This is a limitation of precision of reporting of Swift.
        var writeData = Data("".utf8)
        var logData = Data("".utf8)
        if(dataToAdd[0] == 1.0)
        {
            //string for cap1. Note that there are two consecutive commas after \(dataToAdd[2]) since cap2's data isnt being written
            writeData = Data("\(dataToAdd[1]),\(wallTime),\(dataToAdd[2]),\(dataToAdd[3]),\(dataToAdd[4]),\(dataToAdd[5]),\(dataToAdd[6]),\(dataToAdd[7]),\(dataToAdd[8]),\(dataToAdd[9]),\(dataToAdd[10]),\(dataToAdd[11]),\(dataToAdd[12]),\(dataToAdd[13]),\(dataToAdd[14]),\(dataToAdd[15]),\(dataToAdd[16]),\(dataToAdd[17]),\(dataToAdd[18])\n ".utf8)
            logData = Data("\(dataToAdd[1]),\(wallTime),\(dataToAdd[2]),,\(minCap1Reading),\(maxCap1Reading),\(cap1Diff),\(dacControl)\n".utf8)
        }
        else
        {
            //string for cap1. Note that there are two consecutive commas after \(wallTime) since cap2's data isnt being written
            // NOTE: This part is not used for now since only one channel is notifying
            writeData = Data("\(dataToAdd[1]),\(wallTime),,\(dataToAdd[2]),\(dataToAdd[3]),\(dataToAdd[4]),\(dataToAdd[5]),\(dataToAdd[6]),\(dataToAdd[7]),\(dataToAdd[8]),\(dataToAdd[9]),\(dataToAdd[10]),\(dataToAdd[11])\n".utf8)
            logData = Data("\(dataToAdd[1]),\(wallTime),,\(dataToAdd[2]),\(minCap2Reading),\(maxCap2Reading),\(cap2Diff),\(dacControl)\n".utf8)
        }
        do {
            _ = try File.update(writeData, to: fileURLComponents)
            _ = try File.update(logData, to: logURLComponents)
        } catch {
//            createAlert(title: "File Creation Failed", message: "Please restart app")
            throw error
        }
    }

//    override func viewDidAppear(_ animated: Bool) {
//        scrollView.contentSize = CGSize(width: scrollView.contentSize.width, height: 2000)
//
//    }
    override func viewWillAppear(_ animated: Bool) {
        
        UIApplication.shared.isIdleTimerDisabled = true
        super.viewWillAppear(animated)

    }

    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationController?.navigationBar.shadowImage = UIImage()
        
       // cap1Toggle.alpha = 1.0
      //  cap2Toggle.alpha = 1.0
        if(didSetupFile == 0)
        {
            do{
                try setupFileSaving()
                didSetupFile = 1
                print("succeeded making file")
            } catch{
                print("error making file") //OPTIMIZATION: make this a user warning so that they reset the app. Saving data is the core importance so if it fails to do so then the user should know.
            }
        }
        else
        {
            //This means that there is a file, and a new recording is being made. Hence, a new file should be made
            sessionFileName = FirstViewController.getDateTimeSessionString()
            fileURLComponents = FileURLComponents(fileName: sessionFileName, fileExtension: "csv", directoryName: nil, directoryPath: .documentDirectory)
            do{
                try setupFileSaving()
                didSetupFile = 1
                print("succeeded making file")
            } catch{
                print("error making file") //OPTIMIZATION: make this a user warning so that they reset the app. Saving data is the core importance so if it fails to do so then the user should know.
            }
        }
        
        
        
        do{
            if(try File.exists(configFile))
            {
                do
                {
                    let configurationVars = try File.read(from: configFile)
                    let strConfigurationVars:String = String(decoding: configurationVars, as: UTF8.self)
                    dacControl = NSInteger(Int(strConfigurationVars[strConfigurationVars.count - 2])!) * 10 +  NSInteger(Int(strConfigurationVars[strConfigurationVars.count - 1])!)
                    print("dacCtrl",dacControl)
                    dacControlLabel = Double(Double(dacControl)/8.0)
                    print("dacCtrlLabel",dacControlLabel)
                    DACLabel.text = String(dacControlLabel)
                }
                catch{
                    print("error reading config")
                }
            }
            else
            {
                do
                {
                    if(dacControl > 10)
                    {
                        let dacString = "DAC_CONTROLS \(dacControl)".utf8
                        try File.write(Data(dacString), to: configFile)
                    }
                    else{
                        let dacString = "DAC_CONTROLS 0\(dacControl)".utf8
                        try File.write(Data(dacString), to: configFile)
                    }
                }
                catch{
                    print("error writingt to config")
                }
            }
        } catch{
            print("error checking for config file") //OPTIMIZATION: make this a user warning so that they reset the app. Saving data is the core importance so if it fails to do so then the user should know.
        }
        
        DACLabel.text = String(dacControlLabel)

      //  rangePicker.dataSource = self
       // rangePicker.delegate = self

        //self.title = "Waveform"
        configChart()
//        readInDataFromXlsx()
        if xlsxdata.count > 1{
            // if data is always read in at a steady interval
            incr = xlsxdata[1].x
        }

//        self.BPMtimer = Timer.scheduledTimer(timeInterval: 2.0, target: self, selector: #selector(showBPM), userInfo: nil, repeats: true)
//

         button = dropDownBtn.init(frame: CGRect(x: 0, y: 0, width: 0, height: 0))
                button.setTitle("5 SEC", for: .normal)
                button.setTitleColor(UIColor.black, for: .normal)
                button.clipsToBounds = true
                button.translatesAutoresizingMaskIntoConstraints = false

                self.contentView.addSubview(button)

                button.leadingAnchor.constraint(equalTo: self.contentView.leadingAnchor, constant: 50).isActive = true
                button.topAnchor.constraint(equalTo:self.contentView.topAnchor, constant: 20).isActive = true

                button.widthAnchor.constraint(equalToConstant: 120).isActive = true
                button.heightAnchor.constraint(equalToConstant: 40).isActive = true

              button.dropView.dropDownOptions = ["5 SEC", "10 SEC", "20 SEC", "30 SEC", "5 MIN"]

        //begin notification of nRF
        if(globalBPPeripheral != nil)
        {
            printDate( string: "")
            globalBPPeripheral.delegate  = self
            globalBPPeripheral.setNotifyValue(true, for: cap1Characteristic!)
            printDate( string: "After notifying 1")
//            globalBPPeripheral.setNotifyValue(true, for: cap2Characteristic!)
//            printDate( string: "After notifying 2")
            writeDACValue()
            printDate( string: "Finished notifying")
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        UIApplication.shared.isIdleTimerDisabled = false
    }

    // Function to calculate the arithmetic mean
    func arithmeticMean(array: [Double]) -> Double {
        var total: Double = 0
        for number in array {
            total += number
        }
        return total / Double(array.count)
    }

    // Function to calculate the standard deviation
    func standardDeviation(array: [Double]) -> Double
    {
        let length = Double(array.count)
        let avg = array.reduce(0, {$0 + $1}) / length
        let sumOfSquaredAvgDiff = array.map { pow($0 - avg, 2.0)}.reduce(0, {$0 + $1})
        return sqrt(sumOfSquaredAvgDiff / length)
    }

    // Function to extract some range from an array
    func subArray<T>(array: [T], s: Int, e: Int) -> [T] {
        if e > array.count {
            return []
        }
        return Array(array[s..<min(e, array.count)])
    }

    // Smooth z-score thresholding filter
    func ThresholdingAlgo(y: [Double],lag: Int,threshold: Double,influence: Double) -> ([Int],[Double],[Double]) {

        //  TODO: optimize algorithm -- split the calculation of the signal into a separate function (without the loop). Then when a new datapoint arrives, update filteredY, avgFilter and stdFilter once
        var signals   = Array(repeating: 0, count: y.count)
        var filteredY = Array(repeating: 0.0, count: y.count)
        var avgFilter = Array(repeating: 0.0, count: y.count)
        var stdFilter = Array(repeating: 0.0, count: y.count)

        // Initialise variables
        for i in 0...lag-1 {
            //signals[i] = 0
            filteredY[i] = y[i]
        }

        // Start filter
        avgFilter[lag-1] = arithmeticMean(array: subArray(array: y, s: 0, e: lag-1))
        stdFilter[lag-1] = standardDeviation(array: subArray(array: y, s: 0, e: lag-1))

        for i in lag...y.count-1 {
            if abs(y[i] - avgFilter[i-1]) > threshold*stdFilter[i-1] {
                if y[i] > avgFilter[i-1] {
                    signals[i] = 1      // Positive signal
                } else {
                    signals[i] = -1       // Negative signal
                }
                filteredY[i] = influence*y[i] + (1-influence)*filteredY[i-1]
            } else {
                signals[i] = 0          // No signal
                filteredY[i] = y[i]
            }
            // Adjust the filters
            avgFilter[i] = arithmeticMean(array: subArray(array: filteredY, s: i-lag, e: i))
            stdFilter[i] = standardDeviation(array: subArray(array: filteredY, s: i-lag, e: i))
        }

        return (signals,avgFilter,stdFilter)
    }



    /// conditional check for whether or not the graph needs to call update();
    /// * For now, it checks whether xlsxdata contains any values but when connectd to the bluetooth device for real-time data, it should check if there is new data to be updated
    private func hasData() -> Bool {
        if xlsxdata.isEmpty {
            return false
        }
        return true
    }
    
    func clearCharts()
    {
        self.cap1MaxValue.text = String(round(1000*maxCap1Reading)/1000) + " pF"
        self.cap1MinValue.text = String(round(1000*minCap1Reading)/1000) + " pF"
        self.cap2MaxValue.text = String(round(1000*maxCap2Reading)/1000) + " pF"
        self.cap2MinValue.text = String(round(1000*minCap2Reading)/1000) + " pF"
        self.cap3MaxValue.text = String(round(1000*maxCap3Reading)/1000) + " pF"
        self.cap3MinValue.text = String(round(1000*minCap3Reading)/1000) + " pF"
        self.cap4MaxValue.text = String(round(1000*maxCap4Reading)/1000) + " pF"
        self.cap4MinValue.text = String(round(1000*minCap4Reading)/1000) + " pF"
        self.chartView.data?.clearValues()
        self.chartView2.data?.clearValues()
        self.chartView3.data?.clearValues()
        self.chartView4.data?.clearValues()

        setupChartData()
    }


    /// updates the chartView with new data;
    /// * For now, new data is popped from xlsxdata, but with the real-time bluetooth device, the function could be modified to take in a new data entry as a parameter, and add it to the chartView.data
    @objc func update(_ dataToAdd: Array<Double>) {

            let timerMinutes = Int(maxTime)/60

            //print("MINUTES:", timerMinutes)
        //print("SECONDS:", String(Int(maxTime)-(60*(timerMinutes))))

            self.timeLabel.text = String(timerMinutes) + ":" + (((Int(maxTime)-(60*(timerMinutes)))<10) ? "0" : "") + String(Int(maxTime) - (60*(timerMinutes)))
//(((Int(maxTime)-(60*(timerMinutes)))<10) ? "0" : "") + format: "%.0f",

            let separators = selection.split(separator: " ", maxSplits: 1)
            var value = Double(String(separators.first!))

            let secondsBetweenData:Double = 1/Double(notificationFreq)
            var rMin = 5.0
            var dCount = Int(5.0/secondsBetweenData)
      //  print(secondsBetweenData)

           // self.minValue.text = String(minCap1Reading)
            //self.maxValue.text = String(maxCap1Reading)

//            print("=========", value!)

            if separators[1] == "MIN" {
                value = value! * 60.0
               // print("VALUE", value)
            }
        
        //check if window selection has changed, and clear charts if it did.
        if(currentGraphWindowSize != value!)
        {
            //window selection has changed
            clearCharts()
            currentGraphWindowSize = value!
        }

            if (value! == 5.0) {
                rMin = 5.0
                dCount = Int(5.0/secondsBetweenData) * 4
                print("width",chartView.xAxis.axisRange)
                print("dcount: ",dCount)
            } else if (value! == 10.0) {
                rMin = 10.0
                dCount = Int(10.0/secondsBetweenData)
            } else if (value! == 20.0) {
                rMin = 20.0
                dCount = Int(20.0/secondsBetweenData)
            } else if (value! == 30.0) {
                rMin = 30.0
                dCount = Int(30.0/secondsBetweenData)
            } else if (value! == 300.0) {
                rMin = 300.0
                dCount = Int(300.0/secondsBetweenData)
            }

            let dataCount = self.chartView.data?.entryCount
            let dataCount2 = self.chartView2.data?.entryCount
            if ( dataCount != nil && dataCount! != 0  && dataCount! % (dCount/numOfCapsNotifying) == 0 || dataCount2 != nil && dataCount2! != 0  && dataCount2! % (dCount/numOfCapsNotifying) == 0)
            {
                self.cap1MaxValue.text = String(round(1000*maxCap1Reading)/1000) + " pF"
                self.cap1MinValue.text = String(round(1000*minCap1Reading)/1000) + " pF"
                self.cap2MaxValue.text = String(round(1000*maxCap2Reading)/1000) + " pF"
                self.cap2MinValue.text = String(round(1000*minCap2Reading)/1000) + " pF"
                self.cap3MaxValue.text = String(round(1000*maxCap3Reading)/1000) + " pF"
                self.cap3MinValue.text = String(round(1000*minCap3Reading)/1000) + " pF"
                self.cap4MaxValue.text = String(round(1000*maxCap4Reading)/1000) + " pF"
                self.cap4MinValue.text = String(round(1000*minCap4Reading)/1000) + " pF"
                //reset graph if max points on graph is hit
                clearCharts()
            }
            if(dataToAdd[0] == 1.0) //check the flag at the beginning of the array to see which cap it is. NOTE: This feature has been temporarily disabled as the design of the board has changed.
            // For now, we are noifying for one channel only, so handle only one channel. This is achieved by sending 1.0 as the flag for all cap readings, while disabling the second channel's notificaiton.
            // Kept the flag check in case future changes need the second channel
            {
//                print("cap1")
                if(graphFirstFour==true){
                    let newdata = ChartDataEntry(x: dataToAdd[1], y: dataToAdd[2])
                    let newdata2 = ChartDataEntry(x: dataToAdd[1], y: dataToAdd[3])
                    let newdata3 = ChartDataEntry(x: dataToAdd[1], y: dataToAdd[4])
                    let newdata4 = ChartDataEntry(x: dataToAdd[1], y: dataToAdd[5])
                    
                    self.chartView.data?.addEntry(newdata, dataSetIndex: 0)
                    self.chartView.notifyDataSetChanged()
                    self.chartView.setVisibleXRangeMinimum(rMin)
                    currPosition += dataToAdd[2]
                    self.chartView.moveViewToX(currPosition)
    //                updateReadingsAndLabels(flag: dataToAdd[0], dcount: dataCount!)
                    
                    self.chartView3.data?.addEntry(newdata3, dataSetIndex: 0)
                    self.chartView3.notifyDataSetChanged()
                    self.chartView3.setVisibleXRangeMinimum(rMin)
    //                currPosition += dataToAdd[2]
                    self.chartView3.moveViewToX(currPosition)
    //                updateReadingsAndLabels(flag: dataToAdd[0], dcount: dataCount!)
                    
                    self.chartView2.data?.addEntry(newdata2, dataSetIndex: 0)
                    self.chartView2.notifyDataSetChanged()
                    self.chartView2.setVisibleXRangeMinimum(rMin)
    //                currPosition += dataToAdd[2]
                    self.chartView2.moveViewToX(currPosition)
    //                updateReadingsAndLabels(flag: dataToAdd[0], dcount: dataCount!)
                    
                    self.chartView4.data?.addEntry(newdata4, dataSetIndex: 0)
                    self.chartView4.notifyDataSetChanged()
                    self.chartView4.setVisibleXRangeMinimum(rMin)
    //                currPosition += dataToAdd[2]
                    self.chartView4.moveViewToX(currPosition)
                    updateReadingsAndLabels(flag: dataToAdd[0], dcount: dataCount!)
                }
                
                else if(graphFirstFour==false){
                    let newdata = ChartDataEntry(x: dataToAdd[1], y: dataToAdd[6])
                    let newdata2 = ChartDataEntry(x: dataToAdd[1], y: dataToAdd[7])
                    let newdata3 = ChartDataEntry(x: dataToAdd[1], y: dataToAdd[8])
                    let newdata4 = ChartDataEntry(x: dataToAdd[1], y: dataToAdd[9])
                    
                    self.chartView.data?.addEntry(newdata, dataSetIndex: 0)
                    self.chartView.notifyDataSetChanged()
                    self.chartView.setVisibleXRangeMinimum(rMin)
                    currPosition += dataToAdd[2]
                    self.chartView.moveViewToX(currPosition)
    //                updateReadingsAndLabels(flag: dataToAdd[0], dcount: dataCount!)
                    
                    self.chartView3.data?.addEntry(newdata3, dataSetIndex: 0)
                    self.chartView3.notifyDataSetChanged()
                    self.chartView3.setVisibleXRangeMinimum(rMin)
    //                currPosition += dataToAdd[2]
                    self.chartView3.moveViewToX(currPosition)
    //                updateReadingsAndLabels(flag: dataToAdd[0], dcount: dataCount!)
                    
                    self.chartView2.data?.addEntry(newdata2, dataSetIndex: 0)
                    self.chartView2.notifyDataSetChanged()
                    self.chartView2.setVisibleXRangeMinimum(rMin)
    //                currPosition += dataToAdd[2]
                    self.chartView2.moveViewToX(currPosition)
    //                updateReadingsAndLabels(flag: dataToAdd[0], dcount: dataCount!)
                    
                    self.chartView4.data?.addEntry(newdata4, dataSetIndex: 0)
                    self.chartView4.notifyDataSetChanged()
                    self.chartView4.setVisibleXRangeMinimum(rMin)
    //                currPosition += dataToAdd[2]
                    self.chartView4.moveViewToX(currPosition)
                    updateReadingsAndLabels(flag: dataToAdd[0], dcount: dataCount!)
                }
                
                
            }
        
        
//            else
//            {
//                print("cap2")
//                let newdata = ChartDataEntry(x: dataToAdd[1], y: dataToAdd[2])
//                self.chartView2.data?.addEntry(newdata, dataSetIndex: 0)
//                self.chartView2.notifyDataSetChanged()
//                self.chartView2.setVisibleXRangeMinimum(rMin)
//                currPosition += dataToAdd[2]
//                self.chartView2.moveViewToX(currPosition)
//                updateReadingsAndLabels(flag: dataToAdd[0], dcount: dataCount!)
//            }

            do{
                try writeDataToFile(dataToAdd)
            } catch{
                createAlert(title: "File Creation Failed", message: "Please restart app")
                print("error writing data to file")
            }


    }

    func updateReadingsAndLabels(flag: Double, dcount: Int)
    {
        let dataCount = self.chartView.data?.entryCount
       // let dataCount2 = self.chartView2.data?.entryCount
        if( dataCount! == 1 && flag == 1.0)
        {
            maxCap1Reading = self.chartView.data?.getYMax() as! Double
            minCap1Reading = self.chartView.data?.getYMin() as! Double
            
            maxCap2Reading = self.chartView2.data?.getYMax() as! Double
            minCap2Reading = self.chartView2.data?.getYMin() as! Double
            
            maxCap3Reading = self.chartView3.data?.getYMax() as! Double
            minCap3Reading = self.chartView3.data?.getYMin() as! Double
            
            maxCap4Reading = self.chartView4.data?.getYMax() as! Double
            minCap4Reading = self.chartView4.data?.getYMin() as! Double
            
//            maxCap2Reading = self.chartView2.data?.getYMax() as! Double
//            minCap2Reading = self.chartView2.data?.getYMax() as! Double
        }
//        else if( dataCount2! == 1 && flag == 0.0)
//        {
//            maxCap2Reading = self.chartView2.data?.getYMax() as! Double
//            minCap2Reading = self.chartView2.data?.getYMax() as! Double
//        }
        else if(flag == 1.0)
        {
            // Handle max label updates
            print("max cap3Actual:",self.chartView3.data?.yMax )
            print("max cap3Prev:",self.chartView3.data?.yMax )
            if(self.chartView.data?.yMax ?? 0 > maxCap1Reading)
            {
                maxCap1Reading = self.chartView.data?.yMax ?? 0
                self.cap1MaxValue.text = String(round(1000*maxCap1Reading)/1000) + " pF"

            }
            if(self.chartView2.data?.yMax ?? 0 > maxCap2Reading)
            {
                maxCap2Reading = self.chartView2.data?.yMax ?? 0
                self.cap2MaxValue.text = String(round(1000*maxCap2Reading)/1000) + " pF"
            }
            if(self.chartView3.data?.yMax ?? 0 > maxCap3Reading)
            {
                maxCap3Reading = self.chartView3.data?.yMax ?? 0
                self.cap3MaxValue.text = String(round(1000*maxCap3Reading)/1000) + " pF"
            }
            if(self.chartView4.data?.yMax ?? 0 > maxCap4Reading)
            {
                maxCap4Reading = self.chartView4.data?.yMax ?? 0
                self.cap4MaxValue.text = String(round(1000*maxCap4Reading)/1000) + " pF"
            }

            
            // handle min label updates
            if(self.chartView.data?.yMin ?? 0 < minCap1Reading)
            {
                minCap1Reading = self.chartView.data?.yMin ?? 0
                self.cap1MinValue.text = String(round(1000*minCap1Reading)/1000) + " pF"
                self.cap2MinValue.text = String(round(1000*minCap2Reading)/1000) + " pF"
                self.cap3MinValue.text = String(round(1000*minCap3Reading)/1000) + " pF"
                self.cap4MinValue.text = String(round(1000*minCap4Reading)/1000) + " pF"
            }
            if(self.chartView2.data?.yMin ?? 0 < minCap2Reading)
            {
                minCap2Reading = self.chartView2.data?.yMin ?? 0
                self.cap2MinValue.text = String(round(1000*minCap2Reading)/1000) + " pF"
            }
            if(self.chartView3.data?.yMin ?? 0 < minCap3Reading)
            {
                minCap3Reading = self.chartView3.data?.yMin ?? 0
                self.cap3MinValue.text = String(round(1000*minCap3Reading)/1000) + " pF"
            }
            if(self.chartView4.data?.yMin ?? 0 < minCap4Reading)
            {
                minCap4Reading = self.chartView4.data?.yMin ?? 0
                self.cap4MinValue.text = String(round(1000*minCap4Reading)/1000) + " pF"
            }
            
          
        }
//        else
//        {
//            if(self.chartView2.data?.yMax ?? 0 > maxCap2Reading)
//            {
//                maxCap2Reading = self.chartView2.data?.yMax ?? 0
//                self.cap2MaxValue.text = String(round(1000*maxCap2Reading)/1000) + " pF"
//            }
//
//            if(self.chartView2.data?.yMin ?? 0 < minCap2Reading)
//            {
//                minCap2Reading = self.chartView2.data?.yMin ?? 0
//                self.cap2MinValue.text = String(round(1000*minCap2Reading)/1000) + " pF"
//            }
//        }
        //Update cap Diff readings here because min and max of each get updated here
        cap1Diff = maxCap1Reading - minCap1Reading
        cap2Diff = maxCap2Reading - minCap2Reading
        cap3Diff = maxCap3Reading - minCap3Reading
        cap4Diff = maxCap4Reading - minCap4Reading
        self.cap1DiffValue.text = String(round(1000*cap1Diff)/1000) + " pF"
        self.cap2DiffValue.text = String(round(1000*cap2Diff)/1000) + " pF"
        self.cap3DiffValue.text = String(round(1000*cap3Diff)/1000) + " pF"
        self.cap4DiffValue.text = String(round(1000*cap4Diff)/1000) + " pF"
//        cap2Diff = maxCap2Reading - minCap2Reading
//        self.cap2DiffValue.text = String(round(1000*cap2Diff)/1000) + " pF"
    }

    /// IN PROGRESS !!
    /// TODO: optimize algorithm so it doesn't loop every time
    func peak_det(val: Double){

        yVals.append(val)
        yCount += 1

        if yCount > 200{
            var sys: [Int] = [0, 0, 0]   // peak
            var dia: [Int] = [0, 0, 0]   // dip

            let (signals,avgFilter,stdFilter) = ThresholdingAlgo(y: yVals, lag: 110, threshold: 2.9, influence: 0)
            // threshold > 2.9 will result in some data loss for peaks with current config of parameters (lag: 110, influence: 0)

            for i in 0...signals.count - 1 {
                if signals[i] > 0{
                    if signals[i-1] == 0 {
                        start = i
                    }
                }
                else if signals[i] == 0{
                    if i>0 && signals[i-1] > 0 {
                        end = i
                        sys.append(Int(Array(yVals[start...end]).max()!))
                        sys.removeFirst()

                        // TODO: measure every 3-5 cycles and display average
                        print("Systolic:", sys)
                    }
                }
            }
        }

    }

    /// prints to console the coordinate values that the user taps on from the graph
    func chartValueSelected(_ chartView: ChartViewBase, entry: ChartDataEntry, highlight: Highlight) {
        //print(entry)
//        let string = MyVariables.selection
    }

    /// reads in graph coordinate data from column A and B of XLSX file and stores it in an array of ChartDataEntry
    private func readInDataFromXlsx() {
        guard let file = XLSXFile(filepath: "/Users/Felicia/Documents/GitHub/venavitals/bpdata.xlsx")
            else {
            fatalError("XLSX file corrupted or does not exist")
        }


        var x: Double = 0.0
        var isX = true // distinguish x and y axis cell data

        for path in try! file.parseWorksheetPaths() {
            let worksheet = try! file.parseWorksheet(at: path)
            for row in worksheet.data?.rows ?? [] {
                for c in row.cells {
                    let val = Double(c.value!)!

                    if isX {
                        x = val
                        isX = false
                    }
                    else{
                        xlsxdata.insert(ChartDataEntry(x: x, y: val), at: xlsxdata.endIndex)
                        isX = true
                    }
                }
            }
        }
    }

    /// initializes chartView.data and sets properties of the dataset
    func setupChartData() {
        let set = LineChartDataSet()
        let set2 = LineChartDataSet()
        let set3 = LineChartDataSet()
        let set4 = LineChartDataSet()
        let red = UIColor(displayP3Red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)
        set.lineWidth = 2.5
        set.drawCirclesEnabled = false
        set.setColor(red)
        set2.lineWidth = 2.5
        set2.drawCirclesEnabled = false
        set2.setColor(red)
        set3.lineWidth = 2.5
        set3.drawCirclesEnabled = false
        set3.setColor(red)
        set4.lineWidth = 2.5
        set4.drawCirclesEnabled = false
        set4.setColor(red)

        self.chartView.data = LineChartData(dataSet: set)
        self.chartView.data?.setDrawValues(false)
//
        self.chartView2.data = LineChartData(dataSet: set2)
        self.chartView2.data?.setDrawValues(false)
        
        self.chartView3.data = LineChartData(dataSet: set3)
        self.chartView3.data?.setDrawValues(false)
        
        self.chartView4.data = LineChartData(dataSet: set4)
        self.chartView4.data?.setDrawValues(false)
    }
    

    /// initial configuration of the chartView (should only be called once at the start)
    private func configChart() {
        self.chartView.noDataText = "No Data Available"
        self.chartView.delegate = self

        // position
        //self.chartView.centerInSuperview()
       // self.chartView.width(to: view)
        self.chartView.height(175)

        // actions
        self.chartView.isUserInteractionEnabled = false
        self.chartView.dragEnabled = false
        self.chartView.pinchZoomEnabled = false

        // display
        self.chartView.chartDescription?.enabled = false
        self.chartView.xAxis.drawGridLinesEnabled = false
        self.chartView.xAxis.drawLabelsEnabled = false
        self.chartView.xAxis.drawAxisLineEnabled = false
        self.chartView.rightAxis.enabled = false
        self.chartView.leftAxis.enabled = true
        self.chartView.drawBordersEnabled = false
        self.chartView.legend.enabled = false
        self.chartView.legend.form = .none

        self.chartView2.noDataText = "No Data Available"
        self.chartView2.delegate = self

        // position
        //self.chartView.centerInSuperview()
        //self.chartView2.width(to: view)
        self.chartView2.height(175)

        // actions
        self.chartView2.isUserInteractionEnabled = false
        self.chartView2.dragEnabled = false
        self.chartView2.pinchZoomEnabled = false

        // display
        self.chartView2.chartDescription?.enabled = false
        self.chartView2.xAxis.drawGridLinesEnabled = false
        self.chartView2.xAxis.drawLabelsEnabled = false
        self.chartView2.xAxis.drawAxisLineEnabled = false
        self.chartView2.rightAxis.enabled = false
        self.chartView2.leftAxis.enabled = true
        self.chartView2.drawBordersEnabled = false
        self.chartView2.legend.enabled = false
        self.chartView2.legend.form = .none

        self.chartView3.noDataText = "No Data Available"
        self.chartView3.delegate = self

        // position
        //self.chartView.centerInSuperview()
     //   self.chartView3.width(to: view)
        self.chartView3.height(175)

        // actions
        self.chartView3.isUserInteractionEnabled = false
        self.chartView3.dragEnabled = false
        self.chartView3.pinchZoomEnabled = false

        // display
        self.chartView3.chartDescription?.enabled = false
        self.chartView3.xAxis.drawGridLinesEnabled = false
        self.chartView3.xAxis.drawLabelsEnabled = false
        self.chartView3.xAxis.drawAxisLineEnabled = false
        self.chartView3.rightAxis.enabled = false
        self.chartView3.leftAxis.enabled = true
        self.chartView3.drawBordersEnabled = false
        self.chartView3.legend.enabled = false
        self.chartView3.legend.form = .none
        
        // position
        //self.chartView.centerInSuperview()
        //self.chartView2.width(to: view)
        self.chartView4.height(175)

        // actions
        self.chartView4.isUserInteractionEnabled = false
        self.chartView4.dragEnabled = false
        self.chartView4.pinchZoomEnabled = false

        // display
        self.chartView4.chartDescription?.enabled = false
        self.chartView4.xAxis.drawGridLinesEnabled = false
        self.chartView4.xAxis.drawLabelsEnabled = false
        self.chartView4.xAxis.drawAxisLineEnabled = false
        self.chartView4.rightAxis.enabled = false
        self.chartView4.leftAxis.enabled = true
        self.chartView4.drawBordersEnabled = false
        self.chartView4.legend.enabled = false
        self.chartView4.legend.form = .none
        // sets dataset attributes
        setupChartData()
    }
}


extension FirstViewController {

  func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic,
                  error: Error?) {
    switch characteristic.uuid {
      case CAP1_CHAR_UUID:
        var readings = getCapReadings(from: characteristic)
        //add flag at the beginning of array to signify whether it is cap1 or cap2
        // 1.0 at the beginning of the readings array means its cap1
        // 0.0 at the beginning of the readings array means its cap2
        readings.insert(1.0, at: 0)
        update(readings)

      case CAP2_CHAR_UUID:
        var readings = getCapReadings(from: characteristic)
        readings.insert(0.0, at: 0)
        update(readings)
      default:
        print("Unhandled Characteristic UUID: \(characteristic.uuid)")
    }
  }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil else {
            print("Error discovering services: error")
          return
        }
         print("Message sent")
    }


    private func getCapReadings(from characteristic: CBCharacteristic) -> Array<Double> {
        //The following is based off of the callbacks.py in uci_cbp_demo->backend->bluetooth
//        printDate( string: "beginning of capGetReading: ")

      guard let characteristicData = characteristic.value else { return [] }
      let byteArray = [UInt8](characteristicData)
        print(byteArray.count)
        //Mag
        var readMagZ:Double = Double(byteArray[53]) * 256 + Double(byteArray[52])
        if(readMagZ >= 32768 )
        {
            // This check is to see if it is negative or not by checking if the first bit is 1 i.e. the reading of the small end byte is larger than 32768
          readMagZ = readMagZ - 65536
        }
        readMagZ = magFullScale * readMagZ
        var readMagY:Double = Double(byteArray[51]) * 256 + Double(byteArray[50])
        if(readMagY >= 32768 )
        {
          readMagY = readMagY - 65536
        }
        readMagY = magFullScale * readMagY
        var readMagX:Double = Double(byteArray[49]) * 256 + Double(byteArray[48])
        if(readMagX >= 32768 )
        {
          readMagX = readMagX - 65536
        }
        readMagX = magFullScale * readMagX
        //Gyro
        var readGyroZ:Double = Double(byteArray[47]) * 256 + Double(byteArray[46])
        if(readGyroZ >= 32768 )
        {
          readGyroZ = readGyroZ - 65536
        }
        readGyroZ = gyroFullScale * readGyroZ / 32768.0
        var readGyroY:Double = Double(byteArray[45]) * 256 + Double(byteArray[44])
        if(readGyroY >= 32768 )
        {
          readGyroY = readGyroY - 65536
        }
        readGyroY = gyroFullScale * readGyroY / 32768.0
        var readGyroX:Double = Double(byteArray[43]) * 256 + Double(byteArray[42])
        if(readGyroX >= 32768 )
        {
          readGyroX = readGyroX - 65536
        }
        readGyroX = gyroFullScale * readGyroX / 32768.0
        //Acc
        var readAccZ:Double = Double(byteArray[41]) * 256 + Double(byteArray[40])
        if(readAccZ >= 32768 )
        {
          readAccZ = readAccZ - 65536
        }
        readAccZ = accFullScale * readAccZ / 32768.0
        var readAccY:Double = Double(byteArray[39]) * 256 + Double(byteArray[38])
        if(readAccY >= 32768 )
        {
          readAccY = readAccY - 65536
        }
        readAccY = accFullScale * readAccY / 32768.0
        var readAccX:Double = Double(byteArray[37]) * 256 + Double(byteArray[36])
        if(readAccX >= 32768 )
        {
          readAccX = readAccX - 65536
        }
        readAccX = accFullScale * readAccX / 32768.0
        let capReading:Double =  (Double(byteArray[4])   + Double(byteArray[5]) * 256  + Double(byteArray[6]) * 256 * 256 + Double(byteArray[7]) * 256 * 256 * 256 ) * 8 / 16777215
        let capReading2:Double =  (Double(byteArray[8])   + Double(byteArray[9]) * 256  + Double(byteArray[10]) * 256 * 256 + Double(byteArray[11]) * 256 * 256 * 256) * 8 / 16777215
        let capReading3:Double =  (Double(byteArray[12])   + Double(byteArray[13]) * 256  + Double(byteArray[14]) * 256 * 256 + Double(byteArray[15]) * 256 * 256 * 256) * 8 / 16777215
        let capReading4:Double =  (Double(byteArray[16])   + Double(byteArray[17]) * 256  + Double(byteArray[18]) * 256 * 256 + Double(byteArray[19]) * 256 * 256 * 256) * 8 / 16777215
        let capReading5:Double =  (Double(byteArray[20])   + Double(byteArray[21]) * 256  + Double(byteArray[22]) * 256 * 256 + Double(byteArray[23]) * 256 * 256 * 256) * 8 / 16777215
        let capReading6:Double =  (Double(byteArray[24])   + Double(byteArray[25]) * 256  + Double(byteArray[26]) * 256 * 256 + Double(byteArray[27]) * 256 * 256 * 256) * 8 / 16777215
        let capReading7:Double =  (Double(byteArray[28])   + Double(byteArray[29]) * 256  + Double(byteArray[30]) * 256 * 256 + Double(byteArray[31]) * 256 * 256 * 256) * 8 / 16777215
        let capReading8:Double =  (Double(byteArray[32])   + Double(byteArray[33]) * 256  + Double(byteArray[34]) * 256 * 256 + Double(byteArray[35]) * 256 * 256 * 256) * 8 / 16777215
        
//        print(capReading)
//        print(capReading2)
//        print(capReading3)
//        print(capReading4)
//        print(capReading5)
//        print(capReading6)
//        print(capReading7)
//        print(capReading8)
        
//      capReading = 8 * capReading
//      capReading = capReading / 16777215
        print(round(100*capReading)/100,round(100*capReading2)/100,round(100*capReading3)/100,round(100*capReading4)/100,round(100*capReading5)/100,round(100*capReading6)/100,round(100*capReading7)/100,round(100*capReading8)/100)

      var time:Double = (Double(byteArray[1]) * 256 + Double(byteArray[0]))
      time = time * CLK_PERIOD
      if(maxTime == 0)
      {
        maxTime = time
        previousTime = time
      }
      if(time > previousTime)
      {
        let delta = time - previousTime
        previousTime = time
        maxTime +=  delta
        if(history.count == 100)
        {
            history.removeAll()
            //clear array every 100 values so it does not take up a lot of memory and possibly crash the app
        }
        history.append(delta)
      }
      else{
        previousTime = time
        if(history.count > 0)
        {
            let historySum = history.reduce(0,+)
            let historyAvg:Double = historySum/Double(history.count)
            maxTime += historyAvg
        }
      }
        let rate = 1/(maxTime - prev_time)
        if(rate > 100)
        {
            print("raw_time: ",time)
            print("max: ",maxTime)
            print("prev: ",prev_time)
            print("rate: ",1/(maxTime - prev_time))
        }
//        print("rate: ",1/(maxTime - prev_time))
        prev_time = maxTime
        //This array is formatted the same way the data is written to the file.
      return [maxTime, capReading, capReading2, capReading3, capReading4,capReading5,capReading6,capReading7,capReading8, readAccX, readAccY, readAccZ, readGyroX, readGyroY, readGyroZ, readMagX, readMagY, readMagZ]
//      return [maxTime, capReading5, capReading6, capReading7, capReading8,capReading, capReading2, capReading3, capReading4, readAccX, readAccY, readAccZ, readGyroX, readGyroY, readGyroZ, readMagX, readMagY, readMagZ]

    }


}

