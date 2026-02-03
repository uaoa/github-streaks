// Minimal file to test compilation
import SwiftUI

@main
struct TestApp: App {
    var body: some Scene {
        WindowGroup {
            VStack {
                Text("Test")
                Button("Test Button") { }
                    .buttonStyle(.bordered)
            }
            .frame(width: 200, height: 100)
        }
    }
}