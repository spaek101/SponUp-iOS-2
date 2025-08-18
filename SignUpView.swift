import SwiftUI
import FirebaseAuth
import FirebaseFirestore

enum UserRole: String, CaseIterable, Identifiable {
    case athlete = "Athlete"
    case sponsor = "Sponsor"
    
    var id: String { rawValue }
}

struct SignUpView: View {
    @State private var role: UserRole = .athlete
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var fullName = ""
    @State private var dateOfBirth = Date()
    
    @State private var errorMessage: String? = nil

    // Updated callback to pass fullName as well
    var onSignUpSuccess: (UserRole, String) -> Void

    var isFormValid: Bool {
        !email.isEmpty &&
        !password.isEmpty &&
        password == confirmPassword &&
        !fullName.isEmpty
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Select Role") {
                    Picker("Role", selection: $role) {
                        ForEach(UserRole.allCases) { role in
                            Text(role.rawValue).tag(role)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Section("Account Info") {
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .autocapitalization(.none)
                    
                    SecureField("Password", text: $password)
                        .textContentType(.newPassword)
                    
                    SecureField("Confirm Password", text: $confirmPassword)
                        .textContentType(.newPassword)
                }
                
                Section("Personal Info") {
                    TextField("Full Name", text: $fullName)
                        .autocapitalization(.words)
                    
                    DatePicker(
                        "Date of Birth",
                        selection: $dateOfBirth,
                        in: ...Date(),
                        displayedComponents: .date
                    )
                    .environment(\.locale, Locale(identifier: "en_US_POSIX"))
                }
                
                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }
                
                Section {
                    Button("Sign Up") {
                        signUp()
                    }
                    .disabled(!isFormValid)
                }
            }
            .navigationTitle("Sign Up")
        }
    }
    
    func signUp() {
        guard isFormValid else {
            errorMessage = "Please fill all fields correctly."
            return
        }
        
        errorMessage = nil
        
        Auth.auth().createUser(withEmail: email, password: password) { result, error in
            if let error = error {
                DispatchQueue.main.async {
                    errorMessage = error.localizedDescription
                }
                return
            }
            
            guard let user = result?.user else {
                DispatchQueue.main.async {
                    errorMessage = "Unexpected error occurred."
                }
                return
            }
            
            let db = Firestore.firestore()
            let userData: [String: Any] = [
                "email": email,
                "fullName": fullName,
                "dateOfBirth": Timestamp(date: dateOfBirth),
                "role": role.rawValue
            ]
            
            db.collection("users").document(user.uid).setData(userData) { err in
                DispatchQueue.main.async {
                    if let err = err {
                        errorMessage = "Failed to save user profile: \(err.localizedDescription)"
                    } else {
                        // Pass both role and fullName on success
                        onSignUpSuccess(role, fullName)
                    }
                }
            }
        }
    }
}
