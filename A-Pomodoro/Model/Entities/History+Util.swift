//
//  History+Util.swift
//  A-Pomodoro
//
//  Created by Audun Steinholm on 16/01/2023.
//

import Foundation

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
    
    public override var description: String {
        return self.ownerName ?? "Default"
    }

}
