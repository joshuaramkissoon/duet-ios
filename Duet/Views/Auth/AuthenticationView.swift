//
//  AuthenticationView.swift
//  Duet
//
//  Created by Joshua Ramkissoon on 19/05/2025.
//

import SwiftUI
import AuthenticationServices
import GoogleSignInSwift

struct AuthenticationView: View {
    @EnvironmentObject private var vm: AuthenticationViewModel
    @EnvironmentObject private var groupsVM: GroupsViewModel
    @EnvironmentObject private var toast: ToastManager
    @StateObject private var activityVM = ActivityHistoryViewModel()
    @State private var showingError = false
    
    @ViewBuilder
    private var authContent: some View {
        if vm.state == .unauthenticated {
            loginForm
        } else if vm.state == .authenticating {
            ProgressView("Signing in…")
        } else {                      // .authenticated
            ContentView(toast: toast, activityHistoryVM: activityVM)
        }
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            authContent
                .alert("Error", isPresented: $showingError, actions: {
                    Button("OK") { vm.errorMessage = nil }
                }, message: {
                    Text(vm.errorMessage ?? "An unknown error occurred")
                })
                .onChange(of: vm.errorMessage, { oldValue, newValue in
                    showingError = (newValue != nil)
                })
        }
        .toast($toast.state) 
    }
    
    private var loginForm: some View {
        VStack(spacing: 20) {
            Spacer()
            Image("duet")
              .resizable()
              .scaledToFit()
              .clipShape(
                RoundedRectangle(cornerRadius: 36, style: .continuous)
              )
              .padding(.horizontal, 40)
              .padding(.top, 20)
            
            Text("Welcome to Duet")
                .font(.largeTitle).bold()
                .foregroundStyle(Color.appPrimary)
            
            Text("Discover, collect, experience together")
                .font(.headline)
                .foregroundStyle(.gray.opacity(0.7))
                .padding(.bottom)
            
            // Apple Sign In
            SignInWithAppleButton(
                .signIn,
                onRequest: vm.prepareAppleSignIn,
                onCompletion: vm.handleAppleCompletion
            )
            .signInWithAppleButtonStyle(.black)
            .frame(height: 50)
            .cornerRadius(8)
            
            // Anonymous
            Button(action: vm.signInAnonymously) {
                if vm.isSigningInAnonymously {
                    ProgressView()
                } else {
                    Text("Sign in anonymously")
                        .font(.body)
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .foregroundStyle(.gray)
            .padding(.horizontal)
            
            Spacer()
        }
        .padding()
    }
}

// Helper to present alerts from optional String
extension Optional where Wrapped == String {
    var wrappedValue: String? { self }
}

#Preview {
    AuthenticationView()
}
