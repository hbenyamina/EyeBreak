import Foundation

/// Where the break timer is in a Pomodoro-style round: work intervals each end in a
/// break, and the break after every `length`th one is a long one.
///
/// Counts work intervals finished, so a skipped break still moves the round on — the
/// work before it was done. Foundation only, so the tests can compile it.
struct BreakRound: Equatable {
    /// Work intervals finished since the last long break.
    private(set) var position = 0

    /// Whether the break that ends the current work interval is the long one. A round
    /// shortened in Settings mid-way counts as complete rather than running on.
    func nextIsLong(every length: Int) -> Bool {
        length > 0 && position >= length - 1
    }

    /// Dots to fill: work intervals done in this round, counting the one a break is
    /// running for.
    func filled(every length: Int, isOnBreak: Bool) -> Int {
        guard length > 0 else { return 0 }
        return min(position + (isOnBreak ? 1 : 0), length)
    }

    /// A break ended, taken or skipped. A long one closes the round.
    mutating func breakEnded(wasLong: Bool) {
        position = wasLong ? 0 : position + 1
    }

    /// A fresh round: after sleep, or coming back from being away — you already rested.
    mutating func reset() {
        position = 0
    }
}
