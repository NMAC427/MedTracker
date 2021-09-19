//
//  LoginViewController.swift
//  MedTracker
//
//  Created by Nicolas Camenisch on 18.09.21.
//

import UIKit

class LoginViewController: UIViewController {

    @IBOutlet weak var usernameTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    @IBAction func loginButtonPressed(_ sender: Any) {
        // Segue is handled in Storyboard
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        switch segue.identifier {
        case "medicationSegue":
            guard let destinationVC = segue.destination as? MedicationTableViewController else {
                break
            }
            
            destinationVC.username = self.usernameTextField.text ?? ""
        default: break
        }
    }
    
}
