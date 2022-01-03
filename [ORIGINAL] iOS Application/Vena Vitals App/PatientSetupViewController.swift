//
//  PatientSetupViewController.swift
//  Vena Vitals App
//
//  Created by Felicia Hou on 5/21/20.
//  Copyright © 2020 Tiffany Tran. All rights reserved.
//

import UIKit

class PatientSetupViewController: UIViewController,  UIPickerViewDelegate, UIPickerViewDataSource, UITextFieldDelegate {
    

    @IBOutlet weak var ageField: UITextField!
    @IBOutlet weak var genderField: UITextField!
    
    let agePickerData = [String](arrayLiteral: "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", "13", "14", "15", "16", "17", "18", "19", "20", "21", "22", "23", "24", "25", "26", "27", "28", "29", "30", "31", "32", "33", "34", "35", "36", "37", "38", "39", "40", "41", "42", "43", "44", "45", "46", "47", "48", "49", "50", "51", "52", "53", "54", "55", "56", "57", "58", "59", "60", "61", "62", "63", "64", "65", "66", "67", "68", "69", "70", "71", "72", "73", "74", "75", "76", "77", "78", "79", "80", "81", "82", "83", "84", "85", "86", "87", "88", "89", "90", "91", "92", "93", "94", "95", "96", "97", "98", "99", "100", "100+")
    
    let genderPickerData = [String](arrayLiteral: "Male", "Female")
    
    var itemSelected = ""
    
    weak var pickerView: UIPickerView?

override func viewDidLoad() {
        super.viewDidLoad()
    //allow tap on screen to remove text field input from screen
          self.view.addGestureRecognizer(UITapGestureRecognizer(target: self.view, action: #selector(UIView.endEditing(_:))))
    
        let pickerView = UIPickerView()
    pickerView.delegate = self
    pickerView.dataSource = self
    
    ageField.delegate = self
    genderField.delegate = self
    
    ageField.inputView = pickerView
    genderField.inputView = pickerView
    
    self.pickerView = pickerView
    
    
    
//        agePicker.delegate = self
//        ageField.inputView = agePicker

        
        
        // Do any additional setup after loading the view.
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
         self.pickerView?.reloadAllComponents()
     }
 // MARK: UIPickerView Delegation

 func numberOfComponents(in pickerView: UIPickerView) -> Int {
     return 1
 }

    func pickerView( _ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        if ageField.isFirstResponder{
             return agePickerData.count
         }else if genderField.isFirstResponder{
             return genderPickerData.count
         }
        return 0
 }

 func pickerView( _ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
    if ageField.isFirstResponder{
        return agePickerData[row]
    }else if genderField.isFirstResponder{
        return genderPickerData[row]
    }
    return nil
 // return agePickerData[row]
 }

    func pickerView( _ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        if ageField.isFirstResponder{
            let itemselected = agePickerData[row]
            ageField.text = itemselected
        }else if genderField.isFirstResponder{
            let itemselected = genderPickerData[row]
            genderField.text = itemselected
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
