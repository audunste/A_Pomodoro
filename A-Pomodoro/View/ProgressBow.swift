//
//  ProgressBow.swift
//  A-Pomodoro
//
//  Created by Audun Steinholm on 27/12/2022.
//

import SwiftUI


struct ProgressBow: View {
    let buttonText: String
    let remaining: Int32
    let total: Int32
    @Binding var tempRemaining: Int32?
    var adjustmentHandler: (Int32) -> Void
    var actionHandler: () -> Void
    
    @EnvironmentObject var modelData: ModelData
    @State var isDragging = false

    static let cut = 35.0
    static let endDeg = 90 - cut
    static let fullDegDelta = 360.0 - 2 * cut
    static let startDeg = endDeg - fullDegDelta
    static let endAngle = Angle.degrees(endDeg)
    static let startAngle = Angle.degrees(startDeg)

    var displayedRemaining: Int32 {
        tempRemaining ?? remaining
    }

    var body: some View {
        GeometryReader { geometry in

            let w = geometry.size.width
            let remainingFraction = Double(displayedRemaining) / Double(total)
            let knobDeg = ProgressBow.endDeg - ProgressBow.fullDegDelta * remainingFraction
            let or = 0.45 * w
            let ir = 0.35 * w
            let mr = 0.5 * (or + ir)
            let er = 0.5 * (or - ir)
            let cx = 0.5 * w
            let cy = 0.525 * w
            let sx = cx + __cospi(ProgressBow.startDeg / 180.0) * mr
            let sy = cy + __sinpi(ProgressBow.startDeg / 180.0) * mr
            let startPosition = CGPoint(x: sx, y: sy)
            let kx = cx + __cospi(knobDeg / 180.0) * mr
            let ky = cy + __sinpi(knobDeg / 180.0) * mr
            let knobPosition = CGPoint(x: kx, y: ky)

            Path { path in
                path.addArc(center: CGPoint(x: cx, y: cy), radius: 0.45 * w, startAngle:  ProgressBow.startAngle, endAngle: ProgressBow.endAngle, clockwise: false)
                path.addArc(center: CGPoint(x: cx + cos(Double(ProgressBow.endAngle.radians)) * mr, y: cy + sin(Double(ProgressBow.endAngle.radians)) * mr), radius: 0.5 * (or - ir), startAngle: ProgressBow.endAngle, endAngle: ProgressBow.endAngle + .degrees(180), clockwise: false)
                path.addArc(center: CGPoint(x: cx, y: cy), radius: 0.35 * w, startAngle: ProgressBow.endAngle, endAngle: ProgressBow.startAngle, clockwise: true)
                path.addArc(center: startPosition, radius: er, startAngle: ProgressBow.startAngle - .degrees(180), endAngle: ProgressBow.startAngle, clockwise: false)
            }
            .foregroundColor(.black)
            .opacity(isDragging ? 0.14 : 0.07)
            
            let knob = Path { path in
                path.addRelativeArc(center: knobPosition, radius: er * 1.3, startAngle: .degrees(0), delta: .degrees(360))
                
            }
            knob
            .fill(modelData.appColor.accentColor2)
            .shadow(radius: 3, y: 1)
            .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .named("parent"))
                .onChanged({ value in
                    if !isDragging {
                        isDragging = true
                        tempRemaining = remaining
                    } else {
                        let rad = atan2(value.location.y - cy, value.location.x - cx)
                        let deg = rad * 180.0 / Double.pi
                        var degDelta = deg - Self.startDeg
                        if degDelta > 360 {
                            degDelta -= 360
                        }
                        if degDelta > Self.fullDegDelta {
                            let overflow = degDelta - Self.fullDegDelta
                            if overflow > Self.cut {
                                degDelta = 0
                            } else {
                                degDelta = Self.fullDegDelta
                            }
                        }
                        let fraction = 1.0 - degDelta / Self.fullDegDelta
                        tempRemaining = Int32(Int(fraction * Double(total) / 10.0 + 0.5)) * 10
                    }
                })
                .onEnded({ value in
                    isDragging = false
                    if let newRemaining = tempRemaining {
                        adjustmentHandler(newRemaining)
                        tempRemaining = nil
                    }
                })
            )
            
            Button {
                print("apom toggle play/pause")
                actionHandler()
            } label: {
                Text(buttonText)
                .font(.system(size: round(0.06 * w)))
                .padding(.bottom, 4)
                .padding(.top, 4)
                .frame(width: 0.18 * w, height: 0.08 * w)
            }
            .foregroundColor(modelData.appColor.textColor)
            .buttonStyle(ProminentButton())
            .contentShape(Rectangle())
            .position(x: cx, y: startPosition.y + 0.025 * w)
            
            //.overlay(
            //    knob
            //    .stroke(modelData.appColor.textColor, lineWidth: 2)
            //)

            //Image(systemName: "ring.circle")
            //.resizable()
            //.frame(width: 24, height: 24)
            //.position(x: knobPosition.x, y: knobPosition.y)
            
            
        }
        .coordinateSpace(name: "parent")
    }
    
}

struct ProgressBowPreviewContainer: View {
    let remaining: Int32
    let total: Int32
    @State var tempRemaining: Int32?
    var body: some View {
        ProgressBow(buttonText: "Start", remaining: remaining, total: total, tempRemaining: $tempRemaining, adjustmentHandler: { newRemaining in }, actionHandler: {})
    }
}

struct ProgressBow_Previews: PreviewProvider {

    @State var tempRemaining: Int32?
    
    static var previews: some View {
        SquareZStack {
            ProgressBowPreviewContainer(remaining: 20 * 60, total: 25 * 60)
        }
        .withPreviewEnvironment("iPhone 14 Pro Max")
    }
}
