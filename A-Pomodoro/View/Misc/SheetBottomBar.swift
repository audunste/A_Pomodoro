//
//  SheetBottomBar.swift
//  A-Pomodoro
//
//  Created by Audun Steinholm on 15/02/2023.
//

import SwiftUI

struct SheetBottomBar: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        HStack {
            Spacer()
            Button {
                dismiss()
            } label: {
                Text("Close")
            }
            .buttonStyle(NormalButton())
            Spacer()
            .frame(width: 16)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 56)
        .background(Color("BarBackground"))
        .foregroundColor(Color("BarText"))
    }
}


struct SheetBottomBar_Previews: PreviewProvider {
    static var previews: some View {
        SheetBottomBar()
    }
}
