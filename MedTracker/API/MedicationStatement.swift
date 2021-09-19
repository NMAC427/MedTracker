//
//  MedicationStatement.swift
//  MedTracker
//
//  Created by Nicolas Camenisch on 19.09.21.
//

import Foundation

struct MedicationStatementRequest: Codable {
    var entry: [Entry]
    
    struct Entry: Codable {
        var resource: MedicationStatement
    }
}

struct MedicationStatement: Codable {
    
    var id: String
    var dosage: [Dosage]
    var status: String
    var medicationCodeableConcept: CodeableConcept?
 
    struct Dosage: Codable {
        var text: String?
        var doseAndRate: [DoseAndRate]
        
        struct DoseAndRate: Codable {
            var doseQuantity: Quantity
            
            struct Quantity: Codable {
                var value: Int
            }
        }
    }
    
    struct CodeableConcept: Codable {
        var id: String?
        var text: String?
    }
    
    func toMedication() -> [Medication] {
        return self.dosage.map { d in
            Medication(name: self.medicationCodeableConcept?.text ?? "Unknown Medication",
                       identifier: Medication.Identifier(rawValue: self.medicationCodeableConcept?.id ?? "") ?? .unknown,
                       dosage: d.doseAndRate.first?.doseQuantity.value ?? 1,
                       instruction: d.text ?? "",
                       uid: self.id)
        }
    }
    
}
