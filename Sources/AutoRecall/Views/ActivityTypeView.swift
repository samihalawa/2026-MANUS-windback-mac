import SwiftUI

struct ActivityType {
    let name: String
    let icon: String  // System icon name
    let color: Color
}

struct ActivityTypeView: View {
    let type: ActivityType
    
    var body: some View {
        HStack {
            Image(systemName: type.icon)
                .foregroundColor(.white)
                .padding(8)
                .background(type.color)
                .clipShape(Circle())
            
            Text(type.name)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
} 