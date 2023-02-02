//
//  ReciprocateView.swift
//  A-Pomodoro
//
//  Created by Audun Steinholm on 11/02/2023.
//

import SwiftUI

struct ReciprocateView: View {

    @EnvironmentObject var modelData: ModelData
    @EnvironmentObject var historyViewModel: HistoryViewModel
    let buttonFontSize: CGFloat = 14
    let textFontSize: CGFloat = 15

    var shouldOfferReciprocation: Bool {
        guard let person = historyViewModel.activePerson else {
            return false
        }
        return !person.isYou && person.isReciprocating == nil
    }
    
    var activePersonName: String {
        guard let person = historyViewModel.activePerson else {
            return ""
        }
        return person.name
    }

    var body: some View {
        if shouldOfferReciprocation {
            VStack(alignment: .leading) {
                Text(String(format: NSLocalizedString("Share your own history with %@?", comment: "When asked to reciprocate a share"), activePersonName))
                .font(.system(size: textFontSize))
                .frame(maxWidth: .infinity)
                .fixedSize(horizontal: true, vertical: false)
                .padding(EdgeInsets(top: 12, leading: 18, bottom: 8, trailing: 18))
                
                HStack {
                    Spacer()
                    .frame(maxWidth: .infinity)
                    
                    Button {
                        historyViewModel.reciprocateNotNow()
                    } label: {
                        Text(NSLocalizedString("Not now", comment: "Action").uppercased())
                        .font(.system(size: buttonFontSize, weight: .semibold))
                    }
                    
                    Button {
                        historyViewModel.reciprocateShare()
                    } label: {
                        Text(NSLocalizedString("Share", comment: "Action").uppercased())
                        .font(.system(size: buttonFontSize, weight: .semibold))
                    }
                    .padding(.leading, 12)
                }
                .padding(EdgeInsets(top: 0, leading: 18, bottom: 12, trailing: 18))
            }
            .frame(maxWidth: .infinity)
            .background(Color("BannerBackground"))
            .foregroundColor(Color("PrimaryText"))
        } else {
            EmptyView()
        }
    }
}

struct ReciprocateView_Previews: PreviewProvider {
    static var previews: some View {
        ReciprocateView()
        .withPreviewEnvironment("iPhone SE (3rd generation)")
        .frame(width: 375)
    }
}
