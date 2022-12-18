//
//  TimerView.swift
//  A•Pomodoro
//
//  Created by Audun Steinholm on 16/12/2022.
//

import SwiftUI

struct TimerView: View {

    var seconds: Int32
    @State var timer: Timer? = nil
    @State var remaining: Int32

    init(_ minutes: Int32) {
        seconds = minutes * 60
        remaining = seconds
    }

    var body: some View {
        VStack {
            Text(String(format: "%02d:%02d", (remaining / 60), remaining % 60))
            .font(.system(size: 60).monospacedDigit())
            if (timer == nil) {
                Button("Start") {
                    remaining = seconds
                    timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true)
                    { t in
                        remaining -= 1
                        if (remaining <= 0) {
                            t.invalidate()
                            timer = nil
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .font(.system(size: 24))
                .padding(16)
            } else {
                Button("Stop") {
                    remaining = seconds
                    timer!.invalidate()
                    timer = nil
                }
                .buttonStyle(.borderedProminent)
                .font(.system(size: 24))
                .padding(16)
            }
        }
    }
}

struct TimerView_Previews: PreviewProvider {
    static var previews: some View {
        TimerView(25)
    }
}
