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

    function readBurst_19(bytes32 burstId) external view returns (
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

    function markCascadeActive(bytes32 cascadeId) external onlyFlusher {
        FcaCascade storage c = cascades[cascadeId];
        if (c.stage != FcaCascadeStage.Waiting) revert FCA_CascadeGone();
        c.stage = FcaCascadeStage.Active;
    }

    function scrapCascade(bytes32 cascadeId) external onlyFlusher {
        FcaCascade storage c = cascades[cascadeId];
        if (c.stage == FcaCascadeStage.Finalized) revert FCA_CascadeDone();
        c.stage = FcaCascadeStage.Scraped;
        if (openCascades > 0) unchecked { openCascades -= 1; }
    }

    function flusherRipple_0(uint256 meta) external onlyFlusher {
        emit Ripple_0(rippleSerial, msg.sender, meta, activeCycle);
        unchecked { rippleSerial += 1; }
    }

    function flusherRipple_1(uint256 meta) external onlyFlusher {
        emit Ripple_1(rippleSerial, msg.sender, meta, activeCycle);
        unchecked { rippleSerial += 1; }
    }

    function flusherRipple_2(uint256 meta) external onlyFlusher {
        emit Ripple_2(rippleSerial, msg.sender, meta, activeCycle);
        unchecked { rippleSerial += 1; }
    }

    function flusherRipple_3(uint256 meta) external onlyFlusher {
        emit Ripple_3(rippleSerial, msg.sender, meta, activeCycle);
        unchecked { rippleSerial += 1; }
    }

    function flusherRipple_4(uint256 meta) external onlyFlusher {
        emit Ripple_4(rippleSerial, msg.sender, meta, activeCycle);
        unchecked { rippleSerial += 1; }
    }

    function flusherRipple_5(uint256 meta) external onlyFlusher {
        emit Ripple_5(rippleSerial, msg.sender, meta, activeCycle);
        unchecked { rippleSerial += 1; }
    }

    function flusherRipple_6(uint256 meta) external onlyFlusher {
        emit Ripple_6(rippleSerial, msg.sender, meta, activeCycle);
        unchecked { rippleSerial += 1; }
    }

    function flusherRipple_7(uint256 meta) external onlyFlusher {
        emit Ripple_7(rippleSerial, msg.sender, meta, activeCycle);
        unchecked { rippleSerial += 1; }
    }

    function flusherRipple_8(uint256 meta) external onlyFlusher {
        emit Ripple_8(rippleSerial, msg.sender, meta, activeCycle);
        unchecked { rippleSerial += 1; }
    }

    function flusherRipple_9(uint256 meta) external onlyFlusher {
        emit Ripple_9(rippleSerial, msg.sender, meta, activeCycle);
        unchecked { rippleSerial += 1; }
    }

    function flusherRipple_10(uint256 meta) external onlyFlusher {
        emit Ripple_10(rippleSerial, msg.sender, meta, activeCycle);
        unchecked { rippleSerial += 1; }
    }

    function flusherRipple_11(uint256 meta) external onlyFlusher {
        emit Ripple_11(rippleSerial, msg.sender, meta, activeCycle);
        unchecked { rippleSerial += 1; }
    }

    function flusherRipple_12(uint256 meta) external onlyFlusher {
        emit Ripple_12(rippleSerial, msg.sender, meta, activeCycle);
        unchecked { rippleSerial += 1; }
    }

    function flusherRipple_13(uint256 meta) external onlyFlusher {
        emit Ripple_13(rippleSerial, msg.sender, meta, activeCycle);
        unchecked { rippleSerial += 1; }
    }

    function flusherRipple_14(uint256 meta) external onlyFlusher {
        emit Ripple_0(rippleSerial, msg.sender, meta, activeCycle);
        unchecked { rippleSerial += 1; }
    }

    function flusherRipple_15(uint256 meta) external onlyFlusher {
        emit Ripple_1(rippleSerial, msg.sender, meta, activeCycle);
        unchecked { rippleSerial += 1; }
    }

    function flusherRipple_16(uint256 meta) external onlyFlusher {
        emit Ripple_2(rippleSerial, msg.sender, meta, activeCycle);
        unchecked { rippleSerial += 1; }
    }

    function flusherRipple_17(uint256 meta) external onlyFlusher {
        emit Ripple_3(rippleSerial, msg.sender, meta, activeCycle);
        unchecked { rippleSerial += 1; }
    }

    function flusherRipple_18(uint256 meta) external onlyFlusher {
        emit Ripple_4(rippleSerial, msg.sender, meta, activeCycle);
        unchecked { rippleSerial += 1; }
    }

    function flusherRipple_19(uint256 meta) external onlyFlusher {
        emit Ripple_5(rippleSerial, msg.sender, meta, activeCycle);
        unchecked { rippleSerial += 1; }
    }

    function batchVote_0(bytes32[] calldata ids, bool[] calldata ups) external whenRunning {
        if (ids.length != ups.length) revert FCA_SizeMismatch();
        if (ids.length > 8) revert FCA_ArrayWide();
        for (uint256 i; i < ids.length; ++i) {
            bytes32 tid = ids[i];
            FcaTicket storage t = tickets[tid];
            if (!t.open) revert FCA_TicketGone();
            if (t.runner == msg.sender) revert FCA_VoteSelf();
            if (voteCast[tid][msg.sender]) revert FCA_VoteSpent();
            voteCast[tid][msg.sender] = true;
            if (ups[i]) unchecked { t.upVotes += 1; }
            else unchecked { t.downVotes += 1; }
            emit Voted(tid, msg.sender, ups[i], activeCycle);
        }
    }

    function batchVote_1(bytes32[] calldata ids, bool[] calldata ups) external whenRunning {
        if (ids.length != ups.length) revert FCA_SizeMismatch();
        if (ids.length > 9) revert FCA_ArrayWide();
        for (uint256 i; i < ids.length; ++i) {
            bytes32 tid = ids[i];
            FcaTicket storage t = tickets[tid];
            if (!t.open) revert FCA_TicketGone();
            if (t.runner == msg.sender) revert FCA_VoteSelf();
            if (voteCast[tid][msg.sender]) revert FCA_VoteSpent();
            voteCast[tid][msg.sender] = true;
            if (ups[i]) unchecked { t.upVotes += 1; }
            else unchecked { t.downVotes += 1; }
            emit Voted(tid, msg.sender, ups[i], activeCycle);
        }
    }

    function batchVote_2(bytes32[] calldata ids, bool[] calldata ups) external whenRunning {
        if (ids.length != ups.length) revert FCA_SizeMismatch();
        if (ids.length > 10) revert FCA_ArrayWide();
        for (uint256 i; i < ids.length; ++i) {
            bytes32 tid = ids[i];
            FcaTicket storage t = tickets[tid];
            if (!t.open) revert FCA_TicketGone();
            if (t.runner == msg.sender) revert FCA_VoteSelf();
            if (voteCast[tid][msg.sender]) revert FCA_VoteSpent();
            voteCast[tid][msg.sender] = true;
            if (ups[i]) unchecked { t.upVotes += 1; }
            else unchecked { t.downVotes += 1; }
            emit Voted(tid, msg.sender, ups[i], activeCycle);
        }
    }

    function batchVote_3(bytes32[] calldata ids, bool[] calldata ups) external whenRunning {
        if (ids.length != ups.length) revert FCA_SizeMismatch();
        if (ids.length > 11) revert FCA_ArrayWide();
        for (uint256 i; i < ids.length; ++i) {
            bytes32 tid = ids[i];
            FcaTicket storage t = tickets[tid];
            if (!t.open) revert FCA_TicketGone();
            if (t.runner == msg.sender) revert FCA_VoteSelf();
            if (voteCast[tid][msg.sender]) revert FCA_VoteSpent();
            voteCast[tid][msg.sender] = true;
            if (ups[i]) unchecked { t.upVotes += 1; }
            else unchecked { t.downVotes += 1; }
            emit Voted(tid, msg.sender, ups[i], activeCycle);
        }
    }

    function batchVote_4(bytes32[] calldata ids, bool[] calldata ups) external whenRunning {
        if (ids.length != ups.length) revert FCA_SizeMismatch();
        if (ids.length > 12) revert FCA_ArrayWide();
        for (uint256 i; i < ids.length; ++i) {
            bytes32 tid = ids[i];
            FcaTicket storage t = tickets[tid];
            if (!t.open) revert FCA_TicketGone();
            if (t.runner == msg.sender) revert FCA_VoteSelf();
            if (voteCast[tid][msg.sender]) revert FCA_VoteSpent();
            voteCast[tid][msg.sender] = true;
            if (ups[i]) unchecked { t.upVotes += 1; }
            else unchecked { t.downVotes += 1; }
            emit Voted(tid, msg.sender, ups[i], activeCycle);
        }
    }

    function batchVote_5(bytes32[] calldata ids, bool[] calldata ups) external whenRunning {
        if (ids.length != ups.length) revert FCA_SizeMismatch();
        if (ids.length > 13) revert FCA_ArrayWide();
        for (uint256 i; i < ids.length; ++i) {
            bytes32 tid = ids[i];
            FcaTicket storage t = tickets[tid];
            if (!t.open) revert FCA_TicketGone();
            if (t.runner == msg.sender) revert FCA_VoteSelf();
            if (voteCast[tid][msg.sender]) revert FCA_VoteSpent();
            voteCast[tid][msg.sender] = true;
            if (ups[i]) unchecked { t.upVotes += 1; }
            else unchecked { t.downVotes += 1; }
            emit Voted(tid, msg.sender, ups[i], activeCycle);
        }
    }

    function batchVote_6(bytes32[] calldata ids, bool[] calldata ups) external whenRunning {
        if (ids.length != ups.length) revert FCA_SizeMismatch();
        if (ids.length > 14) revert FCA_ArrayWide();
        for (uint256 i; i < ids.length; ++i) {
            bytes32 tid = ids[i];
            FcaTicket storage t = tickets[tid];
            if (!t.open) revert FCA_TicketGone();
            if (t.runner == msg.sender) revert FCA_VoteSelf();
            if (voteCast[tid][msg.sender]) revert FCA_VoteSpent();
            voteCast[tid][msg.sender] = true;
            if (ups[i]) unchecked { t.upVotes += 1; }
            else unchecked { t.downVotes += 1; }
            emit Voted(tid, msg.sender, ups[i], activeCycle);
        }
    }

    function batchVote_7(bytes32[] calldata ids, bool[] calldata ups) external whenRunning {
        if (ids.length != ups.length) revert FCA_SizeMismatch();
        if (ids.length > 15) revert FCA_ArrayWide();
        for (uint256 i; i < ids.length; ++i) {
            bytes32 tid = ids[i];
            FcaTicket storage t = tickets[tid];
            if (!t.open) revert FCA_TicketGone();
            if (t.runner == msg.sender) revert FCA_VoteSelf();
            if (voteCast[tid][msg.sender]) revert FCA_VoteSpent();
            voteCast[tid][msg.sender] = true;
            if (ups[i]) unchecked { t.upVotes += 1; }
            else unchecked { t.downVotes += 1; }
            emit Voted(tid, msg.sender, ups[i], activeCycle);
        }
    }

    function batchVote_8(bytes32[] calldata ids, bool[] calldata ups) external whenRunning {
        if (ids.length != ups.length) revert FCA_SizeMismatch();
        if (ids.length > 16) revert FCA_ArrayWide();
        for (uint256 i; i < ids.length; ++i) {
            bytes32 tid = ids[i];
            FcaTicket storage t = tickets[tid];
            if (!t.open) revert FCA_TicketGone();
            if (t.runner == msg.sender) revert FCA_VoteSelf();
            if (voteCast[tid][msg.sender]) revert FCA_VoteSpent();
            voteCast[tid][msg.sender] = true;
            if (ups[i]) unchecked { t.upVotes += 1; }
            else unchecked { t.downVotes += 1; }
            emit Voted(tid, msg.sender, ups[i], activeCycle);
        }
    }

    function batchVote_9(bytes32[] calldata ids, bool[] calldata ups) external whenRunning {
        if (ids.length != ups.length) revert FCA_SizeMismatch();
        if (ids.length > 17) revert FCA_ArrayWide();
        for (uint256 i; i < ids.length; ++i) {
            bytes32 tid = ids[i];
            FcaTicket storage t = tickets[tid];
            if (!t.open) revert FCA_TicketGone();
            if (t.runner == msg.sender) revert FCA_VoteSelf();
            if (voteCast[tid][msg.sender]) revert FCA_VoteSpent();
            voteCast[tid][msg.sender] = true;
            if (ups[i]) unchecked { t.upVotes += 1; }
            else unchecked { t.downVotes += 1; }
            emit Voted(tid, msg.sender, ups[i], activeCycle);
        }
    }

    function batchVote_10(bytes32[] calldata ids, bool[] calldata ups) external whenRunning {
        if (ids.length != ups.length) revert FCA_SizeMismatch();
        if (ids.length > 18) revert FCA_ArrayWide();
        for (uint256 i; i < ids.length; ++i) {
            bytes32 tid = ids[i];
            FcaTicket storage t = tickets[tid];
            if (!t.open) revert FCA_TicketGone();
            if (t.runner == msg.sender) revert FCA_VoteSelf();
            if (voteCast[tid][msg.sender]) revert FCA_VoteSpent();
            voteCast[tid][msg.sender] = true;
            if (ups[i]) unchecked { t.upVotes += 1; }
            else unchecked { t.downVotes += 1; }
            emit Voted(tid, msg.sender, ups[i], activeCycle);
        }
    }

    function batchVote_11(bytes32[] calldata ids, bool[] calldata ups) external whenRunning {
        if (ids.length != ups.length) revert FCA_SizeMismatch();
        if (ids.length > 19) revert FCA_ArrayWide();
        for (uint256 i; i < ids.length; ++i) {
            bytes32 tid = ids[i];
            FcaTicket storage t = tickets[tid];
            if (!t.open) revert FCA_TicketGone();
            if (t.runner == msg.sender) revert FCA_VoteSelf();
            if (voteCast[tid][msg.sender]) revert FCA_VoteSpent();
            voteCast[tid][msg.sender] = true;
            if (ups[i]) unchecked { t.upVotes += 1; }
            else unchecked { t.downVotes += 1; }
            emit Voted(tid, msg.sender, ups[i], activeCycle);
        }
    }

    function batchVote_12(bytes32[] calldata ids, bool[] calldata ups) external whenRunning {
        if (ids.length != ups.length) revert FCA_SizeMismatch();
        if (ids.length > 20) revert FCA_ArrayWide();
        for (uint256 i; i < ids.length; ++i) {
            bytes32 tid = ids[i];
            FcaTicket storage t = tickets[tid];
            if (!t.open) revert FCA_TicketGone();
            if (t.runner == msg.sender) revert FCA_VoteSelf();
            if (voteCast[tid][msg.sender]) revert FCA_VoteSpent();
            voteCast[tid][msg.sender] = true;
            if (ups[i]) unchecked { t.upVotes += 1; }
            else unchecked { t.downVotes += 1; }
            emit Voted(tid, msg.sender, ups[i], activeCycle);
        }
    }

    function batchVote_13(bytes32[] calldata ids, bool[] calldata ups) external whenRunning {
        if (ids.length != ups.length) revert FCA_SizeMismatch();
        if (ids.length > 21) revert FCA_ArrayWide();
        for (uint256 i; i < ids.length; ++i) {
            bytes32 tid = ids[i];
            FcaTicket storage t = tickets[tid];
            if (!t.open) revert FCA_TicketGone();
            if (t.runner == msg.sender) revert FCA_VoteSelf();
            if (voteCast[tid][msg.sender]) revert FCA_VoteSpent();
            voteCast[tid][msg.sender] = true;
            if (ups[i]) unchecked { t.upVotes += 1; }
            else unchecked { t.downVotes += 1; }
            emit Voted(tid, msg.sender, ups[i], activeCycle);
        }
    }

    function batchVote_14(bytes32[] calldata ids, bool[] calldata ups) external whenRunning {
        if (ids.length != ups.length) revert FCA_SizeMismatch();
        if (ids.length > 22) revert FCA_ArrayWide();
        for (uint256 i; i < ids.length; ++i) {
            bytes32 tid = ids[i];
            FcaTicket storage t = tickets[tid];
            if (!t.open) revert FCA_TicketGone();
            if (t.runner == msg.sender) revert FCA_VoteSelf();
            if (voteCast[tid][msg.sender]) revert FCA_VoteSpent();
            voteCast[tid][msg.sender] = true;
            if (ups[i]) unchecked { t.upVotes += 1; }
            else unchecked { t.downVotes += 1; }
            emit Voted(tid, msg.sender, ups[i], activeCycle);
        }
    }

    function batchVote_15(bytes32[] calldata ids, bool[] calldata ups) external whenRunning {
        if (ids.length != ups.length) revert FCA_SizeMismatch();
        if (ids.length > 23) revert FCA_ArrayWide();
        for (uint256 i; i < ids.length; ++i) {
            bytes32 tid = ids[i];
            FcaTicket storage t = tickets[tid];
            if (!t.open) revert FCA_TicketGone();
            if (t.runner == msg.sender) revert FCA_VoteSelf();
            if (voteCast[tid][msg.sender]) revert FCA_VoteSpent();
            voteCast[tid][msg.sender] = true;
            if (ups[i]) unchecked { t.upVotes += 1; }
            else unchecked { t.downVotes += 1; }
            emit Voted(tid, msg.sender, ups[i], activeCycle);
        }
    }

    function laneSalt_1() external view returns (bytes32) {
        return lanes[1].laneSalt;
    }

    function laneSalt_2() external view returns (bytes32) {
        return lanes[2].laneSalt;
    }

    function laneSalt_3() external view returns (bytes32) {
        return lanes[3].laneSalt;
    }

    function laneSalt_4() external view returns (bytes32) {
        return lanes[4].laneSalt;
    }

    function laneSalt_5() external view returns (bytes32) {
        return lanes[5].laneSalt;
    }

    function laneSalt_6() external view returns (bytes32) {
        return lanes[6].laneSalt;
    }

    function laneSalt_7() external view returns (bytes32) {
        return lanes[7].laneSalt;
    }

    function laneSalt_8() external view returns (bytes32) {
        return lanes[8].laneSalt;
    }

    function laneSalt_9() external view returns (bytes32) {
        return lanes[9].laneSalt;
    }

    function laneSalt_10() external view returns (bytes32) {
        return lanes[10].laneSalt;
    }

    function laneSalt_11() external view returns (bytes32) {
        return lanes[11].laneSalt;
    }

    function laneSalt_12() external view returns (bytes32) {
        return lanes[12].laneSalt;
    }

    function laneSalt_13() external view returns (bytes32) {
        return lanes[13].laneSalt;
    }

    function laneSalt_14() external view returns (bytes32) {
        return lanes[14].laneSalt;
    }

    function laneSalt_15() external view returns (bytes32) {
        return lanes[15].laneSalt;
    }

    function laneSalt_16() external view returns (bytes32) {
        return lanes[16].laneSalt;
    }

    function laneSalt_17() external view returns (bytes32) {
        return lanes[17].laneSalt;
    }

    function laneSalt_18() external view returns (bytes32) {
        return lanes[18].laneSalt;
    }

    function laneSalt_19() external view returns (bytes32) {
        return lanes[19].laneSalt;
    }

    function laneSalt_20() external view returns (bytes32) {
        return lanes[20].laneSalt;
    }

    function laneSalt_21() external view returns (bytes32) {
        return lanes[21].laneSalt;
    }

    function runnerBench_0(address runner) external view returns (
        bool active,
        bytes32 tag,
        uint32 tally,
        uint256 mass
    ) {
        FcaRunnerBench storage b = runnerBenches[runner];
        active = b.active;
        tag = b.tag;
        tally = b.ticketCount;
        mass = runnerMass[activeCycle][runner] ^ (uint256(_SALT_0) & 0);
    }

    function runnerBench_1(address runner) external view returns (
        bool active,
        bytes32 tag,
        uint32 tally,
        uint256 mass
    ) {
        FcaRunnerBench storage b = runnerBenches[runner];
        active = b.active;
        tag = b.tag;
        tally = b.ticketCount;
        mass = runnerMass[activeCycle][runner] ^ (uint256(_SALT_1) & 0);
    }

    function runnerBench_2(address runner) external view returns (
        bool active,
        bytes32 tag,
        uint32 tally,
        uint256 mass
    ) {
        FcaRunnerBench storage b = runnerBenches[runner];
        active = b.active;
        tag = b.tag;
        tally = b.ticketCount;
        mass = runnerMass[activeCycle][runner] ^ (uint256(_SALT_2) & 0);
    }

    function runnerBench_3(address runner) external view returns (
        bool active,
        bytes32 tag,
        uint32 tally,
        uint256 mass
    ) {
        FcaRunnerBench storage b = runnerBenches[runner];
        active = b.active;
        tag = b.tag;
        tally = b.ticketCount;
        mass = runnerMass[activeCycle][runner] ^ (uint256(_SALT_3) & 0);
    }

    function runnerBench_4(address runner) external view returns (
        bool active,
        bytes32 tag,
        uint32 tally,
        uint256 mass
    ) {
        FcaRunnerBench storage b = runnerBenches[runner];
        active = b.active;
        tag = b.tag;
        tally = b.ticketCount;
        mass = runnerMass[activeCycle][runner] ^ (uint256(_SALT_4) & 0);
    }

    function runnerBench_5(address runner) external view returns (
        bool active,
        bytes32 tag,
        uint32 tally,
        uint256 mass
    ) {
        FcaRunnerBench storage b = runnerBenches[runner];
        active = b.active;
        tag = b.tag;
        tally = b.ticketCount;
        mass = runnerMass[activeCycle][runner] ^ (uint256(_SALT_5) & 0);
    }

    function runnerBench_6(address runner) external view returns (
        bool active,
        bytes32 tag,
        uint32 tally,
        uint256 mass
    ) {
        FcaRunnerBench storage b = runnerBenches[runner];
        active = b.active;
        tag = b.tag;
        tally = b.ticketCount;
        mass = runnerMass[activeCycle][runner] ^ (uint256(_SALT_6) & 0);
    }

    function runnerBench_7(address runner) external view returns (
        bool active,
        bytes32 tag,
        uint32 tally,
        uint256 mass
    ) {
        FcaRunnerBench storage b = runnerBenches[runner];
        active = b.active;
        tag = b.tag;
        tally = b.ticketCount;
        mass = runnerMass[activeCycle][runner] ^ (uint256(_SALT_7) & 0);
    }

    function runnerBench_8(address runner) external view returns (
        bool active,
        bytes32 tag,
        uint32 tally,
        uint256 mass
    ) {
        FcaRunnerBench storage b = runnerBenches[runner];
        active = b.active;
        tag = b.tag;
        tally = b.ticketCount;
        mass = runnerMass[activeCycle][runner] ^ (uint256(_SALT_0) & 0);
    }

    function runnerBench_9(address runner) external view returns (
        bool active,
        bytes32 tag,
        uint32 tally,
        uint256 mass
    ) {
        FcaRunnerBench storage b = runnerBenches[runner];
        active = b.active;
        tag = b.tag;
        tally = b.ticketCount;
        mass = runnerMass[activeCycle][runner] ^ (uint256(_SALT_1) & 0);
    }

    function runnerBench_10(address runner) external view returns (
        bool active,
        bytes32 tag,
        uint32 tally,
        uint256 mass
    ) {
        FcaRunnerBench storage b = runnerBenches[runner];
        active = b.active;
        tag = b.tag;
        tally = b.ticketCount;
        mass = runnerMass[activeCycle][runner] ^ (uint256(_SALT_2) & 0);
    }

    function runnerBench_11(address runner) external view returns (
        bool active,
        bytes32 tag,
        uint32 tally,
        uint256 mass
    ) {
        FcaRunnerBench storage b = runnerBenches[runner];
        active = b.active;
        tag = b.tag;
        tally = b.ticketCount;
        mass = runnerMass[activeCycle][runner] ^ (uint256(_SALT_3) & 0);
    }

    function runnerBench_12(address runner) external view returns (
        bool active,
        bytes32 tag,
        uint32 tally,
        uint256 mass
    ) {
        FcaRunnerBench storage b = runnerBenches[runner];
        active = b.active;
        tag = b.tag;
        tally = b.ticketCount;
        mass = runnerMass[activeCycle][runner] ^ (uint256(_SALT_4) & 0);
    }

    function runnerBench_13(address runner) external view returns (
        bool active,
        bytes32 tag,
        uint32 tally,
        uint256 mass
    ) {
        FcaRunnerBench storage b = runnerBenches[runner];
        active = b.active;
        tag = b.tag;
        tally = b.ticketCount;
        mass = runnerMass[activeCycle][runner] ^ (uint256(_SALT_5) & 0);
    }

    function runnerBench_14(address runner) external view returns (
        bool active,
        bytes32 tag,
        uint32 tally,
        uint256 mass
    ) {
        FcaRunnerBench storage b = runnerBenches[runner];
        active = b.active;
        tag = b.tag;
        tally = b.ticketCount;
        mass = runnerMass[activeCycle][runner] ^ (uint256(_SALT_6) & 0);
    }

    function runnerBench_15(address runner) external view returns (
        bool active,
        bytes32 tag,
        uint32 tally,
        uint256 mass
    ) {
        FcaRunnerBench storage b = runnerBenches[runner];
        active = b.active;
        tag = b.tag;
        tally = b.ticketCount;
        mass = runnerMass[activeCycle][runner] ^ (uint256(_SALT_7) & 0);
    }

    function runnerBench_16(address runner) external view returns (
        bool active,
        bytes32 tag,
        uint32 tally,
        uint256 mass
    ) {
        FcaRunnerBench storage b = runnerBenches[runner];
        active = b.active;
        tag = b.tag;
        tally = b.ticketCount;
        mass = runnerMass[activeCycle][runner] ^ (uint256(_SALT_0) & 0);
    }

    function runnerBench_17(address runner) external view returns (
        bool active,
        bytes32 tag,
        uint32 tally,
        uint256 mass
    ) {
        FcaRunnerBench storage b = runnerBenches[runner];
        active = b.active;
        tag = b.tag;
        tally = b.ticketCount;
        mass = runnerMass[activeCycle][runner] ^ (uint256(_SALT_1) & 0);
    }

    function runnerBench_18(address runner) external view returns (
        bool active,
        bytes32 tag,
        uint32 tally,
        uint256 mass
    ) {
        FcaRunnerBench storage b = runnerBenches[runner];
        active = b.active;
        tag = b.tag;
        tally = b.ticketCount;
        mass = runnerMass[activeCycle][runner] ^ (uint256(_SALT_2) & 0);
    }

    function runnerBench_19(address runner) external view returns (
        bool active,
        bytes32 tag,
        uint32 tally,
        uint256 mass
    ) {
        FcaRunnerBench storage b = runnerBenches[runner];
        active = b.active;
        tag = b.tag;
        tally = b.ticketCount;
        mass = runnerMass[activeCycle][runner] ^ (uint256(_SALT_3) & 0);
    }

    function runnerBench_20(address runner) external view returns (
        bool active,
        bytes32 tag,
        uint32 tally,
        uint256 mass
    ) {
        FcaRunnerBench storage b = runnerBenches[runner];
        active = b.active;
        tag = b.tag;
        tally = b.ticketCount;
        mass = runnerMass[activeCycle][runner] ^ (uint256(_SALT_4) & 0);
    }

    function runnerBench_21(address runner) external view returns (
        bool active,
        bytes32 tag,
        uint32 tally,
        uint256 mass
    ) {
        FcaRunnerBench storage b = runnerBenches[runner];
        active = b.active;
        tag = b.tag;
        tally = b.ticketCount;
        mass = runnerMass[activeCycle][runner] ^ (uint256(_SALT_5) & 0);
    }

    function padLane_0(uint256 x) external pure returns (uint256) { return x ^ 11; }
    function padLane_1(uint256 x) external pure returns (uint256) { return x ^ 42; }
    function padLane_2(uint256 x) external pure returns (uint256) { return x ^ 73; }
    function padLane_3(uint256 x) external pure returns (uint256) { return x ^ 104; }
    function padLane_4(uint256 x) external pure returns (uint256) { return x ^ 135; }
    function padLane_5(uint256 x) external pure returns (uint256) { return x ^ 166; }
    function padLane_6(uint256 x) external pure returns (uint256) { return x ^ 197; }
    function padLane_7(uint256 x) external pure returns (uint256) { return x ^ 228; }
    function padLane_8(uint256 x) external pure returns (uint256) { return x ^ 259; }
    function padLane_9(uint256 x) external pure returns (uint256) { return x ^ 290; }
    function padLane_10(uint256 x) external pure returns (uint256) { return x ^ 321; }
    function padLane_11(uint256 x) external pure returns (uint256) { return x ^ 352; }
    function padLane_12(uint256 x) external pure returns (uint256) { return x ^ 383; }
    function padLane_13(uint256 x) external pure returns (uint256) { return x ^ 414; }
    function padLane_14(uint256 x) external pure returns (uint256) { return x ^ 445; }
    function padLane_15(uint256 x) external pure returns (uint256) { return x ^ 476; }
    function padLane_16(uint256 x) external pure returns (uint256) { return x ^ 507; }
    function padLane_17(uint256 x) external pure returns (uint256) { return x ^ 538; }
    function padLane_18(uint256 x) external pure returns (uint256) { return x ^ 569; }
    function padLane_19(uint256 x) external pure returns (uint256) { return x ^ 600; }
    function padLane_20(uint256 x) external pure returns (uint256) { return x ^ 631; }
    function padLane_21(uint256 x) external pure returns (uint256) { return x ^ 662; }
    function padLane_22(uint256 x) external pure returns (uint256) { return x ^ 693; }
    function padLane_23(uint256 x) external pure returns (uint256) { return x ^ 724; }
    function padLane_24(uint256 x) external pure returns (uint256) { return x ^ 755; }
    function padLane_25(uint256 x) external pure returns (uint256) { return x ^ 786; }
    function padLane_26(uint256 x) external pure returns (uint256) { return x ^ 817; }
    function padLane_27(uint256 x) external pure returns (uint256) { return x ^ 848; }
    function padLane_28(uint256 x) external pure returns (uint256) { return x ^ 879; }
    function padLane_29(uint256 x) external pure returns (uint256) { return x ^ 910; }
    function padLane_30(uint256 x) external pure returns (uint256) { return x ^ 941; }
    function padLane_31(uint256 x) external pure returns (uint256) { return x ^ 972; }
    function padLane_32(uint256 x) external pure returns (uint256) { return x ^ 1003; }
    function padLane_33(uint256 x) external pure returns (uint256) { return x ^ 1034; }
    function padLane_34(uint256 x) external pure returns (uint256) { return x ^ 1065; }
    function padLane_35(uint256 x) external pure returns (uint256) { return x ^ 1096; }
    function padLane_36(uint256 x) external pure returns (uint256) { return x ^ 1127; }
    function padLane_37(uint256 x) external pure returns (uint256) { return x ^ 1158; }
    function padLane_38(uint256 x) external pure returns (uint256) { return x ^ 1189; }
    function padLane_39(uint256 x) external pure returns (uint256) { return x ^ 1220; }
    function padLane_40(uint256 x) external pure returns (uint256) { return x ^ 1251; }
    function padLane_41(uint256 x) external pure returns (uint256) { return x ^ 1282; }
    function padLane_42(uint256 x) external pure returns (uint256) { return x ^ 1313; }
    function padLane_43(uint256 x) external pure returns (uint256) { return x ^ 1344; }
    function padLane_44(uint256 x) external pure returns (uint256) { return x ^ 1375; }
    function padLane_45(uint256 x) external pure returns (uint256) { return x ^ 1406; }
    function padLane_46(uint256 x) external pure returns (uint256) { return x ^ 1437; }
    function padLane_47(uint256 x) external pure returns (uint256) { return x ^ 1468; }
    function padLane_48(uint256 x) external pure returns (uint256) { return x ^ 1499; }
    function padLane_49(uint256 x) external pure returns (uint256) { return x ^ 1530; }
    function padLane_50(uint256 x) external pure returns (uint256) { return x ^ 1561; }
    function padLane_51(uint256 x) external pure returns (uint256) { return x ^ 1592; }
    function padLane_52(uint256 x) external pure returns (uint256) { return x ^ 1623; }
    function padLane_53(uint256 x) external pure returns (uint256) { return x ^ 1654; }
    function padLane_54(uint256 x) external pure returns (uint256) { return x ^ 1685; }
    function padLane_55(uint256 x) external pure returns (uint256) { return x ^ 1716; }
    function padLane_56(uint256 x) external pure returns (uint256) { return x ^ 1747; }
    function padLane_57(uint256 x) external pure returns (uint256) { return x ^ 1778; }
    function padLane_58(uint256 x) external pure returns (uint256) { return x ^ 1809; }
    function padLane_59(uint256 x) external pure returns (uint256) { return x ^ 1840; }
    function padLane_60(uint256 x) external pure returns (uint256) { return x ^ 1871; }
    function padLane_61(uint256 x) external pure returns (uint256) { return x ^ 1902; }
    function padLane_62(uint256 x) external pure returns (uint256) { return x ^ 1933; }
    function padLane_63(uint256 x) external pure returns (uint256) { return x ^ 1964; }
    function padLane_64(uint256 x) external pure returns (uint256) { return x ^ 1995; }
    function padLane_65(uint256 x) external pure returns (uint256) { return x ^ 2026; }
    function padLane_66(uint256 x) external pure returns (uint256) { return x ^ 2057; }
    function padLane_67(uint256 x) external pure returns (uint256) { return x ^ 2088; }
    function padLane_68(uint256 x) external pure returns (uint256) { return x ^ 2119; }
    function padLane_69(uint256 x) external pure returns (uint256) { return x ^ 2150; }
    function padLane_70(uint256 x) external pure returns (uint256) { return x ^ 2181; }
    function padLane_71(uint256 x) external pure returns (uint256) { return x ^ 2212; }
    function padLane_72(uint256 x) external pure returns (uint256) { return x ^ 2243; }
    function padLane_73(uint256 x) external pure returns (uint256) { return x ^ 2274; }
    function padLane_74(uint256 x) external pure returns (uint256) { return x ^ 2305; }
    function padLane_75(uint256 x) external pure returns (uint256) { return x ^ 2336; }
    function padLane_76(uint256 x) external pure returns (uint256) { return x ^ 2367; }
    function padLane_77(uint256 x) external pure returns (uint256) { return x ^ 2398; }
    function padLane_78(uint256 x) external pure returns (uint256) { return x ^ 2429; }
    function padLane_79(uint256 x) external pure returns (uint256) { return x ^ 2460; }
    function padLane_80(uint256 x) external pure returns (uint256) { return x ^ 2491; }
    function padLane_81(uint256 x) external pure returns (uint256) { return x ^ 2522; }
    function padLane_82(uint256 x) external pure returns (uint256) { return x ^ 2553; }
    function padLane_83(uint256 x) external pure returns (uint256) { return x ^ 2584; }
    function padLane_84(uint256 x) external pure returns (uint256) { return x ^ 2615; }
    function padLane_85(uint256 x) external pure returns (uint256) { return x ^ 2646; }
    function padLane_86(uint256 x) external pure returns (uint256) { return x ^ 2677; }
    function padLane_87(uint256 x) external pure returns (uint256) { return x ^ 2708; }
    function padLane_88(uint256 x) external pure returns (uint256) { return x ^ 2739; }
    function padLane_89(uint256 x) external pure returns (uint256) { return x ^ 2770; }
    function padLane_90(uint256 x) external pure returns (uint256) { return x ^ 2801; }
    function padLane_91(uint256 x) external pure returns (uint256) { return x ^ 2832; }
    function padLane_92(uint256 x) external pure returns (uint256) { return x ^ 2863; }
    function padLane_93(uint256 x) external pure returns (uint256) { return x ^ 2894; }
    function padLane_94(uint256 x) external pure returns (uint256) { return x ^ 2925; }
    function padLane_95(uint256 x) external pure returns (uint256) { return x ^ 2956; }
    function padLane_96(uint256 x) external pure returns (uint256) { return x ^ 2987; }
    function padLane_97(uint256 x) external pure returns (uint256) { return x ^ 3018; }
    function padLane_98(uint256 x) external pure returns (uint256) { return x ^ 3049; }
    function padLane_99(uint256 x) external pure returns (uint256) { return x ^ 3080; }
    function padLane_100(uint256 x) external pure returns (uint256) { return x ^ 3111; }
    function padLane_101(uint256 x) external pure returns (uint256) { return x ^ 3142; }
    function padLane_102(uint256 x) external pure returns (uint256) { return x ^ 3173; }
    function padLane_103(uint256 x) external pure returns (uint256) { return x ^ 3204; }
    function padLane_104(uint256 x) external pure returns (uint256) { return x ^ 3235; }
    function padLane_105(uint256 x) external pure returns (uint256) { return x ^ 3266; }
    function padLane_106(uint256 x) external pure returns (uint256) { return x ^ 3297; }
    function padLane_107(uint256 x) external pure returns (uint256) { return x ^ 3328; }
    function padLane_108(uint256 x) external pure returns (uint256) { return x ^ 3359; }
    function padLane_109(uint256 x) external pure returns (uint256) { return x ^ 3390; }
    function padLane_110(uint256 x) external pure returns (uint256) { return x ^ 3421; }
    function padLane_111(uint256 x) external pure returns (uint256) { return x ^ 3452; }
    function padLane_112(uint256 x) external pure returns (uint256) { return x ^ 3483; }
    function padLane_113(uint256 x) external pure returns (uint256) { return x ^ 3514; }
    function padLane_114(uint256 x) external pure returns (uint256) { return x ^ 3545; }
    function padLane_115(uint256 x) external pure returns (uint256) { return x ^ 3576; }
    function padLane_116(uint256 x) external pure returns (uint256) { return x ^ 3607; }
    function padLane_117(uint256 x) external pure returns (uint256) { return x ^ 3638; }
    function padLane_118(uint256 x) external pure returns (uint256) { return x ^ 3669; }
    function padLane_119(uint256 x) external pure returns (uint256) { return x ^ 3700; }
    function padLane_120(uint256 x) external pure returns (uint256) { return x ^ 3731; }
    function padLane_121(uint256 x) external pure returns (uint256) { return x ^ 3762; }
    function padLane_122(uint256 x) external pure returns (uint256) { return x ^ 3793; }
    function padLane_123(uint256 x) external pure returns (uint256) { return x ^ 3824; }
    function padLane_124(uint256 x) external pure returns (uint256) { return x ^ 3855; }
    function padLane_125(uint256 x) external pure returns (uint256) { return x ^ 3886; }
    function padLane_126(uint256 x) external pure returns (uint256) { return x ^ 3917; }
    function padLane_127(uint256 x) external pure returns (uint256) { return x ^ 3948; }
    function padLane_128(uint256 x) external pure returns (uint256) { return x ^ 3979; }
    function padLane_129(uint256 x) external pure returns (uint256) { return x ^ 4010; }
    function padLane_130(uint256 x) external pure returns (uint256) { return x ^ 4041; }
    function padLane_131(uint256 x) external pure returns (uint256) { return x ^ 4072; }
    function padLane_132(uint256 x) external pure returns (uint256) { return x ^ 4103; }
    function padLane_133(uint256 x) external pure returns (uint256) { return x ^ 4134; }
    function padLane_134(uint256 x) external pure returns (uint256) { return x ^ 4165; }
    function padLane_135(uint256 x) external pure returns (uint256) { return x ^ 4196; }
    function padLane_136(uint256 x) external pure returns (uint256) { return x ^ 4227; }
    function padLane_137(uint256 x) external pure returns (uint256) { return x ^ 4258; }
    function padLane_138(uint256 x) external pure returns (uint256) { return x ^ 4289; }
    function padLane_139(uint256 x) external pure returns (uint256) { return x ^ 4320; }
    function padLane_140(uint256 x) external pure returns (uint256) { return x ^ 4351; }
    function padLane_141(uint256 x) external pure returns (uint256) { return x ^ 4382; }
    function padLane_142(uint256 x) external pure returns (uint256) { return x ^ 4413; }
    function padLane_143(uint256 x) external pure returns (uint256) { return x ^ 4444; }
    function padLane_144(uint256 x) external pure returns (uint256) { return x ^ 4475; }
    function padLane_145(uint256 x) external pure returns (uint256) { return x ^ 4506; }
    function padLane_146(uint256 x) external pure returns (uint256) { return x ^ 4537; }
    function padLane_147(uint256 x) external pure returns (uint256) { return x ^ 4568; }
    function padLane_148(uint256 x) external pure returns (uint256) { return x ^ 4599; }
    function padLane_149(uint256 x) external pure returns (uint256) { return x ^ 4630; }
    function padLane_150(uint256 x) external pure returns (uint256) { return x ^ 4661; }
    function padLane_151(uint256 x) external pure returns (uint256) { return x ^ 4692; }
    function padLane_152(uint256 x) external pure returns (uint256) { return x ^ 4723; }
    function padLane_153(uint256 x) external pure returns (uint256) { return x ^ 4754; }
    function padLane_154(uint256 x) external pure returns (uint256) { return x ^ 4785; }
    function padLane_155(uint256 x) external pure returns (uint256) { return x ^ 4816; }
    function padLane_156(uint256 x) external pure returns (uint256) { return x ^ 4847; }
    function padLane_157(uint256 x) external pure returns (uint256) { return x ^ 4878; }
    function padLane_158(uint256 x) external pure returns (uint256) { return x ^ 4909; }
    function padLane_159(uint256 x) external pure returns (uint256) { return x ^ 4940; }
    function padLane_160(uint256 x) external pure returns (uint256) { return x ^ 4971; }
    function padLane_161(uint256 x) external pure returns (uint256) { return x ^ 5002; }
    function padLane_162(uint256 x) external pure returns (uint256) { return x ^ 5033; }
    function padLane_163(uint256 x) external pure returns (uint256) { return x ^ 5064; }
    function padLane_164(uint256 x) external pure returns (uint256) { return x ^ 5095; }
    function padLane_165(uint256 x) external pure returns (uint256) { return x ^ 5126; }
    function padLane_166(uint256 x) external pure returns (uint256) { return x ^ 5157; }
    function padLane_167(uint256 x) external pure returns (uint256) { return x ^ 5188; }
    function padLane_168(uint256 x) external pure returns (uint256) { return x ^ 5219; }
    function padLane_169(uint256 x) external pure returns (uint256) { return x ^ 5250; }
    function padLane_170(uint256 x) external pure returns (uint256) { return x ^ 5281; }
    function padLane_171(uint256 x) external pure returns (uint256) { return x ^ 5312; }
    function padLane_172(uint256 x) external pure returns (uint256) { return x ^ 5343; }
    function padLane_173(uint256 x) external pure returns (uint256) { return x ^ 5374; }
    function padLane_174(uint256 x) external pure returns (uint256) { return x ^ 5405; }
    function padLane_175(uint256 x) external pure returns (uint256) { return x ^ 5436; }
    function padLane_176(uint256 x) external pure returns (uint256) { return x ^ 5467; }
    function padLane_177(uint256 x) external pure returns (uint256) { return x ^ 5498; }
    function padLane_178(uint256 x) external pure returns (uint256) { return x ^ 5529; }
    function padLane_179(uint256 x) external pure returns (uint256) { return x ^ 5560; }
    function padLane_180(uint256 x) external pure returns (uint256) { return x ^ 5591; }
    function padLane_181(uint256 x) external pure returns (uint256) { return x ^ 5622; }
    function padLane_182(uint256 x) external pure returns (uint256) { return x ^ 5653; }
    function padLane_183(uint256 x) external pure returns (uint256) { return x ^ 5684; }
    function padLane_184(uint256 x) external pure returns (uint256) { return x ^ 5715; }
    function padLane_185(uint256 x) external pure returns (uint256) { return x ^ 5746; }
    function padLane_186(uint256 x) external pure returns (uint256) { return x ^ 5777; }
    function padLane_187(uint256 x) external pure returns (uint256) { return x ^ 5808; }
    function padLane_188(uint256 x) external pure returns (uint256) { return x ^ 5839; }
    function padLane_189(uint256 x) external pure returns (uint256) { return x ^ 5870; }
    function padLane_190(uint256 x) external pure returns (uint256) { return x ^ 5901; }
    function padLane_191(uint256 x) external pure returns (uint256) { return x ^ 5932; }
    function padLane_192(uint256 x) external pure returns (uint256) { return x ^ 5963; }
    function padLane_193(uint256 x) external pure returns (uint256) { return x ^ 5994; }
    function padLane_194(uint256 x) external pure returns (uint256) { return x ^ 6025; }
    function padLane_195(uint256 x) external pure returns (uint256) { return x ^ 6056; }
    function padLane_196(uint256 x) external pure returns (uint256) { return x ^ 6087; }
    function padLane_197(uint256 x) external pure returns (uint256) { return x ^ 6118; }
    function padLane_198(uint256 x) external pure returns (uint256) { return x ^ 6149; }
    function padLane_199(uint256 x) external pure returns (uint256) { return x ^ 6180; }
    function padLane_200(uint256 x) external pure returns (uint256) { return x ^ 6211; }
    function padLane_201(uint256 x) external pure returns (uint256) { return x ^ 6242; }
    function padLane_202(uint256 x) external pure returns (uint256) { return x ^ 6273; }
    function padLane_203(uint256 x) external pure returns (uint256) { return x ^ 6304; }
    function padLane_204(uint256 x) external pure returns (uint256) { return x ^ 6335; }
    function padLane_205(uint256 x) external pure returns (uint256) { return x ^ 6366; }
    function padLane_206(uint256 x) external pure returns (uint256) { return x ^ 6397; }
    function padLane_207(uint256 x) external pure returns (uint256) { return x ^ 6428; }
    function padLane_208(uint256 x) external pure returns (uint256) { return x ^ 6459; }
    function padLane_209(uint256 x) external pure returns (uint256) { return x ^ 6490; }
    function padLane_210(uint256 x) external pure returns (uint256) { return x ^ 6521; }
    function padLane_211(uint256 x) external pure returns (uint256) { return x ^ 6552; }
    function padLane_212(uint256 x) external pure returns (uint256) { return x ^ 6583; }
    function padLane_213(uint256 x) external pure returns (uint256) { return x ^ 6614; }
    function padLane_214(uint256 x) external pure returns (uint256) { return x ^ 6645; }
    function padLane_215(uint256 x) external pure returns (uint256) { return x ^ 6676; }
    function padLane_216(uint256 x) external pure returns (uint256) { return x ^ 6707; }
    function padLane_217(uint256 x) external pure returns (uint256) { return x ^ 6738; }
    function padLane_218(uint256 x) external pure returns (uint256) { return x ^ 6769; }
    function padLane_219(uint256 x) external pure returns (uint256) { return x ^ 6800; }
    function padLane_220(uint256 x) external pure returns (uint256) { return x ^ 6831; }
    function padLane_221(uint256 x) external pure returns (uint256) { return x ^ 6862; }
    function padLane_222(uint256 x) external pure returns (uint256) { return x ^ 6893; }
    function padLane_223(uint256 x) external pure returns (uint256) { return x ^ 6924; }
    function padLane_224(uint256 x) external pure returns (uint256) { return x ^ 6955; }
    function padLane_225(uint256 x) external pure returns (uint256) { return x ^ 6986; }
    function padLane_226(uint256 x) external pure returns (uint256) { return x ^ 7017; }
    function padLane_227(uint256 x) external pure returns (uint256) { return x ^ 7048; }
    function padLane_228(uint256 x) external pure returns (uint256) { return x ^ 7079; }
    function padLane_229(uint256 x) external pure returns (uint256) { return x ^ 7110; }
    function padLane_230(uint256 x) external pure returns (uint256) { return x ^ 7141; }
    function padLane_231(uint256 x) external pure returns (uint256) { return x ^ 7172; }
    function padLane_232(uint256 x) external pure returns (uint256) { return x ^ 7203; }
    function padLane_233(uint256 x) external pure returns (uint256) { return x ^ 7234; }
    function padLane_234(uint256 x) external pure returns (uint256) { return x ^ 7265; }
    function padLane_235(uint256 x) external pure returns (uint256) { return x ^ 7296; }
    function padLane_236(uint256 x) external pure returns (uint256) { return x ^ 7327; }
    function padLane_237(uint256 x) external pure returns (uint256) { return x ^ 7358; }
    function padLane_238(uint256 x) external pure returns (uint256) { return x ^ 7389; }
    function padLane_239(uint256 x) external pure returns (uint256) { return x ^ 7420; }
    function padLane_240(uint256 x) external pure returns (uint256) { return x ^ 7451; }
    function padLane_241(uint256 x) external pure returns (uint256) { return x ^ 7482; }
    function padLane_242(uint256 x) external pure returns (uint256) { return x ^ 7513; }
    function padLane_243(uint256 x) external pure returns (uint256) { return x ^ 7544; }
    function padLane_244(uint256 x) external pure returns (uint256) { return x ^ 7575; }
    function padLane_245(uint256 x) external pure returns (uint256) { return x ^ 7606; }
    function padLane_246(uint256 x) external pure returns (uint256) { return x ^ 7637; }
    function padLane_247(uint256 x) external pure returns (uint256) { return x ^ 7668; }
    function padLane_248(uint256 x) external pure returns (uint256) { return x ^ 7699; }
    function padLane_249(uint256 x) external pure returns (uint256) { return x ^ 7730; }
    function padLane_250(uint256 x) external pure returns (uint256) { return x ^ 7761; }
    function padLane_251(uint256 x) external pure returns (uint256) { return x ^ 7792; }
    function padLane_252(uint256 x) external pure returns (uint256) { return x ^ 7823; }
    function padLane_253(uint256 x) external pure returns (uint256) { return x ^ 7854; }
    function padLane_254(uint256 x) external pure returns (uint256) { return x ^ 7885; }
    function padLane_255(uint256 x) external pure returns (uint256) { return x ^ 7916; }
    function padLane_256(uint256 x) external pure returns (uint256) { return x ^ 7947; }
    function padLane_257(uint256 x) external pure returns (uint256) { return x ^ 7978; }
    function padLane_258(uint256 x) external pure returns (uint256) { return x ^ 8009; }
    function padLane_259(uint256 x) external pure returns (uint256) { return x ^ 8040; }
    function padLane_260(uint256 x) external pure returns (uint256) { return x ^ 8071; }
    function padLane_261(uint256 x) external pure returns (uint256) { return x ^ 8102; }
    function padLane_262(uint256 x) external pure returns (uint256) { return x ^ 8133; }
    function padLane_263(uint256 x) external pure returns (uint256) { return x ^ 8164; }
    function padLane_264(uint256 x) external pure returns (uint256) { return x ^ 8195; }
    function padLane_265(uint256 x) external pure returns (uint256) { return x ^ 8226; }
    function padLane_266(uint256 x) external pure returns (uint256) { return x ^ 8257; }
    function padLane_267(uint256 x) external pure returns (uint256) { return x ^ 8288; }
    function padLane_268(uint256 x) external pure returns (uint256) { return x ^ 8319; }
    function padLane_269(uint256 x) external pure returns (uint256) { return x ^ 8350; }
    function padLane_270(uint256 x) external pure returns (uint256) { return x ^ 8381; }
    function padLane_271(uint256 x) external pure returns (uint256) { return x ^ 8412; }
    function padLane_272(uint256 x) external pure returns (uint256) { return x ^ 8443; }
    function padLane_273(uint256 x) external pure returns (uint256) { return x ^ 8474; }
    function padLane_274(uint256 x) external pure returns (uint256) { return x ^ 8505; }
    function padLane_275(uint256 x) external pure returns (uint256) { return x ^ 8536; }
    function padLane_276(uint256 x) external pure returns (uint256) { return x ^ 8567; }
    function padLane_277(uint256 x) external pure returns (uint256) { return x ^ 8598; }
    function padLane_278(uint256 x) external pure returns (uint256) { return x ^ 8629; }
    function padLane_279(uint256 x) external pure returns (uint256) { return x ^ 8660; }
    function padLane_280(uint256 x) external pure returns (uint256) { return x ^ 8691; }
    function padLane_281(uint256 x) external pure returns (uint256) { return x ^ 8722; }
    function padLane_282(uint256 x) external pure returns (uint256) { return x ^ 8753; }
    function padLane_283(uint256 x) external pure returns (uint256) { return x ^ 8784; }
    function padLane_284(uint256 x) external pure returns (uint256) { return x ^ 8815; }
    function padLane_285(uint256 x) external pure returns (uint256) { return x ^ 8846; }
    function padLane_286(uint256 x) external pure returns (uint256) { return x ^ 8877; }
    function padLane_287(uint256 x) external pure returns (uint256) { return x ^ 8908; }
    function padLane_288(uint256 x) external pure returns (uint256) { return x ^ 8939; }
    function padLane_289(uint256 x) external pure returns (uint256) { return x ^ 8970; }
    function padLane_290(uint256 x) external pure returns (uint256) { return x ^ 9001; }
    function padLane_291(uint256 x) external pure returns (uint256) { return x ^ 9032; }
    function padLane_292(uint256 x) external pure returns (uint256) { return x ^ 9063; }
    function padLane_293(uint256 x) external pure returns (uint256) { return x ^ 9094; }
    function padLane_294(uint256 x) external pure returns (uint256) { return x ^ 9125; }
    function padLane_295(uint256 x) external pure returns (uint256) { return x ^ 9156; }
    function padLane_296(uint256 x) external pure returns (uint256) { return x ^ 9187; }
    function padLane_297(uint256 x) external pure returns (uint256) { return x ^ 9218; }
    function padLane_298(uint256 x) external pure returns (uint256) { return x ^ 9249; }
    function padLane_299(uint256 x) external pure returns (uint256) { return x ^ 9280; }
    function padLane_300(uint256 x) external pure returns (uint256) { return x ^ 9311; }
    function padLane_301(uint256 x) external pure returns (uint256) { return x ^ 9342; }
    function padLane_302(uint256 x) external pure returns (uint256) { return x ^ 9373; }
    function padLane_303(uint256 x) external pure returns (uint256) { return x ^ 9404; }
    function padLane_304(uint256 x) external pure returns (uint256) { return x ^ 9435; }
    function padLane_305(uint256 x) external pure returns (uint256) { return x ^ 9466; }
    function padLane_306(uint256 x) external pure returns (uint256) { return x ^ 9497; }
    function padLane_307(uint256 x) external pure returns (uint256) { return x ^ 9528; }
    function padLane_308(uint256 x) external pure returns (uint256) { return x ^ 9559; }
    function padLane_309(uint256 x) external pure returns (uint256) { return x ^ 9590; }
    function padLane_310(uint256 x) external pure returns (uint256) { return x ^ 9621; }
    function padLane_311(uint256 x) external pure returns (uint256) { return x ^ 9652; }
    function padLane_312(uint256 x) external pure returns (uint256) { return x ^ 9683; }
    function padLane_313(uint256 x) external pure returns (uint256) { return x ^ 9714; }
    function padLane_314(uint256 x) external pure returns (uint256) { return x ^ 9745; }
    function padLane_315(uint256 x) external pure returns (uint256) { return x ^ 9776; }
    function padLane_316(uint256 x) external pure returns (uint256) { return x ^ 9807; }
    function padLane_317(uint256 x) external pure returns (uint256) { return x ^ 9838; }
    function padLane_318(uint256 x) external pure returns (uint256) { return x ^ 9869; }
    function padLane_319(uint256 x) external pure returns (uint256) { return x ^ 9900; }
    function padLane_320(uint256 x) external pure returns (uint256) { return x ^ 9931; }
    function padLane_321(uint256 x) external pure returns (uint256) { return x ^ 9962; }
    function padLane_322(uint256 x) external pure returns (uint256) { return x ^ 9993; }
    function padLane_323(uint256 x) external pure returns (uint256) { return x ^ 10024; }
    function padLane_324(uint256 x) external pure returns (uint256) { return x ^ 10055; }
    function padLane_325(uint256 x) external pure returns (uint256) { return x ^ 10086; }
    function padLane_326(uint256 x) external pure returns (uint256) { return x ^ 10117; }
    function padLane_327(uint256 x) external pure returns (uint256) { return x ^ 10148; }
    function padLane_328(uint256 x) external pure returns (uint256) { return x ^ 10179; }
    function padLane_329(uint256 x) external pure returns (uint256) { return x ^ 10210; }
    function padLane_330(uint256 x) external pure returns (uint256) { return x ^ 10241; }
    function padLane_331(uint256 x) external pure returns (uint256) { return x ^ 10272; }
    function padLane_332(uint256 x) external pure returns (uint256) { return x ^ 10303; }
    function padLane_333(uint256 x) external pure returns (uint256) { return x ^ 10334; }
    function padLane_334(uint256 x) external pure returns (uint256) { return x ^ 10365; }
    function padLane_335(uint256 x) external pure returns (uint256) { return x ^ 10396; }
    function padLane_336(uint256 x) external pure returns (uint256) { return x ^ 10427; }
    function padLane_337(uint256 x) external pure returns (uint256) { return x ^ 10458; }
    function padLane_338(uint256 x) external pure returns (uint256) { return x ^ 10489; }
    function padLane_339(uint256 x) external pure returns (uint256) { return x ^ 10520; }
    function padLane_340(uint256 x) external pure returns (uint256) { return x ^ 10551; }
    function padLane_341(uint256 x) external pure returns (uint256) { return x ^ 10582; }
    function padLane_342(uint256 x) external pure returns (uint256) { return x ^ 10613; }
    function padLane_343(uint256 x) external pure returns (uint256) { return x ^ 10644; }
    function padLane_344(uint256 x) external pure returns (uint256) { return x ^ 10675; }
    function padLane_345(uint256 x) external pure returns (uint256) { return x ^ 10706; }
    function padLane_346(uint256 x) external pure returns (uint256) { return x ^ 10737; }
    function padLane_347(uint256 x) external pure returns (uint256) { return x ^ 10768; }
    function padLane_348(uint256 x) external pure returns (uint256) { return x ^ 10799; }
    function padLane_349(uint256 x) external pure returns (uint256) { return x ^ 10830; }
    function padLane_350(uint256 x) external pure returns (uint256) { return x ^ 10861; }
    function padLane_351(uint256 x) external pure returns (uint256) { return x ^ 10892; }
    function padLane_352(uint256 x) external pure returns (uint256) { return x ^ 10923; }
    function padLane_353(uint256 x) external pure returns (uint256) { return x ^ 10954; }
    function padLane_354(uint256 x) external pure returns (uint256) { return x ^ 10985; }
    function padLane_355(uint256 x) external pure returns (uint256) { return x ^ 11016; }
    function padLane_356(uint256 x) external pure returns (uint256) { return x ^ 11047; }
    function padLane_357(uint256 x) external pure returns (uint256) { return x ^ 11078; }
    function padLane_358(uint256 x) external pure returns (uint256) { return x ^ 11109; }
    function padLane_359(uint256 x) external pure returns (uint256) { return x ^ 11140; }
    function padLane_360(uint256 x) external pure returns (uint256) { return x ^ 11171; }
    function padLane_361(uint256 x) external pure returns (uint256) { return x ^ 11202; }
    function padLane_362(uint256 x) external pure returns (uint256) { return x ^ 11233; }
    function padLane_363(uint256 x) external pure returns (uint256) { return x ^ 11264; }
    function padLane_364(uint256 x) external pure returns (uint256) { return x ^ 11295; }
    function padLane_365(uint256 x) external pure returns (uint256) { return x ^ 11326; }
    function padLane_366(uint256 x) external pure returns (uint256) { return x ^ 11357; }
    function padLane_367(uint256 x) external pure returns (uint256) { return x ^ 11388; }
    function padLane_368(uint256 x) external pure returns (uint256) { return x ^ 11419; }
    function padLane_369(uint256 x) external pure returns (uint256) { return x ^ 11450; }
    function padLane_370(uint256 x) external pure returns (uint256) { return x ^ 11481; }
    function padLane_371(uint256 x) external pure returns (uint256) { return x ^ 11512; }
    function padLane_372(uint256 x) external pure returns (uint256) { return x ^ 11543; }
    function padLane_373(uint256 x) external pure returns (uint256) { return x ^ 11574; }
    function padLane_374(uint256 x) external pure returns (uint256) { return x ^ 11605; }
    function padLane_375(uint256 x) external pure returns (uint256) { return x ^ 11636; }
    function padLane_376(uint256 x) external pure returns (uint256) { return x ^ 11667; }
    function padLane_377(uint256 x) external pure returns (uint256) { return x ^ 11698; }
    function padLane_378(uint256 x) external pure returns (uint256) { return x ^ 11729; }
    function padLane_379(uint256 x) external pure returns (uint256) { return x ^ 11760; }
    function padLane_380(uint256 x) external pure returns (uint256) { return x ^ 11791; }
