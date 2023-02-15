//
//  ReciprocateView.swift
//  A-Pomodoro
//
//  Created by Audun Steinholm on 11/02/2023.
//

import SwiftUI

struct ReciprocateView: View {

    @EnvironmentObject var modelData: ModelData
    @EnvironmentObject var historyModel: HistoryModel
    let buttonFontSize: CGFloat = 14
    let textFontSize: CGFloat = 15

    var shouldOfferReciprocation: Bool {
        guard let person = historyModel.activePerson else {
            return false
        }
        return !person.isYou && person.isReciprocating == nil
    }
    
    var activePersonName: String {
        guard let person = historyModel.activePerson else {
            return ""
        }
        return person.name
    }
    
    var isProcessing: Bool {
        historyModel.processingReciprocationForId == historyModel.activeId
    }
    
    var actionColor: Color {
        return isProcessing ? Color("DisabledText") : Color("PrimaryText")
    }

    var body: some View {
        if shouldOfferReciprocation {
            VStack(alignment: .leading) {
                Text(String(format: NSLocalizedString("Share your own history with %@?", comment: "When asked to reciprocate a share"), activePersonName))
                .font(.system(size: textFontSize))
                .frame(maxWidth: .infinity)
                .fixedSize(horizontal: true, vertical: false)
                .padding(EdgeInsets(top: 12, leading: 18, bottom: 0, trailing: 18))
                
                HStack {
                    Spacer()
                    .frame(maxWidth: .infinity)
                    
                    if isProcessing {
                        ProgressView()
                        .padding(.trailing, 12)
                    }
                    
                    Button {
                        historyModel.reciprocateNotNow()
                    } label: {
                        Text(NSLocalizedString("Not now", comment: "Action").uppercased())
                        .font(.system(size: buttonFontSize, weight: .semibold))
                        .foregroundColor(actionColor)
                        .padding(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    }
                    .disabled(isProcessing)
                    
                    Button {
                        historyModel.reciprocateShare()
                    } label: {
                        Text(NSLocalizedString("Share", comment: "Action").uppercased())
                        .font(.system(size: buttonFontSize, weight: .semibold))
                        .foregroundColor(actionColor)
                        .padding(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    }
                    .disabled(isProcessing)
                    .padding(.leading, 12)
                }
                .padding(EdgeInsets(top: 0, leading: 18, bottom: 4, trailing: 18))
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
    static let persistentContainer = PersistenceController.preview.persistentContainer
    static var previews: some View {
        ZStack {
            ReciprocateView()
        }
        .withPreviewEnvironment("iPhone SE (3rd generation)")
        .environmentObject(PreviewHistoryModel(viewContext: persistentContainer.viewContext, peopleCount: 2, reciprocate: true) as HistoryModel)
        .frame(width: 375)
    }
}
