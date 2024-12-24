//
//  statusApp.swift
//  status
//
//  Created by 송창석 on 12/20/24.
//

import SwiftUI
import FirebaseCore

@main
struct statusApp: App {
    init() {
        FirebaseApp.configure()
    }
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
