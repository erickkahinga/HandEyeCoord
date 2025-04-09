//
//  LidarModelApp2App.swift
//  LidarModelApp2
//
//  Created by Andre Grossberg on 4/6/25.
//

import SwiftUI
import ARKit

@main
struct LidarModelApp2App: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchinhWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        if !ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            print("does not support AR")
        }
        return true
    }
}
