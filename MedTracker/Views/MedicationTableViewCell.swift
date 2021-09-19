//
//  MedicationTableViewCell.swift
//  MedTracker
//
//  Created by Nicolas Camenisch on 18.09.21.
//

import UIKit

class MedicationTableViewCell: UITableViewCell {

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
    
    func populate(medication: Medication, taken: Bool = false) {
        // Title Label
        let attributeString = NSMutableAttributedString(string: medication.name)
        
        if taken {
            attributeString.addAttribute(.strikethroughStyle, value: 2, range: NSMakeRange(0, attributeString.length))
        }
        
        self.titleLabel.attributedText = attributeString
        
        // Description Label
        self.descriptionLabel.text = medication.instruction
    }

}
