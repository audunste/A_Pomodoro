//
//  ViewUtil.swift
//  A-Pomodoro
//
//  Created by Audun Steinholm on 30/12/2022.
//

import SwiftUI

extension View {
    func Print(_ item: Any) -> some View {
        #if DEBUG
        print(item)
        #endif
        return self
    }
}
