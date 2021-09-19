//
//  Medication.swift
//  MedTracker
//
//  Created by Nicolas Camenisch on 18.09.21.
//

import Foundation
import UIKit

struct Medication: Equatable {
 
    enum Identifier: String {
        case ALZA36 = "alza 36"
        case AZ036 = "az 036"
        case R194 = "R194"
        case RH046 = "RH 046"
        case RI52 = "RI52"
        case RP012 = "RP 012"
        case V = "v"
        
        case unknown = ""
    }
    
    let name: String
    let identifier: Identifier
    let dosage: Int
    let instruction: String
    
    let uid: String
    
    var image: UIImage? {
        switch self.identifier {
        case .ALZA36: return UIImage(named: "ALZA36")
        case .AZ036: return UIImage(named: "AZ036")
        case .R194: return UIImage(named: "R194")
        case .RH046: return UIImage(named: "RH046")
        case .RI52: return UIImage(named: "RI52")
        case .RP012: return UIImage(named: "RP012")
        case .V: return UIImage(named: "V")
        default: return nil
        }
    }
    
}
