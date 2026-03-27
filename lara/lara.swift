//
//  lara.swift
//  lara
//
//  Created by ruter on 23.03.26.
//

import SwiftUI

@main
struct lara: App {
    init() {
        globallogger.capture()
    }

    var body: some Scene {
        WindowGroup {
            TabView {
                Tab("lara", systemImage: "ant.fill") {
                    ContentView()
                }

                Tab("Logs", systemImage: "text.document.fill") {
                    LogsView(logger: globallogger)
                }
            }
            .onAppear {
                init_offsets()
            }
        }
    }
}
