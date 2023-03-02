//
//  RemainingWidgetBundle.swift
//  RemainingWidget
//
//  Created by Audun Steinholm on 01/03/2023.
//

import WidgetKit
import SwiftUI

@main
struct RemainingWidgetBundle: WidgetBundle {
    var body: some Widget {
        RemainingWidget()
        RemainingWidgetLiveActivity()
    }
}
