import SwiftUI

struct SearchView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack {
            Text("Search View")
                .font(.largeTitle)
                .padding()
            
            Text("This is where you'll be able to search for screenshots, clipboard items, and text inputs.")
                .multilineTextAlignment(.center)
                .padding()
        }
    }
}

struct SearchView_Previews: PreviewProvider {
    static var previews: some View {
        SearchView()
            .environmentObject(AppState.shared)
    }
} 