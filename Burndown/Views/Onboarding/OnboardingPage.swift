import Foundation

/// Static content for the one-time first-launch walkthrough. Order matters —
/// rendered as swipeable pages in this array's order.
struct OnboardingPage: Identifiable {
    let id: Int
    let symbol: String
    let headline: String
    let body: String
}

extension OnboardingPage {
    static let pages: [OnboardingPage] = [
        OnboardingPage(
            id: 0,
            symbol: "clock",
            headline: "You have 168 hours in a week.",
            body: "That's the whole budget. Everything you do \u{2014} work, rest, everything \u{2014} comes out of this one number."
        ),
        OnboardingPage(
            id: 1,
            symbol: "moon.zzz",
            headline: "About a third of it is already spoken for.",
            body: "Roughly 56 hours go to sleeping and rest, leaving about 112 hours a week that are actually yours to allocate."
        ),
        OnboardingPage(
            id: 2,
            symbol: "chart.pie",
            headline: "So you decide where the rest goes.",
            body: "Break your remaining hours into categories — anything you care about — and give each one a weekly hour budget."
        ),
        OnboardingPage(
            id: 3,
            symbol: "timer",
            headline: "Then hit the timer and go backwards.",
            body: "Start a category and watch it count down from its budget. That's how you find out how much you actually spend — not how much you meant to."
        ),
    ]
}
