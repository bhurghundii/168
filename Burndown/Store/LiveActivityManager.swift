import ActivityKit
import Foundation

/// Everything `TimeStore` needs to drive the lock-screen Live Activity,
/// abstracted behind a protocol the same way `now`/`calendar` are injected —
/// so `BurndownTests` can substitute a no-op/recording fake and stay
/// hermetic, never triggering real ActivityKit side effects.
@MainActor
protocol LiveActivityManaging {
    func start(categoryId: UUID, categoryName: String, startedAt: Date, budgetDeadline: Date?)
    func end(categoryId: UUID)
    func updateBudgetDeadline(categoryId: UUID, budgetDeadline: Date?)

    /// The categoryIds of every Live Activity the system currently thinks is
    /// active, regardless of what `TimeStore`'s own state says. Used only by
    /// `TimeStore.reconcileLiveActivities()` to detect drift.
    func activeCategoryIds() -> Set<UUID>
}

/// Thin wrapper over `Activity<BurndownActivityAttributes>`. Deliberately
/// stateless — every method reads/writes through the OS-owned
/// `Activity<...>.activities` list rather than a local cache, so it stays
/// correct across app relaunch with no extra bookkeeping.
///
/// A Live Activity failing to start/update/end must never block the actual
/// timer mutation it's attached to, so every ActivityKit call here is
/// best-effort: errors are swallowed, never thrown.
@MainActor
final class LiveActivityManager: LiveActivityManaging {
    func start(categoryId: UUID, categoryName: String, startedAt: Date, budgetDeadline: Date?) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        // Defensive: clear any stale activity already tracking this category
        // (e.g. left over from a crash) before requesting a fresh one.
        end(categoryId: categoryId)

        let attributes = BurndownActivityAttributes(categoryId: categoryId, categoryName: categoryName)
        let state = BurndownActivityAttributes.ContentState(startedAt: startedAt, budgetDeadline: budgetDeadline)
        do {
            _ = try Activity.request(attributes: attributes, content: .init(state: state, staleDate: nil))
        } catch {
            // Best-effort: the running Session is the source of truth regardless.
        }
    }

    func end(categoryId: UUID) {
        for activity in Activity<BurndownActivityAttributes>.activities where activity.attributes.categoryId == categoryId {
            Task { await activity.end(activity.content, dismissalPolicy: .immediate) }
        }
    }

    func updateBudgetDeadline(categoryId: UUID, budgetDeadline: Date?) {
        for activity in Activity<BurndownActivityAttributes>.activities where activity.attributes.categoryId == categoryId {
            let newState = BurndownActivityAttributes.ContentState(
                startedAt: activity.content.state.startedAt,
                budgetDeadline: budgetDeadline
            )
            Task { await activity.update(.init(state: newState, staleDate: nil)) }
        }
    }

    func activeCategoryIds() -> Set<UUID> {
        Set(Activity<BurndownActivityAttributes>.activities.map(\.attributes.categoryId))
    }
}
