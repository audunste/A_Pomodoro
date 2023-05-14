//
//  TaskView.swift
//  A-Pomodoro
//
//  Created by Audun Steinholm on 01/05/2023.
//

import SwiftUI

struct TaskView: View {
    var body: some View {
        GeometryReader { geometry in
            if geometry.size.width > geometry.size.height {
                Text("Temp")
            } else {
                Text("Temp")
            }
        }
    }
}

struct TaskView_Previews: PreviewProvider {
    static var previews: some View {
        TaskView()
        .previewDisplayName("SE portrait")
        .withPreviewEnvironment("iPhone SE (3rd generation)")
        
        TaskView()
        .previewDisplayName("SE landscape")
        .withPreviewEnvironment("iPhone SE (3rd generation)")
        .previewInterfaceOrientation(.landscapeLeft)

        TaskView()
        .withPreviewEnvironment("iPhone 14 Pro Max")
        
        TaskView()
        .withPreviewEnvironment("iPad (10th generation)")
        
    }
}
