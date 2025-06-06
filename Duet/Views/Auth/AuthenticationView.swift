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
    @EnvironmentObject private var activityVM: ActivityHistoryViewModel
    @EnvironmentObject private var creditUIManager: CreditUIManager
    @State private var showingError = false
    @State private var showingTermsOfService = false
    @State private var showingPrivacyPolicy = false
    
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
                .onChange(of: vm.state) { oldValue, newValue in
                    // Initialize credit data when user becomes authenticated
                    if newValue == .authenticated && oldValue != .authenticated {
                        Task {
                            await CreditService.shared.refreshCreditData()
                        }
                    }
                }
        }
        .sheet(isPresented: $creditUIManager.showCreditsView) {
            CreditsView()
        }
        .sheet(isPresented: $creditUIManager.showPurchaseCreditsSheet) {
            PurchaseCreditsSheet()
        }
        .sheet(isPresented: $showingTermsOfService) {
            TermsOfServiceView(isPresented: $showingTermsOfService)
        }
        .sheet(isPresented: $showingPrivacyPolicy) {
            PrivacyPolicyView(isPresented: $showingPrivacyPolicy)
        }
        .toast($toast.state) 
    }
    
    private var loginForm: some View {
        VStack(spacing: 20) {
            Spacer()
            Image("duet-landing")
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
            
            // Terms of Service Agreement
            VStack(spacing: 8) {
                Text("By signing up, you agree to our")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 4) {
                    Button(action: {
                        showingTermsOfService = true
                    }) {
                        Text("Terms of Service")
                            .font(.caption)
                            .foregroundColor(.appPrimary)
                            .underline()
                    }
                    
                    Text("and")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button(action: {
                        showingPrivacyPolicy = true
                    }) {
                        Text("Privacy Policy")
                            .font(.caption)
                            .foregroundColor(.appPrimary)
                            .underline()
                    }
                }
            }
            .padding(.top, 16)
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - Terms of Service View

struct TermsOfServiceView: View {
    @Binding var isPresented: Bool
    @State private var isLoading = true
    
    var body: some View {
        NavigationView {
            ZStack {
                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Loading Terms of Service...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                } else {
                    WebView(url: URL(string: "\(NetworkClient.shared.baseUrl)/terms")!)
                }
            }
            .navigationTitle("Terms of Service")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
            .onAppear {
                // Small delay to show loading state briefly
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isLoading = false
                }
            }
        }
    }
}

// MARK: - Privacy Policy View

struct PrivacyPolicyView: View {
    @Binding var isPresented: Bool
    @State private var isLoading = true
    
    var body: some View {
        NavigationView {
            ZStack {
                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Loading Privacy Policy...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                } else {
                    WebView(url: URL(string: "\(NetworkClient.shared.baseUrl)/privacy")!)
                }
            }
            .navigationTitle("Privacy Policy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
            .onAppear {
                // Small delay to show loading state briefly
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isLoading = false
                }
            }
        }
    }
}

// MARK: - WebView for Terms of Service

import WebKit

struct WebView: UIViewRepresentable {
    let url: URL
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        let request = URLRequest(url: url)
        webView.load(request)
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        // No updates needed
    }
}

// Helper to present alerts from optional String
extension Optional where Wrapped == String {
    var wrappedValue: String? { self }
}

#Preview {
    AuthenticationView()
}
