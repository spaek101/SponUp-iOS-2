import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct SignInView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage: String?
    @State private var isShowingSignUp = false

    var onSignInSuccess: (UserRole, String) -> Void

    var isFormValid: Bool { !email.isEmpty && !password.isEmpty }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Sign In").font(.largeTitle.bold()).padding(.top, 40)

                TextField("Email", text: $email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.none)
                    .autocorrectionDisabled(true)
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(8)

                SecureField("Password", text: $password)
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(8)

                if let error = errorMessage {
                    Text(error).foregroundColor(.red).font(.caption)
                }

                Button(action: signIn) {
                    Text("Sign In")
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isFormValid ? Color.blue : Color.gray)
                        .cornerRadius(8)
                }
                .disabled(!isFormValid)

                Spacer()

                HStack {
                    Text("Don't have an account?")
                    Button { isShowingSignUp = true } label: {
                        Text("Sign Up").fontWeight(.bold).foregroundColor(.blue)
                    }
                }
                .padding(.bottom, 40)
                .navigationDestination(isPresented: $isShowingSignUp) {
                    SignUpView(onSignUpSuccess: onSignInSuccess)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func signIn() {
        errorMessage = nil
        Auth.auth().signIn(withEmail: email, password: password) { res, err in
            if let err = err {
                errorMessage = err.localizedDescription; return
            }
            guard let u = res?.user else {
                errorMessage = "Unknown error"; return
            }
            Firestore.firestore().collection("users").document(u.uid)
                .getDocument { doc, err in
                    if let err = err {
                        errorMessage = err.localizedDescription; return
                    }
                    guard
                        let data = doc?.data(),
                        let roleStr = data["role"] as? String,
                        let role = UserRole(rawValue: roleStr),
                        let fullName = data["fullName"] as? String
                    else {
                        errorMessage = "Invalid user record."; return
                    }
                    onSignInSuccess(role, fullName)
                }
        }
    }
}
