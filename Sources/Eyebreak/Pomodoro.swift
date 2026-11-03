import Foundation

/// A Pomodoro you start from the menu: focus blocks, each closed by a break, with a long
/// break after every few. While one runs it is the break timer, so no other break cuts
/// into a block, and its breaks are EyeBreak's own (the routine, water, 5 More Minutes,
/// waiting for a pause, holding for calls).
///
/// Counts what you finished: a block counts when its time runs out, not when Take a Break
/// Now ends it early, and only a counted block moves the round on. Foundation only, so the
/// tests can compile it.
struct Pomodoro: Equatable {
    /// Blocks finished since this Pomodoro started.
    private(set) var completed = 0
    /// Where the blocks are in their round.
    private(set) var round = BreakRound()
    /// Between blocks, waiting for you to start the next (when they don't run on by
    /// themselves). The usual breaks run meanwhile.
    private(set) var isWaiting = false
    /// The break under way, or held back by 5 More Minutes, closes a block that ran its
    /// full length.
    private(set) var breakFollowsFinishedBlock = false

    /// Whether the break that ends the current block is the long one, if the block runs out.
    func nextBreakIsLong(every length: Int) -> Bool {
        round.nextIsLong(every: length)
    }

    /// The block's break begins. `finished` is false when you ended the block early: the
    /// block doesn't count and its break is a short one. Returns whether the break is long.
    @discardableResult
    mutating func blockEnded(finished: Bool, every length: Int) -> Bool {
        // The same break coming back after 5 More Minutes: already counted
        if breakFollowsFinishedBlock { return round.nextIsLong(every: length) }
        guard finished else { return false }
        breakFollowsFinishedBlock = true
        completed += 1
        return round.nextIsLong(every: length)
    }

    /// The break is over, taken or skipped. With `continues`, the next block starts now;
    /// otherwise it waits for you.
    mutating func breakEnded(wasLong: Bool, continues: Bool) {
        if breakFollowsFinishedBlock { round.breakEnded(wasLong: wasLong) }
        breakFollowsFinishedBlock = false
        isWaiting = !continues
    }

    mutating func startNextBlock() {
        isWaiting = false
    }

    /// Dots to fill: blocks done in this round, counting the one a break is running for.
    func filled(every length: Int, isOnBreak: Bool) -> Int {
        round.filled(every: length, isOnBreak: isOnBreak && breakFollowsFinishedBlock)
    }
}
