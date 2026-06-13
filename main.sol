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

    function setFlusher(address next_) external onlyPitMaster {
        if (next_ == address(0)) revert FCA_ZeroAddr();
        flusher = next_;
        emit FlusherSet(next_, block.number);
    }

    function setHalted(bool on) external onlyPitMaster {
        halted = on;
        emit Halted(on, msg.sender, block.number);
    }

    function turnCycle() external onlyPitMaster whenRunning {
        uint256 n = activeCycle + 1;
        if (n > 43) revert FCA_CycleOff();
        activeCycle = n;
        _beginCycle(n);
        emit Turned(n, uint64(block.timestamp), _cycleTicketMass(), openCascades);
    }

    function drainLane(uint256 laneId) external onlyFlusher {
        FcaLane storage ln = lanes[laneId];
        if (ln.status == FcaLaneStatus.Empty) revert FCA_LaneDead();
        ln.status = FcaLaneStatus.Drained;
    }

    function enrollRunner(address runner, bytes32 tag) external onlyPitMaster {
        if (runner == address(0)) revert FCA_ZeroAddr();
        if (runnerBenches[runner].active) revert FCA_RunnerKnown();
        runnerBenches[runner] = FcaRunnerBench({
            active: true,
            tag: tag,
            joinedAt: uint64(block.timestamp),
            ticketCount: 0
        });
        emit RunnerJoined(runner, tag, 0);
    }

    function dropRunner(address runner) external onlyPitMaster {
        if (!runnerBenches[runner].active) revert FCA_NotRunner();
        runnerBenches[runner].active = false;
        emit RunnerLeft(runner, block.number);
    }

    function skimExcess(uint256 amt, address payable to) external onlyPitMaster nonReentrant {
        if (to == address(0)) revert FCA_ZeroAddr();
        if (amt == 0 || amt > address(this).balance) revert FCA_ZeroWei();
        if (amt > address(this).balance - escrowWei) revert FCA_CapHit();
        _pushNative(to, amt);
    }

    function postTicket(
        bytes32 ticketId,
        uint256 laneId,
        bytes32 clawSeal,
        uint8 flushTier
    ) external payable nonReentrant whenRunning onlyActiveRunner {
        if (ticketId == bytes32(0)) revert FCA_HashEmpty();
        if (ticketIdUsed[ticketId]) revert FCA_TicketTaken();
        if (msg.value < FCA_TICKET_FEE) revert FCA_BondThin();
        if (flushTier == 0 || flushTier > FCA_TIER_CAP) revert FCA_TierOff();
        FcaLane storage ln = lanes[laneId];
        if (ln.status != FcaLaneStatus.Running) revert FCA_LaneDrained();
        if (ln.ticketCount >= FCA_MAX_TICKETS) revert FCA_CapHit();
        ticketIdUsed[ticketId] = true;
        tickets[ticketId] = FcaTicket({
            laneId: laneId,
            runner: msg.sender,
            clawSeal: clawSeal,
            flushTier: flushTier,
            upVotes: 0,
            downVotes: 0,
            lockedWei: msg.value,
            postedAt: uint64(block.timestamp),
            open: true
        });
        unchecked {
            ln.ticketCount += 1;
            ln.massSum = FcaGauge.safeAdd(
                ln.massSum, uint256(flushTier) * 89, FCA_MASS_CAP
            );
            runnerBenches[msg.sender].ticketCount += 1;
        }
        runnerMass[activeCycle][msg.sender] += uint256(flushTier) * 17;
        escrowWei += msg.value;
        _ticketsByRunner[msg.sender].push(ticketId);
        _ticketRoll.push(ticketId);
        emit Posted(ticketId, laneId, msg.sender, flushTier, msg.value);
    }

    function voteTicket(bytes32 ticketId, bool up) external whenRunning {
        FcaTicket storage t = tickets[ticketId];
        if (!t.open) revert FCA_TicketGone();
        if (t.runner == msg.sender) revert FCA_VoteSelf();
        if (voteCast[ticketId][msg.sender]) revert FCA_VoteSpent();
        voteCast[ticketId][msg.sender] = true;
        if (up) unchecked { t.upVotes += 1; }
        else unchecked { t.downVotes += 1; }
        emit Voted(ticketId, msg.sender, up, activeCycle);
    }

    function lockTicket(bytes32 ticketId) external payable nonReentrant whenRunning {
        if (msg.value == 0) revert FCA_ZeroWei();
        FcaTicket storage t = tickets[ticketId];
        if (!t.open) revert FCA_TicketGone();
        t.lockedWei += msg.value;
        escrowWei += msg.value;
        emit Locked(ticketId, msg.sender, msg.value, activeCycle);
    }

    function joinRunner(bytes32 tag) external payable nonReentrant whenRunning {
        if (msg.value < FCA_FLUSHER_BOND) revert FCA_BondThin();
        if (runnerBenches[msg.sender].active) revert FCA_RunnerKnown();
        runnerBenches[msg.sender] = FcaRunnerBench({
            active: true,
            tag: tag,
            joinedAt: uint64(block.timestamp),
            ticketCount: 0
        });
        escrowWei += msg.value;
        emit RunnerJoined(msg.sender, tag, msg.value);
    }

    function queueCascade(bytes32 cascadeId, uint256 laneId, bytes32 flushTag)
        external
        payable
        nonReentrant
        whenRunning
        onlyActiveRunner
    {
        if (cascadeId == bytes32(0)) revert FCA_HashEmpty();
        if (cascadeIdUsed[cascadeId]) revert FCA_CascadeLive();
        if (msg.value < FCA_TICKET_FEE) revert FCA_BondThin();
        if (openCascades >= FCA_OPEN_CASCADE_CAP) revert FCA_CapHit();
        FcaLane storage ln = lanes[laneId];
        if (ln.status != FcaLaneStatus.Running) revert FCA_LaneDrained();
        cascadeIdUsed[cascadeId] = true;
        cascades[cascadeId] = FcaCascade({
            laneId: laneId,
            proposer: msg.sender,
            flushTag: flushTag,
            stage: FcaCascadeStage.Waiting,
            outcomeHash: bytes32(0),
            flushRating: 0,
            queuedAt: uint64(block.timestamp)
        });
        unchecked {
            openCascades += 1;
            ln.cascadeCount += 1;
        }
        escrowWei += msg.value;
        emit Queued(cascadeId, laneId, flushTag, block.timestamp);
    }

    function flushCascade(bytes32 cascadeId, bytes32 outcomeHash, uint16 flushRating) external onlyFlusher {
        FcaCascade storage c = cascades[cascadeId];
        if (c.stage != FcaCascadeStage.Waiting && c.stage != FcaCascadeStage.Active) revert FCA_CascadeDone();
        if (flushRating < FCA_RATING_FLOOR) revert FCA_RatingLow();
        if (flushRating > FCA_RATING_CEIL) revert FCA_RatingHigh();
        c.stage = FcaCascadeStage.Finalized;
        c.outcomeHash = outcomeHash;
        c.flushRating = flushRating;
        if (openCascades > 0) unchecked { openCascades -= 1; }
        emit Flushed(cascadeId, outcomeHash, flushRating, activeCycle);
    }

    function emitBurst(
        bytes32 burstId,
        uint256 laneId,
        bytes32 burstTag,
        bytes32 ductHash,
        uint16 pressureBand
    ) external onlyFlusher whenRunning {
        if (burstIdUsed[burstId]) revert FCA_FlusherOld();
        if (pressureBand < FCA_FLUSH_FLOOR) revert FCA_RatingLow();
        if (pressureBand > FCA_FLUSH_CEIL) revert FCA_RatingHigh();
        FcaLane storage ln = lanes[laneId];
        if (ln.status != FcaLaneStatus.Running) revert FCA_LaneDrained();
        burstIdUsed[burstId] = true;
        bursts[burstId] = FcaBurst({
            laneId: laneId,
            burstTag: burstTag,
            ductHash: ductHash,
            pressureBand: pressureBand,
            stampedAt: uint64(block.timestamp)
        });
        emit Burst(burstId, laneId, pressureBand, block.timestamp);
    }

    function fundLane() external payable whenRunning {
        if (msg.value == 0) revert FCA_ZeroWei();
        emit NativeReceived(msg.sender, msg.value, block.number);
        emit Ripple_1(rippleSerial, msg.sender, msg.value, activeCycle);
        unchecked { rippleSerial += 1; }
    }

    function redeemTicket(bytes32 ticketId, address payable to) external nonReentrant whenRunning {
        FcaTicket storage t = tickets[ticketId];
        if (!t.open) revert FCA_TicketGone();
        if (t.runner != msg.sender) revert FCA_SelfRoute();
        if (to == address(0)) revert FCA_ZeroAddr();
        uint256 amt = t.lockedWei;
        if (amt == 0) revert FCA_ZeroWei();
        t.open = false;
        t.lockedWei = 0;
        escrowWei -= amt;
        _pushNative(to, amt);
    }

    function _pushNative(address to, uint256 amt) internal {
        (bool ok, ) = payable(to).call{value: amt}("");
        if (!ok) revert FCA_SendFail();
    }

    function _beginCycle(uint256 cycleId) internal {
        FcaCycleRing storage ring = cycleRings[cycleId];
        ring.openedAt = uint64(block.timestamp);
        ring.ticketMass = _cycleTicketMass();
        ring.cascadeMass = openCascades;
        ring.ringDigest = _ringDigest(cycleId, ring.ticketMass, ring.cascadeMass);
    }

    function _ringDigest(uint256 cycleId, uint256 tm, uint256 cm) internal view returns (bytes32) {
        return keccak256(abi.encode(
            FCA_DOMAIN,
            cycleId,
            tm,
            cm,
            ADDRESS_A,
            ADDRESS_B,
            ADDRESS_C,
            _SALT_0,
            FCA_CYCLE_BLOCKS,
            bornBlock
        ));
    }

    function ticketDigest(bytes32 ticketId) public view returns (bytes32) {
        FcaTicket storage t = tickets[ticketId];
        return keccak256(abi.encode(
            ticketId,
            t.laneId,
            t.runner,
            t.lockedWei,
            t.clawSeal,
            _SALT_1,
            activeCycle
        ));
    }

    function _cycleTicketMass() internal view returns (uint256 mass) {
        for (uint256 i = 1; i <= FCA_LANE_COUNT; ++i) {
            mass += lanes[i].massSum;
        }
    }

    function _bootLanes() internal {
        lanes[1] = FcaLane({
            status: FcaLaneStatus.Running,
            flushTier: uint8(4),
            startedAt: uint64(block.timestamp),
            ticketCount: 0,
            cascadeCount: 0,
            massSum: 64,
            laneSalt: 0x35b02cfede838780a8ebe475affefd4fc6eb33aa30809807a8615763937f48ea
        });
        emit Opened(1, 0x35b02cfede838780a8ebe475affefd4fc6eb33aa30809807a8615763937f48ea, uint8(4), 64);
        lanes[2] = FcaLane({
            status: FcaLaneStatus.Running,
            flushTier: uint8(6),
            startedAt: uint64(block.timestamp),
            ticketCount: 0,
            cascadeCount: 0,
            massSum: 105,
            laneSalt: 0x65d7818e940bcd3b3ebfe42d7231e66e00da16f1a35f9ce6e54095277ba4fc89
        });
        emit Opened(2, 0x65d7818e940bcd3b3ebfe42d7231e66e00da16f1a35f9ce6e54095277ba4fc89, uint8(6), 105);
        lanes[3] = FcaLane({
            status: FcaLaneStatus.Running,
            flushTier: uint8(5),
            startedAt: uint64(block.timestamp),
            ticketCount: 0,
            cascadeCount: 0,
            massSum: 146,
            laneSalt: 0x91fdada9f13b5906ca2ab1a6ef05d0917686ff4b99da4d1dcca2e68b91f57967
        });
        emit Opened(3, 0x91fdada9f13b5906ca2ab1a6ef05d0917686ff4b99da4d1dcca2e68b91f57967, uint8(5), 146);
        lanes[4] = FcaLane({
            status: FcaLaneStatus.Running,
            flushTier: uint8(7),
            startedAt: uint64(block.timestamp),
            ticketCount: 0,
            cascadeCount: 0,
            massSum: 187,
            laneSalt: 0x49060685b6cc4782c7b290f1f5e57b063af1e70a9c81c7d47b30431315a590eb
        });
        emit Opened(4, 0x49060685b6cc4782c7b290f1f5e57b063af1e70a9c81c7d47b30431315a590eb, uint8(7), 187);
        lanes[5] = FcaLane({
            status: FcaLaneStatus.Running,
            flushTier: uint8(3),
            startedAt: uint64(block.timestamp),
            ticketCount: 0,
            cascadeCount: 0,
            massSum: 228,
            laneSalt: 0xbf92eb3073a18681650be4ef5a1f1c7c018a2e34c77c14c19740663f96edfbc8
        });
        emit Opened(5, 0xbf92eb3073a18681650be4ef5a1f1c7c018a2e34c77c14c19740663f96edfbc8, uint8(3), 228);
        lanes[6] = FcaLane({
            status: FcaLaneStatus.Running,
            flushTier: uint8(8),
            startedAt: uint64(block.timestamp),
            ticketCount: 0,
            cascadeCount: 0,
            massSum: 269,
            laneSalt: 0x44d45f84c1b69a4d8913f7315733f7abe576d7fcc07fbef60171841e3570afdc
        });
        emit Opened(6, 0x44d45f84c1b69a4d8913f7315733f7abe576d7fcc07fbef60171841e3570afdc, uint8(8), 269);
        lanes[7] = FcaLane({
            status: FcaLaneStatus.Running,
            flushTier: uint8(5),
            startedAt: uint64(block.timestamp),
            ticketCount: 0,
            cascadeCount: 0,
            massSum: 310,
            laneSalt: 0x97b36661868ba2a098505260463d95497d4f7af485e7fa219cf02b72bb20d1c1
        });
        emit Opened(7, 0x97b36661868ba2a098505260463d95497d4f7af485e7fa219cf02b72bb20d1c1, uint8(5), 310);
        lanes[8] = FcaLane({
            status: FcaLaneStatus.Running,
            flushTier: uint8(6),
            startedAt: uint64(block.timestamp),
            ticketCount: 0,
            cascadeCount: 0,
            massSum: 351,
            laneSalt: 0x2558b2be49ec3bad79dfef16e6385c1b3c80e134e25fee605c95125304f58523
        });
        emit Opened(8, 0x2558b2be49ec3bad79dfef16e6385c1b3c80e134e25fee605c95125304f58523, uint8(6), 351);
        lanes[9] = FcaLane({
            status: FcaLaneStatus.Running,
            flushTier: uint8(4),
            startedAt: uint64(block.timestamp),
            ticketCount: 0,
            cascadeCount: 0,
            massSum: 392,
            laneSalt: 0x35b02cfede838780a8ebe475affefd4fc6eb33aa30809807a8615763937f48ea
        });
        emit Opened(9, 0x35b02cfede838780a8ebe475affefd4fc6eb33aa30809807a8615763937f48ea, uint8(4), 392);
        lanes[10] = FcaLane({
            status: FcaLaneStatus.Running,
            flushTier: uint8(6),
            startedAt: uint64(block.timestamp),
            ticketCount: 0,
            cascadeCount: 0,
            massSum: 433,
            laneSalt: 0x65d7818e940bcd3b3ebfe42d7231e66e00da16f1a35f9ce6e54095277ba4fc89
        });
        emit Opened(10, 0x65d7818e940bcd3b3ebfe42d7231e66e00da16f1a35f9ce6e54095277ba4fc89, uint8(6), 433);
        lanes[11] = FcaLane({
            status: FcaLaneStatus.Running,
            flushTier: uint8(5),
            startedAt: uint64(block.timestamp),
            ticketCount: 0,
            cascadeCount: 0,
            massSum: 474,
            laneSalt: 0x91fdada9f13b5906ca2ab1a6ef05d0917686ff4b99da4d1dcca2e68b91f57967
        });
        emit Opened(11, 0x91fdada9f13b5906ca2ab1a6ef05d0917686ff4b99da4d1dcca2e68b91f57967, uint8(5), 474);
        lanes[12] = FcaLane({
            status: FcaLaneStatus.Running,
            flushTier: uint8(7),
            startedAt: uint64(block.timestamp),
            ticketCount: 0,
            cascadeCount: 0,
            massSum: 515,
            laneSalt: 0x49060685b6cc4782c7b290f1f5e57b063af1e70a9c81c7d47b30431315a590eb
        });
        emit Opened(12, 0x49060685b6cc4782c7b290f1f5e57b063af1e70a9c81c7d47b30431315a590eb, uint8(7), 515);
        lanes[13] = FcaLane({
            status: FcaLaneStatus.Running,
            flushTier: uint8(3),
            startedAt: uint64(block.timestamp),
            ticketCount: 0,
            cascadeCount: 0,
            massSum: 556,
            laneSalt: 0xbf92eb3073a18681650be4ef5a1f1c7c018a2e34c77c14c19740663f96edfbc8
        });
        emit Opened(13, 0xbf92eb3073a18681650be4ef5a1f1c7c018a2e34c77c14c19740663f96edfbc8, uint8(3), 556);
        lanes[14] = FcaLane({
            status: FcaLaneStatus.Running,
            flushTier: uint8(8),
            startedAt: uint64(block.timestamp),
            ticketCount: 0,
            cascadeCount: 0,
            massSum: 597,
            laneSalt: 0x44d45f84c1b69a4d8913f7315733f7abe576d7fcc07fbef60171841e3570afdc
        });
        emit Opened(14, 0x44d45f84c1b69a4d8913f7315733f7abe576d7fcc07fbef60171841e3570afdc, uint8(8), 597);
        lanes[15] = FcaLane({
            status: FcaLaneStatus.Running,
            flushTier: uint8(5),
            startedAt: uint64(block.timestamp),
            ticketCount: 0,
            cascadeCount: 0,
            massSum: 638,
            laneSalt: 0x97b36661868ba2a098505260463d95497d4f7af485e7fa219cf02b72bb20d1c1
        });
        emit Opened(15, 0x97b36661868ba2a098505260463d95497d4f7af485e7fa219cf02b72bb20d1c1, uint8(5), 638);
        lanes[16] = FcaLane({
            status: FcaLaneStatus.Running,
            flushTier: uint8(6),
            startedAt: uint64(block.timestamp),
            ticketCount: 0,
            cascadeCount: 0,
            massSum: 679,
            laneSalt: 0x2558b2be49ec3bad79dfef16e6385c1b3c80e134e25fee605c95125304f58523
        });
        emit Opened(16, 0x2558b2be49ec3bad79dfef16e6385c1b3c80e134e25fee605c95125304f58523, uint8(6), 679);
        lanes[17] = FcaLane({
            status: FcaLaneStatus.Running,
            flushTier: uint8(4),
            startedAt: uint64(block.timestamp),
            ticketCount: 0,
            cascadeCount: 0,
            massSum: 720,
            laneSalt: 0x35b02cfede838780a8ebe475affefd4fc6eb33aa30809807a8615763937f48ea
        });
        emit Opened(17, 0x35b02cfede838780a8ebe475affefd4fc6eb33aa30809807a8615763937f48ea, uint8(4), 720);
        lanes[18] = FcaLane({
            status: FcaLaneStatus.Running,
            flushTier: uint8(6),
            startedAt: uint64(block.timestamp),
            ticketCount: 0,
            cascadeCount: 0,
            massSum: 761,
            laneSalt: 0x65d7818e940bcd3b3ebfe42d7231e66e00da16f1a35f9ce6e54095277ba4fc89
        });
        emit Opened(18, 0x65d7818e940bcd3b3ebfe42d7231e66e00da16f1a35f9ce6e54095277ba4fc89, uint8(6), 761);
        lanes[19] = FcaLane({
            status: FcaLaneStatus.Running,
            flushTier: uint8(5),
            startedAt: uint64(block.timestamp),
            ticketCount: 0,
            cascadeCount: 0,
            massSum: 802,
            laneSalt: 0x91fdada9f13b5906ca2ab1a6ef05d0917686ff4b99da4d1dcca2e68b91f57967
        });
        emit Opened(19, 0x91fdada9f13b5906ca2ab1a6ef05d0917686ff4b99da4d1dcca2e68b91f57967, uint8(5), 802);
        lanes[20] = FcaLane({
            status: FcaLaneStatus.Running,
            flushTier: uint8(7),
            startedAt: uint64(block.timestamp),
            ticketCount: 0,
            cascadeCount: 0,
            massSum: 843,
            laneSalt: 0x49060685b6cc4782c7b290f1f5e57b063af1e70a9c81c7d47b30431315a590eb
        });
        emit Opened(20, 0x49060685b6cc4782c7b290f1f5e57b063af1e70a9c81c7d47b30431315a590eb, uint8(7), 843);
        lanes[21] = FcaLane({
            status: FcaLaneStatus.Running,
            flushTier: uint8(3),
            startedAt: uint64(block.timestamp),
            ticketCount: 0,
            cascadeCount: 0,
            massSum: 884,
            laneSalt: 0xbf92eb3073a18681650be4ef5a1f1c7c018a2e34c77c14c19740663f96edfbc8
        });
        emit Opened(21, 0xbf92eb3073a18681650be4ef5a1f1c7c018a2e34c77c14c19740663f96edfbc8, uint8(3), 884);
    }

    // lane readers
    function readTicket_0(bytes32 ticketId) external view returns (
        uint256 laneId,
        address runner,
        uint8 tier,
        uint256 locked,
        bytes32 digest
    ) {
        FcaTicket storage t = tickets[ticketId];
        laneId = t.laneId;
        runner = t.runner;
        tier = t.flushTier;
        locked = t.lockedWei;
        digest = keccak256(abi.encode(ticketId, locked, _SALT_0));
    }

    function readTicket_1(bytes32 ticketId) external view returns (
        uint256 laneId,
        address runner,
        uint8 tier,
        uint256 locked,
        bytes32 digest
    ) {
        FcaTicket storage t = tickets[ticketId];
        laneId = t.laneId;
        runner = t.runner;
        tier = t.flushTier;
        locked = t.lockedWei;
        digest = keccak256(abi.encode(ticketId, locked, _SALT_1));
    }

    function readTicket_2(bytes32 ticketId) external view returns (
        uint256 laneId,
        address runner,
        uint8 tier,
        uint256 locked,
        bytes32 digest
    ) {
        FcaTicket storage t = tickets[ticketId];
        laneId = t.laneId;
        runner = t.runner;
        tier = t.flushTier;
        locked = t.lockedWei;
        digest = keccak256(abi.encode(ticketId, locked, _SALT_2));
    }

    function readTicket_3(bytes32 ticketId) external view returns (
        uint256 laneId,
        address runner,
        uint8 tier,
        uint256 locked,
        bytes32 digest
    ) {
        FcaTicket storage t = tickets[ticketId];
        laneId = t.laneId;
        runner = t.runner;
        tier = t.flushTier;
        locked = t.lockedWei;
        digest = keccak256(abi.encode(ticketId, locked, _SALT_3));
    }

    function readTicket_4(bytes32 ticketId) external view returns (
        uint256 laneId,
        address runner,
        uint8 tier,
        uint256 locked,
        bytes32 digest
    ) {
        FcaTicket storage t = tickets[ticketId];
        laneId = t.laneId;
        runner = t.runner;
        tier = t.flushTier;
        locked = t.lockedWei;
        digest = keccak256(abi.encode(ticketId, locked, _SALT_4));
    }

    function readTicket_5(bytes32 ticketId) external view returns (
        uint256 laneId,
        address runner,
        uint8 tier,
        uint256 locked,
        bytes32 digest
    ) {
        FcaTicket storage t = tickets[ticketId];
        laneId = t.laneId;
        runner = t.runner;
        tier = t.flushTier;
        locked = t.lockedWei;
        digest = keccak256(abi.encode(ticketId, locked, _SALT_5));
    }

    function readTicket_6(bytes32 ticketId) external view returns (
        uint256 laneId,
        address runner,
        uint8 tier,
        uint256 locked,
        bytes32 digest
    ) {
        FcaTicket storage t = tickets[ticketId];
        laneId = t.laneId;
        runner = t.runner;
        tier = t.flushTier;
        locked = t.lockedWei;
        digest = keccak256(abi.encode(ticketId, locked, _SALT_6));
    }

    function readTicket_7(bytes32 ticketId) external view returns (
        uint256 laneId,
        address runner,
        uint8 tier,
        uint256 locked,
        bytes32 digest
    ) {
        FcaTicket storage t = tickets[ticketId];
        laneId = t.laneId;
        runner = t.runner;
        tier = t.flushTier;
        locked = t.lockedWei;
        digest = keccak256(abi.encode(ticketId, locked, _SALT_7));
    }

    function readTicket_8(bytes32 ticketId) external view returns (
        uint256 laneId,
        address runner,
        uint8 tier,
        uint256 locked,
        bytes32 digest
    ) {
        FcaTicket storage t = tickets[ticketId];
        laneId = t.laneId;
        runner = t.runner;
        tier = t.flushTier;
        locked = t.lockedWei;
        digest = keccak256(abi.encode(ticketId, locked, _SALT_0));
    }

    function readTicket_9(bytes32 ticketId) external view returns (
        uint256 laneId,
        address runner,
        uint8 tier,
        uint256 locked,
        bytes32 digest
    ) {
        FcaTicket storage t = tickets[ticketId];
        laneId = t.laneId;
        runner = t.runner;
        tier = t.flushTier;
        locked = t.lockedWei;
        digest = keccak256(abi.encode(ticketId, locked, _SALT_1));
    }

    function readTicket_10(bytes32 ticketId) external view returns (
        uint256 laneId,
        address runner,
        uint8 tier,
        uint256 locked,
        bytes32 digest
    ) {
        FcaTicket storage t = tickets[ticketId];
        laneId = t.laneId;
        runner = t.runner;
        tier = t.flushTier;
        locked = t.lockedWei;
        digest = keccak256(abi.encode(ticketId, locked, _SALT_2));
    }

    function readTicket_11(bytes32 ticketId) external view returns (
        uint256 laneId,
        address runner,
        uint8 tier,
        uint256 locked,
        bytes32 digest
    ) {
        FcaTicket storage t = tickets[ticketId];
        laneId = t.laneId;
        runner = t.runner;
        tier = t.flushTier;
        locked = t.lockedWei;
        digest = keccak256(abi.encode(ticketId, locked, _SALT_3));
    }

    function readTicket_12(bytes32 ticketId) external view returns (
        uint256 laneId,
        address runner,
        uint8 tier,
        uint256 locked,
        bytes32 digest
    ) {
        FcaTicket storage t = tickets[ticketId];
        laneId = t.laneId;
        runner = t.runner;
        tier = t.flushTier;
        locked = t.lockedWei;
        digest = keccak256(abi.encode(ticketId, locked, _SALT_4));
    }

    function readTicket_13(bytes32 ticketId) external view returns (
        uint256 laneId,
        address runner,
        uint8 tier,
        uint256 locked,
        bytes32 digest
    ) {
        FcaTicket storage t = tickets[ticketId];
        laneId = t.laneId;
        runner = t.runner;
        tier = t.flushTier;
        locked = t.lockedWei;
        digest = keccak256(abi.encode(ticketId, locked, _SALT_5));
    }

    function readTicket_14(bytes32 ticketId) external view returns (
        uint256 laneId,
        address runner,
        uint8 tier,
        uint256 locked,
        bytes32 digest
    ) {
        FcaTicket storage t = tickets[ticketId];
        laneId = t.laneId;
        runner = t.runner;
        tier = t.flushTier;
        locked = t.lockedWei;
        digest = keccak256(abi.encode(ticketId, locked, _SALT_6));
    }

    function readTicket_15(bytes32 ticketId) external view returns (
        uint256 laneId,
        address runner,
        uint8 tier,
        uint256 locked,
        bytes32 digest
    ) {
        FcaTicket storage t = tickets[ticketId];
        laneId = t.laneId;
        runner = t.runner;
        tier = t.flushTier;
        locked = t.lockedWei;
        digest = keccak256(abi.encode(ticketId, locked, _SALT_7));
    }

    function readTicket_16(bytes32 ticketId) external view returns (
        uint256 laneId,
        address runner,
        uint8 tier,
        uint256 locked,
        bytes32 digest
    ) {
        FcaTicket storage t = tickets[ticketId];
        laneId = t.laneId;
        runner = t.runner;
        tier = t.flushTier;
        locked = t.lockedWei;
        digest = keccak256(abi.encode(ticketId, locked, _SALT_0));
    }

    function readTicket_17(bytes32 ticketId) external view returns (
        uint256 laneId,
        address runner,
        uint8 tier,
        uint256 locked,
        bytes32 digest
    ) {
        FcaTicket storage t = tickets[ticketId];
        laneId = t.laneId;
        runner = t.runner;
        tier = t.flushTier;
        locked = t.lockedWei;
        digest = keccak256(abi.encode(ticketId, locked, _SALT_1));
    }

    function readTicket_18(bytes32 ticketId) external view returns (
        uint256 laneId,
        address runner,
        uint8 tier,
        uint256 locked,
        bytes32 digest
    ) {
        FcaTicket storage t = tickets[ticketId];
        laneId = t.laneId;
        runner = t.runner;
        tier = t.flushTier;
        locked = t.lockedWei;
        digest = keccak256(abi.encode(ticketId, locked, _SALT_2));
    }

    function readTicket_19(bytes32 ticketId) external view returns (
        uint256 laneId,
        address runner,
        uint8 tier,
        uint256 locked,
        bytes32 digest
    ) {
        FcaTicket storage t = tickets[ticketId];
        laneId = t.laneId;
        runner = t.runner;
        tier = t.flushTier;
        locked = t.lockedWei;
        digest = keccak256(abi.encode(ticketId, locked, _SALT_3));
    }

    function readTicket_20(bytes32 ticketId) external view returns (
        uint256 laneId,
        address runner,
        uint8 tier,
        uint256 locked,
        bytes32 digest
    ) {
        FcaTicket storage t = tickets[ticketId];
        laneId = t.laneId;
        runner = t.runner;
        tier = t.flushTier;
        locked = t.lockedWei;
        digest = keccak256(abi.encode(ticketId, locked, _SALT_4));
    }

    function readTicket_21(bytes32 ticketId) external view returns (
        uint256 laneId,
        address runner,
        uint8 tier,
        uint256 locked,
        bytes32 digest
    ) {
        FcaTicket storage t = tickets[ticketId];
        laneId = t.laneId;
        runner = t.runner;
        tier = t.flushTier;
        locked = t.lockedWei;
        digest = keccak256(abi.encode(ticketId, locked, _SALT_5));
    }

    function readTicket_22(bytes32 ticketId) external view returns (
        uint256 laneId,
        address runner,
        uint8 tier,
        uint256 locked,
        bytes32 digest
    ) {
        FcaTicket storage t = tickets[ticketId];
        laneId = t.laneId;
        runner = t.runner;
        tier = t.flushTier;
        locked = t.lockedWei;
        digest = keccak256(abi.encode(ticketId, locked, _SALT_6));
    }

    function readTicket_23(bytes32 ticketId) external view returns (
        uint256 laneId,
        address runner,
        uint8 tier,
        uint256 locked,
        bytes32 digest
    ) {
        FcaTicket storage t = tickets[ticketId];
        laneId = t.laneId;
        runner = t.runner;
        tier = t.flushTier;
        locked = t.lockedWei;
        digest = keccak256(abi.encode(ticketId, locked, _SALT_7));
    }

    function readTicket_24(bytes32 ticketId) external view returns (
        uint256 laneId,
        address runner,
        uint8 tier,
        uint256 locked,
        bytes32 digest
    ) {
        FcaTicket storage t = tickets[ticketId];
        laneId = t.laneId;
        runner = t.runner;
        tier = t.flushTier;
        locked = t.lockedWei;
        digest = keccak256(abi.encode(ticketId, locked, _SALT_0));
    }

    function readTicket_25(bytes32 ticketId) external view returns (
        uint256 laneId,
        address runner,
        uint8 tier,
        uint256 locked,
        bytes32 digest
    ) {
        FcaTicket storage t = tickets[ticketId];
        laneId = t.laneId;
        runner = t.runner;
        tier = t.flushTier;
        locked = t.lockedWei;
        digest = keccak256(abi.encode(ticketId, locked, _SALT_1));
    }

    function readTicket_26(bytes32 ticketId) external view returns (
        uint256 laneId,
        address runner,
        uint8 tier,
        uint256 locked,
        bytes32 digest
    ) {
        FcaTicket storage t = tickets[ticketId];
        laneId = t.laneId;
        runner = t.runner;
        tier = t.flushTier;
        locked = t.lockedWei;
        digest = keccak256(abi.encode(ticketId, locked, _SALT_2));
    }

    function readTicket_27(bytes32 ticketId) external view returns (
        uint256 laneId,
        address runner,
        uint8 tier,
        uint256 locked,
        bytes32 digest
    ) {
        FcaTicket storage t = tickets[ticketId];
        laneId = t.laneId;
        runner = t.runner;
        tier = t.flushTier;
        locked = t.lockedWei;
        digest = keccak256(abi.encode(ticketId, locked, _SALT_3));
    }

    function readTicket_28(bytes32 ticketId) external view returns (
        uint256 laneId,
        address runner,
        uint8 tier,
        uint256 locked,
        bytes32 digest
    ) {
        FcaTicket storage t = tickets[ticketId];
        laneId = t.laneId;
        runner = t.runner;
        tier = t.flushTier;
        locked = t.lockedWei;
        digest = keccak256(abi.encode(ticketId, locked, _SALT_4));
    }

    function readTicket_29(bytes32 ticketId) external view returns (
        uint256 laneId,
        address runner,
        uint8 tier,
        uint256 locked,
        bytes32 digest
    ) {
        FcaTicket storage t = tickets[ticketId];
        laneId = t.laneId;
        runner = t.runner;
        tier = t.flushTier;
        locked = t.lockedWei;
        digest = keccak256(abi.encode(ticketId, locked, _SALT_5));
    }

    function readTicket_30(bytes32 ticketId) external view returns (
        uint256 laneId,
        address runner,
        uint8 tier,
        uint256 locked,
        bytes32 digest
    ) {
        FcaTicket storage t = tickets[ticketId];
        laneId = t.laneId;
        runner = t.runner;
        tier = t.flushTier;
        locked = t.lockedWei;
        digest = keccak256(abi.encode(ticketId, locked, _SALT_6));
    }

    function readTicket_31(bytes32 ticketId) external view returns (
        uint256 laneId,
        address runner,
        uint8 tier,
        uint256 locked,
        bytes32 digest
    ) {
        FcaTicket storage t = tickets[ticketId];
        laneId = t.laneId;
        runner = t.runner;
        tier = t.flushTier;
        locked = t.lockedWei;
        digest = keccak256(abi.encode(ticketId, locked, _SALT_7));
    }

    function readTicket_32(bytes32 ticketId) external view returns (
        uint256 laneId,
        address runner,
        uint8 tier,
        uint256 locked,
        bytes32 digest
    ) {
        FcaTicket storage t = tickets[ticketId];
        laneId = t.laneId;
        runner = t.runner;
        tier = t.flushTier;
        locked = t.lockedWei;
        digest = keccak256(abi.encode(ticketId, locked, _SALT_0));
    }

    function readTicket_33(bytes32 ticketId) external view returns (
        uint256 laneId,
        address runner,
        uint8 tier,
        uint256 locked,
        bytes32 digest
    ) {
        FcaTicket storage t = tickets[ticketId];
        laneId = t.laneId;
        runner = t.runner;
        tier = t.flushTier;
        locked = t.lockedWei;
        digest = keccak256(abi.encode(ticketId, locked, _SALT_1));
    }

    function readTicket_34(bytes32 ticketId) external view returns (
        uint256 laneId,
        address runner,
        uint8 tier,
        uint256 locked,
        bytes32 digest
    ) {
        FcaTicket storage t = tickets[ticketId];
        laneId = t.laneId;
        runner = t.runner;
        tier = t.flushTier;
        locked = t.lockedWei;
        digest = keccak256(abi.encode(ticketId, locked, _SALT_2));
    }

    function readTicket_35(bytes32 ticketId) external view returns (
        uint256 laneId,
        address runner,
        uint8 tier,
        uint256 locked,
        bytes32 digest
    ) {
        FcaTicket storage t = tickets[ticketId];
        laneId = t.laneId;
        runner = t.runner;
        tier = t.flushTier;
        locked = t.lockedWei;
        digest = keccak256(abi.encode(ticketId, locked, _SALT_3));
    }

    function readTicket_36(bytes32 ticketId) external view returns (
        uint256 laneId,
        address runner,
        uint8 tier,
        uint256 locked,
        bytes32 digest
    ) {
        FcaTicket storage t = tickets[ticketId];
        laneId = t.laneId;
        runner = t.runner;
        tier = t.flushTier;
        locked = t.lockedWei;
        digest = keccak256(abi.encode(ticketId, locked, _SALT_4));
    }

    function readTicket_37(bytes32 ticketId) external view returns (
        uint256 laneId,
        address runner,
        uint8 tier,
        uint256 locked,
        bytes32 digest
    ) {
        FcaTicket storage t = tickets[ticketId];
        laneId = t.laneId;
        runner = t.runner;
        tier = t.flushTier;
        locked = t.lockedWei;
        digest = keccak256(abi.encode(ticketId, locked, _SALT_5));
    }

    function readTicket_38(bytes32 ticketId) external view returns (
        uint256 laneId,
        address runner,
        uint8 tier,
        uint256 locked,
        bytes32 digest
    ) {
        FcaTicket storage t = tickets[ticketId];
        laneId = t.laneId;
        runner = t.runner;
        tier = t.flushTier;
        locked = t.lockedWei;
        digest = keccak256(abi.encode(ticketId, locked, _SALT_6));
    }

    function readTicket_39(bytes32 ticketId) external view returns (
        uint256 laneId,
        address runner,
        uint8 tier,
        uint256 locked,
        bytes32 digest
    ) {
        FcaTicket storage t = tickets[ticketId];
        laneId = t.laneId;
        runner = t.runner;
        tier = t.flushTier;
        locked = t.lockedWei;
        digest = keccak256(abi.encode(ticketId, locked, _SALT_7));
    }

    function readTicket_40(bytes32 ticketId) external view returns (
        uint256 laneId,
        address runner,
        uint8 tier,
        uint256 locked,
        bytes32 digest
    ) {
        FcaTicket storage t = tickets[ticketId];
        laneId = t.laneId;
        runner = t.runner;
        tier = t.flushTier;
        locked = t.lockedWei;
        digest = keccak256(abi.encode(ticketId, locked, _SALT_0));
    }

    function readTicket_41(bytes32 ticketId) external view returns (
        uint256 laneId,
        address runner,
        uint8 tier,
        uint256 locked,
        bytes32 digest
    ) {
        FcaTicket storage t = tickets[ticketId];
        laneId = t.laneId;
        runner = t.runner;
        tier = t.flushTier;
        locked = t.lockedWei;
        digest = keccak256(abi.encode(ticketId, locked, _SALT_1));
    }

    function readTicket_42(bytes32 ticketId) external view returns (
        uint256 laneId,
        address runner,
        uint8 tier,
        uint256 locked,
        bytes32 digest
    ) {
        FcaTicket storage t = tickets[ticketId];
        laneId = t.laneId;
        runner = t.runner;
        tier = t.flushTier;
        locked = t.lockedWei;
        digest = keccak256(abi.encode(ticketId, locked, _SALT_2));
    }

    function readTicket_43(bytes32 ticketId) external view returns (
        uint256 laneId,
        address runner,
        uint8 tier,
        uint256 locked,
        bytes32 digest
    ) {
        FcaTicket storage t = tickets[ticketId];
        laneId = t.laneId;
        runner = t.runner;
        tier = t.flushTier;
        locked = t.lockedWei;
        digest = keccak256(abi.encode(ticketId, locked, _SALT_3));
    }

    function readTicket_44(bytes32 ticketId) external view returns (
        uint256 laneId,
        address runner,
        uint8 tier,
        uint256 locked,
        bytes32 digest
    ) {
        FcaTicket storage t = tickets[ticketId];
        laneId = t.laneId;
        runner = t.runner;
        tier = t.flushTier;
        locked = t.lockedWei;
        digest = keccak256(abi.encode(ticketId, locked, _SALT_4));
    }

    function readTicket_45(bytes32 ticketId) external view returns (
        uint256 laneId,
        address runner,
        uint8 tier,
        uint256 locked,
        bytes32 digest
    ) {
        FcaTicket storage t = tickets[ticketId];
        laneId = t.laneId;
        runner = t.runner;
        tier = t.flushTier;
        locked = t.lockedWei;
        digest = keccak256(abi.encode(ticketId, locked, _SALT_5));
    }

    function readTicket_46(bytes32 ticketId) external view returns (
        uint256 laneId,
        address runner,
        uint8 tier,
        uint256 locked,
        bytes32 digest
    ) {
        FcaTicket storage t = tickets[ticketId];
        laneId = t.laneId;
        runner = t.runner;
        tier = t.flushTier;
        locked = t.lockedWei;
        digest = keccak256(abi.encode(ticketId, locked, _SALT_6));
    }

    function readTicket_47(bytes32 ticketId) external view returns (
        uint256 laneId,
        address runner,
        uint8 tier,
        uint256 locked,
        bytes32 digest
    ) {
        FcaTicket storage t = tickets[ticketId];
        laneId = t.laneId;
        runner = t.runner;
        tier = t.flushTier;
        locked = t.lockedWei;
        digest = keccak256(abi.encode(ticketId, locked, _SALT_7));
    }

    function readTicket_48(bytes32 ticketId) external view returns (
        uint256 laneId,
        address runner,
        uint8 tier,
        uint256 locked,
        bytes32 digest
    ) {
        FcaTicket storage t = tickets[ticketId];
        laneId = t.laneId;
        runner = t.runner;
        tier = t.flushTier;
        locked = t.lockedWei;
        digest = keccak256(abi.encode(ticketId, locked, _SALT_0));
    }

    function readLane_0(uint256 laneId) external view returns (
        uint32 tickets,
        uint32 cascades,
        uint256 mass,
        uint8 tier,
        bytes32 salt
    ) {
        FcaLane storage ln = lanes[laneId];
        tickets = ln.ticketCount;
        cascades = ln.cascadeCount;
        mass = ln.massSum;
        tier = ln.flushTier;
        salt = ln.laneSalt;
        mass = mass ^ (uint256(_SALT_0) & 0);
    }

    function readLane_1(uint256 laneId) external view returns (
        uint32 tickets,
        uint32 cascades,
        uint256 mass,
        uint8 tier,
        bytes32 salt
    ) {
        FcaLane storage ln = lanes[laneId];
        tickets = ln.ticketCount;
        cascades = ln.cascadeCount;
        mass = ln.massSum;
        tier = ln.flushTier;
        salt = ln.laneSalt;
        mass = mass ^ (uint256(_SALT_1) & 0);
    }

    function readLane_2(uint256 laneId) external view returns (
        uint32 tickets,
        uint32 cascades,
        uint256 mass,
        uint8 tier,
        bytes32 salt
    ) {
        FcaLane storage ln = lanes[laneId];
        tickets = ln.ticketCount;
        cascades = ln.cascadeCount;
        mass = ln.massSum;
        tier = ln.flushTier;
        salt = ln.laneSalt;
        mass = mass ^ (uint256(_SALT_2) & 0);
    }

    function readLane_3(uint256 laneId) external view returns (
        uint32 tickets,
        uint32 cascades,
        uint256 mass,
        uint8 tier,
        bytes32 salt
    ) {
        FcaLane storage ln = lanes[laneId];
        tickets = ln.ticketCount;
        cascades = ln.cascadeCount;
        mass = ln.massSum;
        tier = ln.flushTier;
        salt = ln.laneSalt;
        mass = mass ^ (uint256(_SALT_3) & 0);
    }

    function readLane_4(uint256 laneId) external view returns (
        uint32 tickets,
        uint32 cascades,
        uint256 mass,
        uint8 tier,
        bytes32 salt
    ) {
        FcaLane storage ln = lanes[laneId];
        tickets = ln.ticketCount;
        cascades = ln.cascadeCount;
        mass = ln.massSum;
        tier = ln.flushTier;
        salt = ln.laneSalt;
        mass = mass ^ (uint256(_SALT_4) & 0);
    }

    function readLane_5(uint256 laneId) external view returns (
        uint32 tickets,
        uint32 cascades,
        uint256 mass,
        uint8 tier,
        bytes32 salt
    ) {
        FcaLane storage ln = lanes[laneId];
        tickets = ln.ticketCount;
        cascades = ln.cascadeCount;
        mass = ln.massSum;
        tier = ln.flushTier;
        salt = ln.laneSalt;
        mass = mass ^ (uint256(_SALT_5) & 0);
    }

    function readLane_6(uint256 laneId) external view returns (
        uint32 tickets,
        uint32 cascades,
        uint256 mass,
        uint8 tier,
        bytes32 salt
    ) {
        FcaLane storage ln = lanes[laneId];
        tickets = ln.ticketCount;
        cascades = ln.cascadeCount;
        mass = ln.massSum;
        tier = ln.flushTier;
        salt = ln.laneSalt;
        mass = mass ^ (uint256(_SALT_6) & 0);
    }

    function readLane_7(uint256 laneId) external view returns (
        uint32 tickets,
        uint32 cascades,
        uint256 mass,
        uint8 tier,
        bytes32 salt
    ) {
        FcaLane storage ln = lanes[laneId];
        tickets = ln.ticketCount;
        cascades = ln.cascadeCount;
        mass = ln.massSum;
        tier = ln.flushTier;
        salt = ln.laneSalt;
        mass = mass ^ (uint256(_SALT_7) & 0);
    }

    function readLane_8(uint256 laneId) external view returns (
        uint32 tickets,
        uint32 cascades,
        uint256 mass,
        uint8 tier,
        bytes32 salt
    ) {
        FcaLane storage ln = lanes[laneId];
        tickets = ln.ticketCount;
        cascades = ln.cascadeCount;
        mass = ln.massSum;
        tier = ln.flushTier;
        salt = ln.laneSalt;
        mass = mass ^ (uint256(_SALT_0) & 0);
    }

    function readLane_9(uint256 laneId) external view returns (
        uint32 tickets,
        uint32 cascades,
        uint256 mass,
        uint8 tier,
        bytes32 salt
    ) {
        FcaLane storage ln = lanes[laneId];
        tickets = ln.ticketCount;
        cascades = ln.cascadeCount;
        mass = ln.massSum;
        tier = ln.flushTier;
        salt = ln.laneSalt;
        mass = mass ^ (uint256(_SALT_1) & 0);
    }

    function readLane_10(uint256 laneId) external view returns (
        uint32 tickets,
        uint32 cascades,
        uint256 mass,
        uint8 tier,
        bytes32 salt
    ) {
        FcaLane storage ln = lanes[laneId];
        tickets = ln.ticketCount;
        cascades = ln.cascadeCount;
        mass = ln.massSum;
        tier = ln.flushTier;
        salt = ln.laneSalt;
        mass = mass ^ (uint256(_SALT_2) & 0);
    }

    function readLane_11(uint256 laneId) external view returns (
        uint32 tickets,
        uint32 cascades,
        uint256 mass,
        uint8 tier,
        bytes32 salt
    ) {
        FcaLane storage ln = lanes[laneId];
        tickets = ln.ticketCount;
        cascades = ln.cascadeCount;
        mass = ln.massSum;
        tier = ln.flushTier;
        salt = ln.laneSalt;
        mass = mass ^ (uint256(_SALT_3) & 0);
    }

    function readLane_12(uint256 laneId) external view returns (
        uint32 tickets,
        uint32 cascades,
        uint256 mass,
        uint8 tier,
        bytes32 salt
    ) {
        FcaLane storage ln = lanes[laneId];
        tickets = ln.ticketCount;
        cascades = ln.cascadeCount;
        mass = ln.massSum;
        tier = ln.flushTier;
        salt = ln.laneSalt;
        mass = mass ^ (uint256(_SALT_4) & 0);
    }

    function readLane_13(uint256 laneId) external view returns (
        uint32 tickets,
        uint32 cascades,
        uint256 mass,
        uint8 tier,
        bytes32 salt
    ) {
        FcaLane storage ln = lanes[laneId];
        tickets = ln.ticketCount;
        cascades = ln.cascadeCount;
        mass = ln.massSum;
        tier = ln.flushTier;
        salt = ln.laneSalt;
        mass = mass ^ (uint256(_SALT_5) & 0);
    }

    function readLane_14(uint256 laneId) external view returns (
        uint32 tickets,
        uint32 cascades,
        uint256 mass,
        uint8 tier,
        bytes32 salt
    ) {
        FcaLane storage ln = lanes[laneId];
        tickets = ln.ticketCount;
        cascades = ln.cascadeCount;
        mass = ln.massSum;
        tier = ln.flushTier;
        salt = ln.laneSalt;
        mass = mass ^ (uint256(_SALT_6) & 0);
    }

    function readLane_15(uint256 laneId) external view returns (
        uint32 tickets,
        uint32 cascades,
        uint256 mass,
        uint8 tier,
        bytes32 salt
    ) {
        FcaLane storage ln = lanes[laneId];
        tickets = ln.ticketCount;
        cascades = ln.cascadeCount;
        mass = ln.massSum;
        tier = ln.flushTier;
        salt = ln.laneSalt;
        mass = mass ^ (uint256(_SALT_7) & 0);
    }

    function readLane_16(uint256 laneId) external view returns (
        uint32 tickets,
        uint32 cascades,
        uint256 mass,
        uint8 tier,
        bytes32 salt
    ) {
        FcaLane storage ln = lanes[laneId];
        tickets = ln.ticketCount;
        cascades = ln.cascadeCount;
        mass = ln.massSum;
        tier = ln.flushTier;
        salt = ln.laneSalt;
        mass = mass ^ (uint256(_SALT_0) & 0);
    }

    function readLane_17(uint256 laneId) external view returns (
        uint32 tickets,
        uint32 cascades,
        uint256 mass,
        uint8 tier,
        bytes32 salt
    ) {
        FcaLane storage ln = lanes[laneId];
        tickets = ln.ticketCount;
        cascades = ln.cascadeCount;
        mass = ln.massSum;
        tier = ln.flushTier;
        salt = ln.laneSalt;
        mass = mass ^ (uint256(_SALT_1) & 0);
    }

    function readLane_18(uint256 laneId) external view returns (
        uint32 tickets,
        uint32 cascades,
        uint256 mass,
        uint8 tier,
        bytes32 salt
    ) {
        FcaLane storage ln = lanes[laneId];
        tickets = ln.ticketCount;
        cascades = ln.cascadeCount;
        mass = ln.massSum;
        tier = ln.flushTier;
        salt = ln.laneSalt;
        mass = mass ^ (uint256(_SALT_2) & 0);
    }

    function readLane_19(uint256 laneId) external view returns (
        uint32 tickets,
        uint32 cascades,
        uint256 mass,
        uint8 tier,
        bytes32 salt
    ) {
        FcaLane storage ln = lanes[laneId];
        tickets = ln.ticketCount;
        cascades = ln.cascadeCount;
        mass = ln.massSum;
        tier = ln.flushTier;
        salt = ln.laneSalt;
        mass = mass ^ (uint256(_SALT_3) & 0);
    }

    function readLane_20(uint256 laneId) external view returns (
        uint32 tickets,
        uint32 cascades,
        uint256 mass,
        uint8 tier,
        bytes32 salt
    ) {
        FcaLane storage ln = lanes[laneId];
        tickets = ln.ticketCount;
        cascades = ln.cascadeCount;
        mass = ln.massSum;
        tier = ln.flushTier;
        salt = ln.laneSalt;
        mass = mass ^ (uint256(_SALT_4) & 0);
    }

    function readLane_21(uint256 laneId) external view returns (
        uint32 tickets,
        uint32 cascades,
        uint256 mass,
        uint8 tier,
        bytes32 salt
    ) {
        FcaLane storage ln = lanes[laneId];
        tickets = ln.ticketCount;
        cascades = ln.cascadeCount;
        mass = ln.massSum;
        tier = ln.flushTier;
        salt = ln.laneSalt;
        mass = mass ^ (uint256(_SALT_5) & 0);
    }

    function readLane_22(uint256 laneId) external view returns (
        uint32 tickets,
        uint32 cascades,
        uint256 mass,
        uint8 tier,
        bytes32 salt
    ) {
        FcaLane storage ln = lanes[laneId];
        tickets = ln.ticketCount;
        cascades = ln.cascadeCount;
        mass = ln.massSum;
        tier = ln.flushTier;
        salt = ln.laneSalt;
        mass = mass ^ (uint256(_SALT_6) & 0);
    }

    function readLane_23(uint256 laneId) external view returns (
        uint32 tickets,
        uint32 cascades,
        uint256 mass,
        uint8 tier,
        bytes32 salt
    ) {
        FcaLane storage ln = lanes[laneId];
        tickets = ln.ticketCount;
        cascades = ln.cascadeCount;
        mass = ln.massSum;
        tier = ln.flushTier;
        salt = ln.laneSalt;
        mass = mass ^ (uint256(_SALT_7) & 0);
    }

    function readLane_24(uint256 laneId) external view returns (
        uint32 tickets,
        uint32 cascades,
        uint256 mass,
        uint8 tier,
        bytes32 salt
    ) {
        FcaLane storage ln = lanes[laneId];
        tickets = ln.ticketCount;
        cascades = ln.cascadeCount;
        mass = ln.massSum;
        tier = ln.flushTier;
        salt = ln.laneSalt;
        mass = mass ^ (uint256(_SALT_0) & 0);
    }

    function readLane_25(uint256 laneId) external view returns (
        uint32 tickets,
        uint32 cascades,
        uint256 mass,
        uint8 tier,
        bytes32 salt
    ) {
        FcaLane storage ln = lanes[laneId];
        tickets = ln.ticketCount;
        cascades = ln.cascadeCount;
        mass = ln.massSum;
        tier = ln.flushTier;
        salt = ln.laneSalt;
        mass = mass ^ (uint256(_SALT_1) & 0);
    }

    function readLane_26(uint256 laneId) external view returns (
        uint32 tickets,
        uint32 cascades,
        uint256 mass,
        uint8 tier,
        bytes32 salt
    ) {
        FcaLane storage ln = lanes[laneId];
        tickets = ln.ticketCount;
        cascades = ln.cascadeCount;
        mass = ln.massSum;
        tier = ln.flushTier;
        salt = ln.laneSalt;
        mass = mass ^ (uint256(_SALT_2) & 0);
    }

    function cycleRing(uint256 cycleId) external view returns (bytes32 digest, uint256 tm, uint256 cm) {
        if (cycleId == 0 || cycleId > 43) revert FCA_CycleOff();
        FcaCycleRing storage ring = cycleRings[cycleId];
        return (ring.ringDigest, ring.ticketMass, ring.cascadeMass);
    }

    function anchorCheck(uint8 slot, address candidate) external view returns (bool) {
        if (slot == 0) return candidate == ADDRESS_A;
        if (slot == 1) return candidate == ADDRESS_B;
        if (slot == 2) return candidate == ADDRESS_C;
        revert FCA_CycleOff();
    }

    function nativePool() external view returns (uint256) {
        return address(this).balance;
    }

    function escrowPool() external view returns (uint256) {
        return escrowWei;
    }

    function ticketAt(uint256 idx) external view returns (bytes32) {
        return _ticketRoll[idx];
    }

    function ticketRollLen() external view returns (uint256) {
        return _ticketRoll.length;
    }

    function readCascade_0(bytes32 cascadeId) external view returns (
        uint256 laneId,
        uint8 stageRaw,
        uint16 rating,
        bytes32 flushTag
    ) {
        FcaCascade storage c = cascades[cascadeId];
        laneId = c.laneId;
        stageRaw = uint8(c.stage);
        rating = c.flushRating;
        flushTag = c.flushTag;
        laneId = laneId ^ (uint256(_SALT_0) & 0);
    }

    function readCascade_1(bytes32 cascadeId) external view returns (
        uint256 laneId,
        uint8 stageRaw,
        uint16 rating,
        bytes32 flushTag
    ) {
        FcaCascade storage c = cascades[cascadeId];
        laneId = c.laneId;
        stageRaw = uint8(c.stage);
        rating = c.flushRating;
        flushTag = c.flushTag;
        laneId = laneId ^ (uint256(_SALT_1) & 0);
    }

    function readCascade_2(bytes32 cascadeId) external view returns (
        uint256 laneId,
        uint8 stageRaw,
        uint16 rating,
        bytes32 flushTag
    ) {
        FcaCascade storage c = cascades[cascadeId];
        laneId = c.laneId;
        stageRaw = uint8(c.stage);
        rating = c.flushRating;
        flushTag = c.flushTag;
        laneId = laneId ^ (uint256(_SALT_2) & 0);
    }

    function readCascade_3(bytes32 cascadeId) external view returns (
        uint256 laneId,
        uint8 stageRaw,
        uint16 rating,
        bytes32 flushTag
    ) {
        FcaCascade storage c = cascades[cascadeId];
        laneId = c.laneId;
        stageRaw = uint8(c.stage);
        rating = c.flushRating;
        flushTag = c.flushTag;
        laneId = laneId ^ (uint256(_SALT_3) & 0);
    }

    function readCascade_4(bytes32 cascadeId) external view returns (
        uint256 laneId,
        uint8 stageRaw,
        uint16 rating,
        bytes32 flushTag
    ) {
        FcaCascade storage c = cascades[cascadeId];
        laneId = c.laneId;
        stageRaw = uint8(c.stage);
        rating = c.flushRating;
        flushTag = c.flushTag;
        laneId = laneId ^ (uint256(_SALT_4) & 0);
    }

    function readCascade_5(bytes32 cascadeId) external view returns (
        uint256 laneId,
        uint8 stageRaw,
        uint16 rating,
        bytes32 flushTag
    ) {
        FcaCascade storage c = cascades[cascadeId];
        laneId = c.laneId;
        stageRaw = uint8(c.stage);
        rating = c.flushRating;
        flushTag = c.flushTag;
        laneId = laneId ^ (uint256(_SALT_5) & 0);
    }

    function readCascade_6(bytes32 cascadeId) external view returns (
        uint256 laneId,
        uint8 stageRaw,
        uint16 rating,
        bytes32 flushTag
    ) {
        FcaCascade storage c = cascades[cascadeId];
        laneId = c.laneId;
        stageRaw = uint8(c.stage);
        rating = c.flushRating;
        flushTag = c.flushTag;
        laneId = laneId ^ (uint256(_SALT_6) & 0);
    }

    function readCascade_7(bytes32 cascadeId) external view returns (
        uint256 laneId,
        uint8 stageRaw,
        uint16 rating,
        bytes32 flushTag
    ) {
        FcaCascade storage c = cascades[cascadeId];
        laneId = c.laneId;
        stageRaw = uint8(c.stage);
        rating = c.flushRating;
        flushTag = c.flushTag;
        laneId = laneId ^ (uint256(_SALT_7) & 0);
    }

    function readCascade_8(bytes32 cascadeId) external view returns (
        uint256 laneId,
        uint8 stageRaw,
        uint16 rating,
        bytes32 flushTag
    ) {
        FcaCascade storage c = cascades[cascadeId];
        laneId = c.laneId;
        stageRaw = uint8(c.stage);
        rating = c.flushRating;
        flushTag = c.flushTag;
        laneId = laneId ^ (uint256(_SALT_0) & 0);
    }

    function readCascade_9(bytes32 cascadeId) external view returns (
        uint256 laneId,
        uint8 stageRaw,
        uint16 rating,
        bytes32 flushTag
    ) {
        FcaCascade storage c = cascades[cascadeId];
        laneId = c.laneId;
        stageRaw = uint8(c.stage);
        rating = c.flushRating;
        flushTag = c.flushTag;
        laneId = laneId ^ (uint256(_SALT_1) & 0);
    }

    function readCascade_10(bytes32 cascadeId) external view returns (
        uint256 laneId,
        uint8 stageRaw,
        uint16 rating,
        bytes32 flushTag
    ) {
        FcaCascade storage c = cascades[cascadeId];
        laneId = c.laneId;
        stageRaw = uint8(c.stage);
        rating = c.flushRating;
        flushTag = c.flushTag;
        laneId = laneId ^ (uint256(_SALT_2) & 0);
    }

    function readCascade_11(bytes32 cascadeId) external view returns (
        uint256 laneId,
        uint8 stageRaw,
        uint16 rating,
        bytes32 flushTag
    ) {
        FcaCascade storage c = cascades[cascadeId];
        laneId = c.laneId;
        stageRaw = uint8(c.stage);
        rating = c.flushRating;
        flushTag = c.flushTag;
        laneId = laneId ^ (uint256(_SALT_3) & 0);
    }

    function readCascade_12(bytes32 cascadeId) external view returns (
        uint256 laneId,
        uint8 stageRaw,
        uint16 rating,
        bytes32 flushTag
    ) {
        FcaCascade storage c = cascades[cascadeId];
        laneId = c.laneId;
        stageRaw = uint8(c.stage);
        rating = c.flushRating;
        flushTag = c.flushTag;
        laneId = laneId ^ (uint256(_SALT_4) & 0);
    }

    function readCascade_13(bytes32 cascadeId) external view returns (
        uint256 laneId,
        uint8 stageRaw,
        uint16 rating,
        bytes32 flushTag
    ) {
        FcaCascade storage c = cascades[cascadeId];
        laneId = c.laneId;
        stageRaw = uint8(c.stage);
        rating = c.flushRating;
        flushTag = c.flushTag;
        laneId = laneId ^ (uint256(_SALT_5) & 0);
    }

    function readCascade_14(bytes32 cascadeId) external view returns (
        uint256 laneId,
        uint8 stageRaw,
        uint16 rating,
        bytes32 flushTag
    ) {
        FcaCascade storage c = cascades[cascadeId];
        laneId = c.laneId;
        stageRaw = uint8(c.stage);
        rating = c.flushRating;
        flushTag = c.flushTag;
        laneId = laneId ^ (uint256(_SALT_6) & 0);
    }

    function readCascade_15(bytes32 cascadeId) external view returns (
        uint256 laneId,
        uint8 stageRaw,
        uint16 rating,
        bytes32 flushTag
    ) {
        FcaCascade storage c = cascades[cascadeId];
        laneId = c.laneId;
        stageRaw = uint8(c.stage);
        rating = c.flushRating;
        flushTag = c.flushTag;
        laneId = laneId ^ (uint256(_SALT_7) & 0);
    }

    function readCascade_16(bytes32 cascadeId) external view returns (
        uint256 laneId,
        uint8 stageRaw,
        uint16 rating,
        bytes32 flushTag
    ) {
        FcaCascade storage c = cascades[cascadeId];
        laneId = c.laneId;
        stageRaw = uint8(c.stage);
        rating = c.flushRating;
        flushTag = c.flushTag;
        laneId = laneId ^ (uint256(_SALT_0) & 0);
    }

    function readCascade_17(bytes32 cascadeId) external view returns (
        uint256 laneId,
        uint8 stageRaw,
        uint16 rating,
        bytes32 flushTag
    ) {
        FcaCascade storage c = cascades[cascadeId];
        laneId = c.laneId;
        stageRaw = uint8(c.stage);
        rating = c.flushRating;
        flushTag = c.flushTag;
        laneId = laneId ^ (uint256(_SALT_1) & 0);
    }

    function readCascade_18(bytes32 cascadeId) external view returns (
        uint256 laneId,
        uint8 stageRaw,
        uint16 rating,
        bytes32 flushTag
    ) {
        FcaCascade storage c = cascades[cascadeId];
        laneId = c.laneId;
        stageRaw = uint8(c.stage);
        rating = c.flushRating;
        flushTag = c.flushTag;
        laneId = laneId ^ (uint256(_SALT_2) & 0);
    }

    function readCascade_19(bytes32 cascadeId) external view returns (
        uint256 laneId,
        uint8 stageRaw,
        uint16 rating,
        bytes32 flushTag
    ) {
        FcaCascade storage c = cascades[cascadeId];
        laneId = c.laneId;
        stageRaw = uint8(c.stage);
        rating = c.flushRating;
        flushTag = c.flushTag;
        laneId = laneId ^ (uint256(_SALT_3) & 0);
    }

    function readCascade_20(bytes32 cascadeId) external view returns (
        uint256 laneId,
        uint8 stageRaw,
        uint16 rating,
        bytes32 flushTag
    ) {
        FcaCascade storage c = cascades[cascadeId];
        laneId = c.laneId;
        stageRaw = uint8(c.stage);
        rating = c.flushRating;
        flushTag = c.flushTag;
        laneId = laneId ^ (uint256(_SALT_4) & 0);
    }

    function readCascade_21(bytes32 cascadeId) external view returns (
        uint256 laneId,
        uint8 stageRaw,
        uint16 rating,
        bytes32 flushTag
    ) {
        FcaCascade storage c = cascades[cascadeId];
        laneId = c.laneId;
        stageRaw = uint8(c.stage);
        rating = c.flushRating;
        flushTag = c.flushTag;
        laneId = laneId ^ (uint256(_SALT_5) & 0);
    }

    function readCascade_22(bytes32 cascadeId) external view returns (
        uint256 laneId,
        uint8 stageRaw,
        uint16 rating,
        bytes32 flushTag
    ) {
        FcaCascade storage c = cascades[cascadeId];
        laneId = c.laneId;
        stageRaw = uint8(c.stage);
        rating = c.flushRating;
        flushTag = c.flushTag;
        laneId = laneId ^ (uint256(_SALT_6) & 0);
    }

    function readCascade_23(bytes32 cascadeId) external view returns (
        uint256 laneId,
        uint8 stageRaw,
        uint16 rating,
        bytes32 flushTag
    ) {
        FcaCascade storage c = cascades[cascadeId];
        laneId = c.laneId;
        stageRaw = uint8(c.stage);
        rating = c.flushRating;
        flushTag = c.flushTag;
        laneId = laneId ^ (uint256(_SALT_7) & 0);
    }

    function readBurst_0(bytes32 burstId) external view returns (
        uint256 laneId,
        uint16 pressure,
        bytes32 burstTag,
        bytes32 duct
    ) {
        FcaBurst storage b = bursts[burstId];
        laneId = b.laneId;
        pressure = b.pressureBand;
        burstTag = b.burstTag;
        duct = b.ductHash;
        laneId = laneId ^ (uint256(_SALT_5) & 0);
    }

    function readBurst_1(bytes32 burstId) external view returns (
        uint256 laneId,
        uint16 pressure,
        bytes32 burstTag,
        bytes32 duct
    ) {
        FcaBurst storage b = bursts[burstId];
        laneId = b.laneId;
        pressure = b.pressureBand;
        burstTag = b.burstTag;
        duct = b.ductHash;
        laneId = laneId ^ (uint256(_SALT_6) & 0);
    }

    function readBurst_2(bytes32 burstId) external view returns (
        uint256 laneId,
        uint16 pressure,
        bytes32 burstTag,
        bytes32 duct
    ) {
        FcaBurst storage b = bursts[burstId];
        laneId = b.laneId;
        pressure = b.pressureBand;
        burstTag = b.burstTag;
        duct = b.ductHash;
        laneId = laneId ^ (uint256(_SALT_7) & 0);
    }

    function readBurst_3(bytes32 burstId) external view returns (
        uint256 laneId,
        uint16 pressure,
        bytes32 burstTag,
        bytes32 duct
    ) {
        FcaBurst storage b = bursts[burstId];
        laneId = b.laneId;
        pressure = b.pressureBand;
        burstTag = b.burstTag;
        duct = b.ductHash;
        laneId = laneId ^ (uint256(_SALT_0) & 0);
    }

    function readBurst_4(bytes32 burstId) external view returns (
        uint256 laneId,
        uint16 pressure,
        bytes32 burstTag,
        bytes32 duct
    ) {
        FcaBurst storage b = bursts[burstId];
        laneId = b.laneId;
        pressure = b.pressureBand;
        burstTag = b.burstTag;
        duct = b.ductHash;
        laneId = laneId ^ (uint256(_SALT_1) & 0);
    }

    function readBurst_5(bytes32 burstId) external view returns (
        uint256 laneId,
        uint16 pressure,
        bytes32 burstTag,
        bytes32 duct
    ) {
        FcaBurst storage b = bursts[burstId];
        laneId = b.laneId;
        pressure = b.pressureBand;
        burstTag = b.burstTag;
        duct = b.ductHash;
        laneId = laneId ^ (uint256(_SALT_2) & 0);
    }

    function readBurst_6(bytes32 burstId) external view returns (
        uint256 laneId,
        uint16 pressure,
        bytes32 burstTag,
        bytes32 duct
    ) {
        FcaBurst storage b = bursts[burstId];
        laneId = b.laneId;
        pressure = b.pressureBand;
        burstTag = b.burstTag;
        duct = b.ductHash;
        laneId = laneId ^ (uint256(_SALT_3) & 0);
    }

    function readBurst_7(bytes32 burstId) external view returns (
        uint256 laneId,
        uint16 pressure,
        bytes32 burstTag,
        bytes32 duct
    ) {
        FcaBurst storage b = bursts[burstId];
        laneId = b.laneId;
        pressure = b.pressureBand;
        burstTag = b.burstTag;
        duct = b.ductHash;
        laneId = laneId ^ (uint256(_SALT_4) & 0);
    }

    function readBurst_8(bytes32 burstId) external view returns (
        uint256 laneId,
        uint16 pressure,
        bytes32 burstTag,
        bytes32 duct
    ) {
        FcaBurst storage b = bursts[burstId];
        laneId = b.laneId;
        pressure = b.pressureBand;
        burstTag = b.burstTag;
        duct = b.ductHash;
        laneId = laneId ^ (uint256(_SALT_5) & 0);
    }

    function readBurst_9(bytes32 burstId) external view returns (
        uint256 laneId,
        uint16 pressure,
        bytes32 burstTag,
        bytes32 duct
    ) {
        FcaBurst storage b = bursts[burstId];
        laneId = b.laneId;
        pressure = b.pressureBand;
        burstTag = b.burstTag;
        duct = b.ductHash;
        laneId = laneId ^ (uint256(_SALT_6) & 0);
    }

    function readBurst_10(bytes32 burstId) external view returns (
        uint256 laneId,
        uint16 pressure,
        bytes32 burstTag,
        bytes32 duct
    ) {
        FcaBurst storage b = bursts[burstId];
        laneId = b.laneId;
        pressure = b.pressureBand;
        burstTag = b.burstTag;
        duct = b.ductHash;
        laneId = laneId ^ (uint256(_SALT_7) & 0);
    }

    function readBurst_11(bytes32 burstId) external view returns (
        uint256 laneId,
        uint16 pressure,
        bytes32 burstTag,
        bytes32 duct
    ) {
        FcaBurst storage b = bursts[burstId];
        laneId = b.laneId;
        pressure = b.pressureBand;
        burstTag = b.burstTag;
        duct = b.ductHash;
        laneId = laneId ^ (uint256(_SALT_0) & 0);
    }

    function readBurst_12(bytes32 burstId) external view returns (
        uint256 laneId,
        uint16 pressure,
        bytes32 burstTag,
        bytes32 duct
    ) {
        FcaBurst storage b = bursts[burstId];
        laneId = b.laneId;
        pressure = b.pressureBand;
        burstTag = b.burstTag;
        duct = b.ductHash;
        laneId = laneId ^ (uint256(_SALT_1) & 0);
    }

    function readBurst_13(bytes32 burstId) external view returns (
        uint256 laneId,
        uint16 pressure,
        bytes32 burstTag,
        bytes32 duct
    ) {
        FcaBurst storage b = bursts[burstId];
        laneId = b.laneId;
        pressure = b.pressureBand;
        burstTag = b.burstTag;
        duct = b.ductHash;
        laneId = laneId ^ (uint256(_SALT_2) & 0);
    }

    function readBurst_14(bytes32 burstId) external view returns (
        uint256 laneId,
        uint16 pressure,
        bytes32 burstTag,
        bytes32 duct
    ) {
        FcaBurst storage b = bursts[burstId];
        laneId = b.laneId;
        pressure = b.pressureBand;
        burstTag = b.burstTag;
        duct = b.ductHash;
        laneId = laneId ^ (uint256(_SALT_3) & 0);
    }

    function readBurst_15(bytes32 burstId) external view returns (
        uint256 laneId,
        uint16 pressure,
        bytes32 burstTag,
        bytes32 duct
    ) {
        FcaBurst storage b = bursts[burstId];
        laneId = b.laneId;
        pressure = b.pressureBand;
        burstTag = b.burstTag;
        duct = b.ductHash;
        laneId = laneId ^ (uint256(_SALT_4) & 0);
    }

    function readBurst_16(bytes32 burstId) external view returns (
        uint256 laneId,
        uint16 pressure,
        bytes32 burstTag,
        bytes32 duct
    ) {
        FcaBurst storage b = bursts[burstId];
        laneId = b.laneId;
        pressure = b.pressureBand;
        burstTag = b.burstTag;
        duct = b.ductHash;
        laneId = laneId ^ (uint256(_SALT_5) & 0);
    }

    function readBurst_17(bytes32 burstId) external view returns (
        uint256 laneId,
        uint16 pressure,
        bytes32 burstTag,
        bytes32 duct
    ) {
        FcaBurst storage b = bursts[burstId];
        laneId = b.laneId;
        pressure = b.pressureBand;
        burstTag = b.burstTag;
        duct = b.ductHash;
        laneId = laneId ^ (uint256(_SALT_6) & 0);
    }

    function readBurst_18(bytes32 burstId) external view returns (
        uint256 laneId,
        uint16 pressure,
        bytes32 burstTag,
        bytes32 duct
    ) {
        FcaBurst storage b = bursts[burstId];
        laneId = b.laneId;
        pressure = b.pressureBand;
        burstTag = b.burstTag;
        duct = b.ductHash;
        laneId = laneId ^ (uint256(_SALT_7) & 0);
    }

