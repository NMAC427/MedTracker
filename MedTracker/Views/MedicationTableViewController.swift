//
//  MedicationTableViewController.swift
//  MedTracker
//
//  Created by Nicolas Camenisch on 18.09.21.
//

import UIKit

class MedicationTableViewController: UITableViewController, ScanViewControllerDelgate {
    
    var username = ""
    var medications = [Medication]()
    //    [
    //        Medication(name: "Multivitamin", identifier: .V, dosage: 1, instruction: "Take one pill in the morning before breakfast."),
    //        Medication(name: "Pink Pill", identifier: .RH046, dosage: 1, instruction: "Are you ready to taste the rainbow?\nIf not, this is the perfect pill for you. It has only one color."),
    //        Medication(name: "Round one", identifier: .AZ036, dosage: 3, instruction: "Idk...\nJust don't swallow it.")
    //    ]
    
    var takenMedication = [String]()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let api = FHIR()
        api.login(username: self.username, password: "")
        api.getMedicationStatement() { result in
            guard case .success(let statements) = result else {
                return
            }
            
            self.medications = statements.flatMap { $0.toMedication() }
            self.tableView.reloadData()
        }
    }
    
    func medicationTaken(_ medication: Medication) {
        self.takenMedication.append(medication.uid)
        self.tableView.reloadData()
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return medications.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as! MedicationTableViewCell
        let medication = self.medications[indexPath.row]
        
        cell.populate(medication: medication, taken: takenMedication.contains(medication.uid))

        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let medication = self.medications[indexPath.row]
        self.performSegue(withIdentifier: "scanSegue", sender: medication)
    }

    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        switch segue.identifier {
        case "scanSegue":
            guard let destinationVC = segue.destination as? ScanViewController, let medication = sender as? Medication else {
                return
            }
            
            destinationVC.medication = medication
            destinationVC.delegate = self
        default: return
        }
    }

}
