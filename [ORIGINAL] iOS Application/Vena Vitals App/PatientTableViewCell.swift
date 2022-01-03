//
//  PatientTableViewCell.swift
//  Vena Vitals App
//
//  Created by Felicia Hou on 5/18/20.
//  Copyright © 2020 Tiffany Tran. All rights reserved.
//

import UIKit

class PatientTableViewCell: UITableViewCell {
    
    //MARK: Properties
    @IBOutlet weak var patientLabel: UILabel!
    @IBOutlet weak var rightArrowImageView: UIView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
