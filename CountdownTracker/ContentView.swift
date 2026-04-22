import SwiftUI

/// Root view. Shows a brief splash (app icon + title) on cold launch, then
/// fades into `HomeView` — the WhatsApp-style entry pattern.
///
/// The splash only runs once per process, so returning from the background
/// does NOT re-show it. iOS's own launch screen covers sub-second launches;
/// this splash adds a brief branded beat on top.
struct ContentView: View {
    @State private var showSplash = true

    var body: some View {
        ZStack {
            HomeView()
                .opacity(showSplash ? 0 : 1)

            if showSplash {
                SplashView()
                    .transition(.opacity)
            }
        }
        .task {
            // ~1.2s is long enough to register the brand without feeling like
            // the app is slow. Matches WhatsApp/Instagram-style launches.
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            withAnimation(.easeOut(duration: 0.35)) {
                showSplash = false
            }
        }
    }
}

private struct SplashView: View {
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Image("SplashIcon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                    .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 6)

                Text("Countdowns")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.primary)
            }
        }
    }
}
