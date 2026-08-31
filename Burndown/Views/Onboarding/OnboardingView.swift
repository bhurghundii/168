import SwiftUI

struct OnboardingView: View {
    let onFinish: () -> Void
    @State private var pageIndex = 0

    private var isLastPage: Bool {
        pageIndex == OnboardingPage.pages.count - 1
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 20) {
                TabView(selection: $pageIndex) {
                    ForEach(OnboardingPage.pages) { page in
                        OnboardingPageView(page: page)
                            .tag(page.id)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                HStack(spacing: 8) {
                    ForEach(OnboardingPage.pages) { page in
                        Circle()
                            .fill(page.id == pageIndex ? Color("AccentBurn") : Color.white.opacity(0.2))
                            .frame(width: 7, height: 7)
                    }
                }

                Button {
                    if isLastPage {
                        onFinish()
                    } else {
                        withAnimation {
                            pageIndex += 1
                        }
                    }
                } label: {
                    Text(isLastPage ? "Get Started" : "Next")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color("AccentBurn"))
                .padding(.horizontal, 32)
                .padding(.bottom, 24)
            }
        }
    }
}
