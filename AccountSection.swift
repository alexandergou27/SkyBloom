import SwiftUI

struct AccountSection: View {
    @EnvironmentObject private var auth: AuthManager
    @State private var confirmSignOut = false
    @State private var confirmDelete = false
 
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("ACCOUNT")
                .font(.caption.weight(.semibold))
          
            HStack(spacing: 12) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.regular)
                VStack(alignment: .leading, spacing: 2) {
                    Text(auth.displayName)
                        .font(.headline)
                        .foregroundStyle(Color.textPrimary)
                    if let email = auth.email {
                        Text(email)
                            .font(.subheadline)
                            .foregroundStyle(Color.textSecondary)
                    }
                }
            }
            Divider()
          
            Button { confirmSignOut = true} label: { Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right") }
              .foregroundStyle(Color.regular)
            Button(role: .destructive) { confirmDelete = true} label: { Label("Delete Account", systemImage: "trash") }
          
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .confirmationDialog("Sign out of your account?", isPresented: $confirmSignOut, titleVisibility: .visible) {
            Button("Sign Out", role: .destructive) { auth.signOut() }
        }
        .confirmationDialog("Delete your account? This is permanent.",
                            isPresented: $confirmDelete,
                            titleVisibility: .visible) {
            Button("Delete Account", role: .destructive) {
                Task { await auth.deleteAccount() }
            }
        }
    }
}

