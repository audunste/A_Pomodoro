//
//  ModelData.swift
//  A•Pomodoro
//
//  Created by Audun Steinholm on 18/12/2022.
//

import Foundation
import Combine

final class ModelData: ObservableObject {
    @Published var appColor = AppColor.pomodoroLight
}
