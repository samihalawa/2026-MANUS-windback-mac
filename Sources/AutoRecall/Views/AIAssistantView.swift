import SwiftUI

struct TextAIAssistantView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack {
            Text("AI Assistant")
                .font(.largeTitle)
                .padding()
            
            Text("This is where the AI assistant features will be implemented.")
                .multilineTextAlignment(.center)
                .padding()
        }
    }
}

struct TextAIAssistantView_Previews: PreviewProvider {
    static var previews: some View {
        TextAIAssistantView()
            .environmentObject(AppState.shared)
    }
} 