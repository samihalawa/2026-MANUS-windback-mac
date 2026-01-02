import SwiftUI

struct TextInputTestApp: App {
    var body: some Scene {
        WindowGroup {
            TextTestView()
        }
    }
}

struct TextTestView: View {
    @State private var testResults: [String] = []
    @State private var isRunning = false
    
    var body: some View {
        VStack {
            Text("TextInput Test Application")
                .font(.largeTitle)
                .padding()
            
            Button("Run TextInput Tests") {
                runTests()
            }
            .buttonStyle(.borderedProminent)
            .padding()
            .disabled(isRunning)
            
            ScrollView {
                VStack(alignment: .leading) {
                    ForEach(testResults, id: \.self) { line in
                        Text(line)
                            .font(.system(.body, design: .monospaced))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.textBackgroundColor))
            .cornerRadius(8)
            .padding()
        }
        .frame(width: 800, height: 600)
    }
    
    private func runTests() {
        isRunning = true
        testResults = ["Starting tests..."]
        
        DispatchQueue.global(qos: .userInitiated).async {
            // TextInputTester.runTests()
            
            DispatchQueue.main.async {
                self.testResults.append("Tests completed")
                self.isRunning = false
            }
        }
    }
}

struct TextInputApp_Previews: PreviewProvider {
    static var previews: some View {
        TextInputApp()
        // Remove test call
        // .onAppear {
        //     TextInputTester.runTests()
        // }
    }
} 