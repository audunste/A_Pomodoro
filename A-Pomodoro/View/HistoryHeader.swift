//
//  HistoryHeader.swift
//  A-Pomodoro
//
//  Created by Audun Steinholm on 08/01/2023.
//

import SwiftUI

struct HistoryHeader: View {
    @EnvironmentObject private var viewModel: HistoryViewModel
    @EnvironmentObject private var modelData: ModelData

    static func calcItemWidth(_ width: CGFloat, _ peopleCount: Int) -> CGFloat {
        switch peopleCount {
        case 0, 1:
            return width - 2 * 16
        case 2:
            return (width - 2 * 16 - 8) / 2
        default:
            return (width - 16 - 2 * 8) / 2.5
        }
    }
    
    static func getItemWidth(_ index: Int, _ count: Int, _ width: CGFloat) -> CGFloat {
        let extraFactor: CGFloat = index == 0 ? 1 : 0
        let extra: CGFloat = 32
        switch count {
        case 0, 1:
            return width - 2 * 16
        case 2:
            return (width - 2 * 16 - 8 - extra) / 2 + extra * extraFactor
        default:
            return (width - 16 - 2 * 8 - extra - 32) / 2 + extra * extraFactor
        }
    }

    var body: some View {
        GeometryReader { geometry in
            let w = geometry.size.width

            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(Array(viewModel.people.enumerated()), id: \.element) {
                        index, person in
                        HeaderItem(person: person, isSelected: viewModel.activeId == person.id)
                        .frame(
                            width: Self.getItemWidth(index, viewModel.people.count, w),
                            height: 56)
                    }
                    if viewModel.people.isEmpty {
                        Text("Empty people array")
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.leading, 16)
                .padding(.trailing, 16)
            }
            .scrollIndicators(.hidden)
            .frame(maxHeight: .infinity)
            .background(modelData.appColor.backgroundColor)
            .foregroundColor(modelData.appColor.textColor)
        }
    }
}

struct HeaderItem: View {
    let person: Person
    let isSelected: Bool
    
    @Environment(\.shareHistory) var shareHistory
    @EnvironmentObject var historyViewModel: HistoryViewModel

    let largeFontSize: CGFloat = 14
    let smallFontSize: CGFloat = 12

    var body: some View {
        Button {
            ALog("tap HeaderItem")
            historyViewModel.activeId = person.id
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 0) {
                    Text(person.isYou
                        ? NSLocalizedString("Your history", comment: "History header")
                        : person.name)
                    .font(.system(size: largeFontSize, weight: .semibold))
                    .padding(.top, 8)
                    .padding(.leading, 16)
                    
                    Text(String(format: NSLocalizedString("%d pomodoro(s)", comment: "Number of pomodoros finished"), person.pomodoroCount))
                    .font(.system(size: smallFontSize, weight: .regular))
                    .frame(alignment: .topLeading)
                    .padding(.top, 8)
                    .padding(.leading, 16)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                
                if person.isYou {
                    Button {
                        ALog("try share")
                        shareHistory?()
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                        .frame(width: 24, height: 24)
                    }
                    Spacer().frame(width: 10)
                }
            }
        }
        .background(Color(white: isSelected ? 0.0 : 1.0, opacity: 0.07))
        .buttonStyle(UnstyledButton())
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .cornerRadius(16)
    }
}


struct HistoryHeader_Previews: PreviewProvider {
    static let persistentContainer = PersistenceController.preview.persistentContainer
    
    static var previews: some View {
        HistoryHeader()
        .withPreviewEnvironment("iPhone SE (3rd generation)")
        .frame(width: 375, height: 72)
        .border(.gray)
        .environmentObject(PreviewHistoryViewModel(viewContext: persistentContainer.viewContext, peopleCount: 3) as HistoryViewModel)
    }
}
