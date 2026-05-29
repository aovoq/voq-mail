import SwiftUI

struct ContentView: View {
    var body: some View {
        MainMailSplitView()
            .background(WindowChromeConfigurator())
            .ignoresSafeArea(.container, edges: .top)
    }
}

#Preview {
    ContentView()
}
