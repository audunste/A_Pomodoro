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

private struct MainWindowSizeKey: EnvironmentKey {
    static let defaultValue: CGSize = .zero
}

typealias EnvAction = () -> Void

private struct ShareHistoryActionKey: EnvironmentKey {
    static var defaultValue: EnvAction? = nil
}

private struct UpActionKey: EnvironmentKey {
    static var defaultValue: EnvAction? = nil
}

extension EnvironmentValues {
    var mainWindowSize: CGSize {
        get { self[MainWindowSizeKey.self] }
        set { self[MainWindowSizeKey.self] = newValue }
    }
    var shareHistory: EnvAction? {
        get { self[ShareHistoryActionKey.self] }
        set { self[ShareHistoryActionKey.self] = newValue }
    }
    var up: EnvAction? {
        get { self[UpActionKey.self] }
        set { self[UpActionKey.self] = newValue }
    }
}
