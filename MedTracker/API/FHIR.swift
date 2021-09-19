//
//  FHIR.swift
//  MedTracker
//
//  Created by Nicolas Camenisch on 19.09.21.
//

import Foundation
import Alamofire

class FHIR {
    
    private let API_KEY = "uktAVcVaPI7wwDJ8Gc5rE2JW1LToX8Vc99CkcZw3"
    
    // ----
    
    private var patient: String = ""
    
    func login(username: String, password: String) {
        // This function is just a mockup...
        switch username {
        case "1": self.patient = "Patient/10039"
        default: self.patient = "Patient/100236"
        }
    }
    
    func getMedicationStatement(completionHandler: @escaping (Result<[MedicationStatement], Error>) -> Void) {
        
        let headers = HTTPHeaders([
            HTTPHeader(name: "accept", value: "application/fhir+json"),
            HTTPHeader(name: "x-api-key", value: API_KEY)
        ])
        
        AF.request("https://fhir.dd76mdmqa8vg.static-test-account.isccloud.io/MedicationStatement?patient=\(self.patient.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")",
                   method: .get, headers: headers).validate().responseDecodable(of: MedicationStatementRequest.self, decoder: JSONDecoder()) { response in
            guard case .success(let r) = response.result else {
                completionHandler(.failure(response.error ?? NSError()))
                return
            }
            
            let statements = r.entry.map({ $0.resource })
            completionHandler(.success(statements))
        }
        
    }
    
}
