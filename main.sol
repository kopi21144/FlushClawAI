// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @title FlushClawAI — hydraulic ticket cascade for claw-routed mixer lanes.
/// @dev codename: teal siphon / gasket line nine

library FcaGauge {
    error FCA_GaugeOverflow();
    uint256 internal constant BPS = 10_000;
    function clampU24(uint256 v, uint24 lo, uint24 hi) internal pure returns (uint24) {
        if (v < lo) return lo;
        if (v > hi) return hi;
        return uint24(v);
    }
    function takeBps(uint256 gross, uint256 bps) internal pure returns (uint256) {
        unchecked { return (gross * bps) / BPS; }
    }
    function safeAdd(uint256 a, uint256 b, uint256 cap) internal pure returns (uint256) {
        unchecked {
            uint256 s = a + b;
            if (s < a || s > cap) revert FCA_GaugeOverflow();
            return s;
        }
    }
}

contract FlushClawAI {
    error FCA_NotPitMaster();
    error FCA_NotFlusher();
    error FCA_Halted();
    error FCA_ZeroAddr();
    error FCA_ZeroWei();
    error FCA_Reentered();
    error FCA_LaneDead();
    error FCA_LaneDrained();
    error FCA_TicketTaken();
    error FCA_TicketGone();
    error FCA_TierOff();
    error FCA_CapHit();
    error FCA_CycleOff();
    error FCA_CascadeLive();
    error FCA_CascadeGone();
    error FCA_CascadeDone();
    error FCA_FlusherOld();
    error FCA_RatingLow();
    error FCA_RatingHigh();
    error FCA_SelfRoute();
    error FCA_HashEmpty();
    error FCA_VoteSpent();
    error FCA_VoteSelf();
    error FCA_BondThin();
    error FCA_SendFail();
    error FCA_ArrayWide();
    error FCA_SizeMismatch();
    error FCA_NotRunner();
    error FCA_RunnerKnown();
    error FCA_FallbackBlocked();
    error FCA_PitLocked();
    error FCA_Fault_31();
    error FCA_Fault_32();
    error FCA_Fault_33();
    error FCA_Fault_34();
    error FCA_Fault_35();
    error FCA_Fault_36();

    event Posted(bytes32 indexed ticketId, uint256 indexed laneId, address indexed runner, uint8 tier, uint256 weiLocked);
    event Voted(bytes32 indexed ticketId, address indexed voter, bool up, uint256 cycleId);
    event Locked(bytes32 indexed ticketId, address indexed from, uint256 weiAmt, uint256 cycleId);
    event Queued(bytes32 indexed cascadeId, uint256 indexed laneId, bytes32 flushTag, uint256 queuedAt);
    event Flushed(bytes32 indexed cascadeId, bytes32 outcomeHash, uint16 flushRating, uint256 cycleId);
    event Burst(bytes32 indexed burstId, uint256 indexed laneId, uint16 pressureBand, uint256 at);
    event Opened(uint256 indexed laneId, bytes32 laneSalt, uint8 tier, uint256 seedWeight);
    event Turned(uint256 indexed cycleId, uint64 wallAt, uint256 ticketMass, uint256 cascadeMass);
    event Halted(bool halted, address indexed by, uint256 atBlock);
    event FlusherSet(address indexed flusher, uint256 atBlock);
    event NativeReceived(address indexed from, uint256 weiAmt, uint256 atBlock);
    event RunnerJoined(address indexed runner, bytes32 tag, uint256 bondWei);
    event RunnerLeft(address indexed runner, uint256 atBlock);
    event Ripple_0(uint256 indexed slot, address indexed actor, uint256 meta, uint256 cycleId);
    event Ripple_1(uint256 indexed slot, address indexed actor, uint256 meta, uint256 cycleId);
    event Ripple_2(uint256 indexed slot, address indexed actor, uint256 meta, uint256 cycleId);
    event Ripple_3(uint256 indexed slot, address indexed actor, uint256 meta, uint256 cycleId);
    event Ripple_4(uint256 indexed slot, address indexed actor, uint256 meta, uint256 cycleId);
    event Ripple_5(uint256 indexed slot, address indexed actor, uint256 meta, uint256 cycleId);
    event Ripple_6(uint256 indexed slot, address indexed actor, uint256 meta, uint256 cycleId);
    event Ripple_7(uint256 indexed slot, address indexed actor, uint256 meta, uint256 cycleId);
    event Ripple_8(uint256 indexed slot, address indexed actor, uint256 meta, uint256 cycleId);
    event Ripple_9(uint256 indexed slot, address indexed actor, uint256 meta, uint256 cycleId);
    event Ripple_10(uint256 indexed slot, address indexed actor, uint256 meta, uint256 cycleId);
    event Ripple_11(uint256 indexed slot, address indexed actor, uint256 meta, uint256 cycleId);
    event Ripple_12(uint256 indexed slot, address indexed actor, uint256 meta, uint256 cycleId);
    event Ripple_13(uint256 indexed slot, address indexed actor, uint256 meta, uint256 cycleId);

    enum FcaLaneStatus { Empty, Running, Drained }
    enum FcaCascadeStage { Waiting, Active, Finalized, Scraped }

    struct FcaLane {
        FcaLaneStatus status;
        uint8 flushTier;
        uint64 startedAt;
        uint32 ticketCount;
        uint32 cascadeCount;
        uint256 massSum;
        bytes32 laneSalt;
    }

    struct FcaTicket {
        uint256 laneId;
        address runner;
        bytes32 clawSeal;
        uint8 flushTier;
        uint32 upVotes;
        uint32 downVotes;
        uint256 lockedWei;
        uint64 postedAt;
        bool open;
    }

    struct FcaCascade {
        uint256 laneId;
        address proposer;
        bytes32 flushTag;
        FcaCascadeStage stage;
        bytes32 outcomeHash;
        uint16 flushRating;
        uint64 queuedAt;
