//
//  History+Util.swift
//  A-Pomodoro
//
//  Created by Audun Steinholm on 16/01/2023.
//

import Foundation
import CoreData

extension History {

    func getCategoryLike(_ dup: Category) -> Category? {
        guard let categories = self.categories else {
            return nil
        }
        for case let category as Category in categories {
            if dup.title == category.title
                && dup.color == category.color
            {
                return category
            }
        }
        return nil
    }
    
    func clone(into context: NSManagedObjectContext) -> History {
        let clone = History(context: context)
        
        for (key, _) in History.entity().attributesByName {
            clone.setValue(self.value(forKey: key), forKey: key)
        }

        if let categories = self.categories {
            for case let category as Category in categories {
                clone.addToCategories(category.clone(into: context))
            }
        }
        
        return clone
    }
    
    var isMine: Bool {
        if let share = PersistenceController.shared.getShare(for: self) {
            return share.owner == share.currentUserParticipant
        }
        return true
    }
    
    public override var description: String {
        return self.ownerName ?? "Default"
    }

}
