//
//  NSManagedObject+Util.swift
//  A-Pomodoro
//
//  Created by Audun Steinholm on 17/01/2023.
//

import Foundation
import CoreData

extension NSManagedObject {
    
    func debugString(with context: NSManagedObjectContext) -> String {
        let entityName = "\(Self.self)"
        guard let attributes = NSEntityDescription.entity(forEntityName: entityName, in: context)?.attributesByName else {
            return "error"
        }
        return attributes
            .map {
                ($0.key, descriptionOrNil(optional: self.value(forKey: $0.key)))
            }
            .map {
                "\($0.0)=\($0.1)"
            }
            .joined(separator: ", ")
    }
}
