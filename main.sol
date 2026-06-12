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
    }

    struct FcaBurst {
        uint256 laneId;
        bytes32 burstTag;
        bytes32 ductHash;
        uint16 pressureBand;
        uint64 stampedAt;
    }

    struct FcaCycleRing {
        uint64 openedAt;
        uint256 ticketMass;
        uint256 cascadeMass;
        bytes32 ringDigest;
    }

    struct FcaRunnerBench {
        bool active;
        bytes32 tag;
        uint64 joinedAt;
        uint32 ticketCount;
    }

    uint256 public constant FCA_TIER_CAP = 8;
    uint256 public constant FCA_TICKET_FEE = 0.005 ether;
    uint256 public constant FCA_FLUSHER_BOND = 0.04 ether;
    uint256 public constant FCA_MAX_TICKETS = 178;
    uint256 public constant FCA_OPEN_CASCADE_CAP = 71;
    uint256 public constant FCA_FLUSH_FLOOR = 415;
    uint256 public constant FCA_FLUSH_CEIL = 8375;
    uint256 public constant FCA_CYCLE_BLOCKS = 520;
    uint256 public constant FCA_MASS_CAP = 16587;
    uint256 public constant FCA_RATING_FLOOR = 328;
    uint256 public constant FCA_RATING_CEIL = 7751;
    uint256 public constant FCA_LANE_COUNT = 21;

    bytes32 private constant _SALT_0 = 0x2558b2be49ec3bad79dfef16e6385c1b3c80e134e25fee605c95125304f58523;
    bytes32 private constant _SALT_1 = 0x35b02cfede838780a8ebe475affefd4fc6eb33aa30809807a8615763937f48ea;
    bytes32 private constant _SALT_2 = 0x65d7818e940bcd3b3ebfe42d7231e66e00da16f1a35f9ce6e54095277ba4fc89;
    bytes32 private constant _SALT_3 = 0x91fdada9f13b5906ca2ab1a6ef05d0917686ff4b99da4d1dcca2e68b91f57967;
    bytes32 private constant _SALT_4 = 0x49060685b6cc4782c7b290f1f5e57b063af1e70a9c81c7d47b30431315a590eb;
    bytes32 private constant _SALT_5 = 0xbf92eb3073a18681650be4ef5a1f1c7c018a2e34c77c14c19740663f96edfbc8;
    bytes32 private constant _SALT_6 = 0x44d45f84c1b69a4d8913f7315733f7abe576d7fcc07fbef60171841e3570afdc;
    bytes32 private constant _SALT_7 = 0x97b36661868ba2a098505260463d95497d4f7af485e7fa219cf02b72bb20d1c1;
    bytes32 private constant FCA_DOMAIN = keccak256("FlushClawAI.hydraulicLane");

    address public immutable pitMaster;
    address public immutable ADDRESS_A;
    address public immutable ADDRESS_B;
    address public immutable ADDRESS_C;

    address public flusher;
    bool public halted;
    uint256 public activeCycle;
    uint256 public rippleSerial;
    uint256 public openCascades;
    uint256 public escrowWei;
    uint256 public bornBlock;
    uint256 public laneSerial;

    mapping(uint256 => FcaLane) public lanes;
    mapping(bytes32 => FcaTicket) public tickets;
    mapping(bytes32 => FcaCascade) public cascades;
    mapping(bytes32 => FcaBurst) public bursts;
    mapping(uint256 => FcaCycleRing) public cycleRings;
    mapping(uint256 => mapping(address => uint256)) public runnerMass;
    mapping(bytes32 => mapping(address => bool)) public voteCast;
    mapping(bytes32 => bool) public ticketIdUsed;
    mapping(bytes32 => bool) public cascadeIdUsed;
    mapping(bytes32 => bool) public burstIdUsed;
    mapping(address => FcaRunnerBench) public runnerBenches;
    mapping(address => bytes32[]) private _ticketsByRunner;
    bytes32[] private _ticketRoll;
    uint256 private _guard;

    modifier nonReentrant() {
        if (_guard == 2) revert FCA_Reentered();
        _guard = 2;
        _;
        _guard = 1;
    }

    modifier onlyPitMaster() {
        if (msg.sender != pitMaster) revert FCA_NotPitMaster();
        _;
    }

    modifier onlyFlusher() {
        if (msg.sender != flusher) revert FCA_NotFlusher();
        _;
    }

    modifier whenRunning() {
        if (halted) revert FCA_Halted();
        _;
    }

    modifier onlyActiveRunner() {
        if (!runnerBenches[msg.sender].active) revert FCA_NotRunner();
        _;
    }

    constructor() {
        pitMaster = msg.sender;
        ADDRESS_A = 0x2B75f7f6f428b2F55a213d782f1935CbC8D06140;
        ADDRESS_B = 0x08497A578575B3381b9a62222ECe51827728c938;
        ADDRESS_C = 0x8A7366B486B8617581D8ec1458e8718510124Aef;
        flusher = ADDRESS_A;
        _guard = 1;
        bornBlock = block.number;
        activeCycle = 1;
        laneSerial = FCA_LANE_COUNT;
        _beginCycle(1);
        _bootLanes();
    }

    receive() external payable {
        emit NativeReceived(msg.sender, msg.value, block.number);
        emit Ripple_0(rippleSerial, msg.sender, msg.value, activeCycle);
        unchecked { rippleSerial += 1; }
    }

    fallback() external payable {
        revert FCA_FallbackBlocked();
    }
