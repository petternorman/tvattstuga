import SwiftUI

struct LoginSheetView: View {
    @EnvironmentObject private var model: AppModel
    @FocusState private var focusedField: Field?

    private enum Field {
        case username
        case password
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Credentials") {
                    TextField("Username", text: $model.loginUsername)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .focused($focusedField, equals: .username)
                        .submitLabel(.next)
                        .onSubmit {
                            focusedField = .password
                        }

                    SecureField("Password", text: $model.loginPassword)
                        .focused($focusedField, equals: .password)
                        .submitLabel(.go)
                        .onSubmit {
                            Task {
                                await model.saveLogin()
                            }
                        }
                }

                if let error = model.loginError {
                    Section {
                        Text(error)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Button("Save and continue") {
                        Task {
                            await model.saveLogin()
                        }
                    }
                    .disabled(
                        model.loginUsername.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                        model.loginPassword.isEmpty
                    )
                }
            }
            .navigationTitle("Sign In")
            .toolbar {
                if model.signedInUsername != nil {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            model.dismissLoginSheet()
                        }
                    }
                }
            }
        }
        .onAppear {
            if model.loginUsername.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                focusedField = .username
            } else {
                focusedField = .password
            }
        }
    }
}
