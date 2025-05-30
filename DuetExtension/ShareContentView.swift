import SwiftUI

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.white)
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.appPrimary)
            .cornerRadius(12)
            .shadow(color: .black.opacity(configuration.isPressed ? 0.1 : 0.25), radius: 6, y: 3)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}

struct ShareContentView: View {
    @ObservedObject var vm: ShareSheetViewModel

    var body: some View {
        ZStack {
            content
                .background(Color.appBackground.ignoresSafeArea())
        }
        .alert("Oops!", isPresented: .constant(vm.error != nil)) {
            Button("OK") { vm.error = nil }
        } message: {
            Text(vm.error ?? "")
        }
    }

    private var content: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    if let thumb = vm.thumbnailURL {
                        AsyncImage(url: thumb) { phase in
                            switch phase {
                            case .success(let img):
                                img
                                    .resizable()
                                    .aspectRatio(vm.thumbnailAspect, contentMode: .fit)
                                    .cornerRadius(12)
                                    .shadow(radius: 6)
                            case .failure(_):
                                placeholderThumb
                            case .empty:
                                placeholderThumb
                            @unknown default:
                                placeholderThumb
                            }
                        }
                        .frame(width: thumbnailWidth, height: thumbnailHeight)
                    }

                    if vm.sharedURL == nil {
                        Text("No URL detected")
                            .foregroundStyle(.secondary)
                    }

                    if !vm.groups.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Add to Group")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Menu {
                                Button("None") { vm.selectedGroup = nil }
                                ForEach(vm.groups) { g in
                                    Button(g.name) { vm.selectedGroup = g }
                                }
                            } label: {
                                HStack {
                                    Text(vm.selectedGroup?.name ?? "Select Group")
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                        .foregroundColor(.appPrimary)
                                        .font(.caption)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(Color.white)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.appPrimary.opacity(0.3), lineWidth: 1)
                                )
                                .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
                            }
                            .accentColor(.appPrimary)
                        }
                    }

                    Button(action: { vm.performShare() }) {
                        if vm.isSubmitting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .frame(maxWidth: .infinity)
                        } else {
                            Label("Add to Duet", systemImage: "paperplane.fill")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(vm.sharedURL == nil || vm.isSubmitting)
                }
                .padding()
            }
            .navigationTitle("Share to Duet")
        }
    }

    private var placeholderThumb: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.2))
            .frame(width: thumbnailWidth, height: thumbnailHeight)
            .cornerRadius(12)
    }
    
    // MARK: - Computed Properties for Thumbnail Dimensions
    
    private var thumbnailWidth: CGFloat {
        let isLandscape = vm.thumbnailAspect > 1
        if isLandscape {
            // Fill most of the available width when landscape, leaving some padding
            return UIScreen.main.bounds.width - 64 // account for padding
        } else {
            return 200 // fixed width for portrait videos
        }
    }

    private var thumbnailHeight: CGFloat {
        return thumbnailWidth / vm.thumbnailAspect
    }
}

#if DEBUG
#Preview {
    ShareContentView(vm: ShareSheetViewModel())
}
#endif 
