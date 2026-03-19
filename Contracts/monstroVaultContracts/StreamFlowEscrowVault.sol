// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseVault} from "./BaseVault.sol";

contract StreamFlowEscrowVault is BaseVault {
    string public constant VAULT_NAME = "StreamFlowEscrowVault";

    uint256 public constant TOTAL_PERIODS = 4;
    uint256 public constant PERIOD_DURATION = 180 days;

    uint256 public scheduleStart;
    address public artistUnvestedVault;
    bool public scheduleInitialised;

    mapping(uint256 => bool) public periodReleased;

    event ScheduleInitialised(
        uint256 indexed startTime,
        address indexed artistUnvestedVault,
        uint256 period1UnlocksAt,
        uint256 period2UnlocksAt,
        uint256 period3UnlocksAt,
        uint256 period4UnlocksAt
    );

    event PeriodReleased(
        uint256 indexed period,
        uint256 amount,
        uint256 unlockedAt,
        uint256 releasedAt
    );

    error ScheduleNotInitialised();
    error ScheduleAlreadyInitialised();
    error InvalidPeriod(uint256 period);
    error PeriodAlreadyReleased(uint256 period);
    error PeriodNotYetUnlocked(
        uint256 period,
        uint256 unlocksAt,
        uint256 currentTime
    );

    constructor(
        address _multisig,
        address _token,
        address _contract
    ) BaseVault(_multisig, _token, _contract) {}

    function startSchedule(
        address _artistUnvestedVault,
        uint256 _startTime
    ) external onlyMultisig {
        if (scheduleInitialised) revert ScheduleAlreadyInitialised();
        if (_artistUnvestedVault == address(0)) revert ZeroAddress();

        require(_startTime >= block.timestamp, "Start time is in the past");

        scheduleInitialised = true;
        scheduleStart = _startTime;
        artistUnvestedVault = _artistUnvestedVault;

        emit ScheduleInitialised(
            _startTime,
            _artistUnvestedVault,
            _startTime + (1 * PERIOD_DURATION),
            _startTime + (2 * PERIOD_DURATION),
            _startTime + (3 * PERIOD_DURATION),
            _startTime + (4 * PERIOD_DURATION)
        );
    }

    function releasePeriod(
        uint256 period,
        uint256 _amount
    ) external onlyMultisig {
        if (!scheduleInitialised) revert ScheduleNotInitialised();
        if (period == 0 || period > TOTAL_PERIODS) revert InvalidPeriod(period);
        if (periodReleased[period]) revert PeriodAlreadyReleased(period);

        uint256 unlocksAt = scheduleStart + (period * PERIOD_DURATION);

        if (block.timestamp < unlocksAt) {
            revert PeriodNotYetUnlocked(period, unlocksAt, block.timestamp);
        }

        periodReleased[period] = true;

        _release(artistUnvestedVault, _amount);

        emit PeriodReleased(period, _amount, unlocksAt, block.timestamp);
    }

    function periodUnlockTime(uint256 period) external view returns (uint256) {
        if (!scheduleInitialised) revert ScheduleNotInitialised();
        if (period == 0 || period > TOTAL_PERIODS) revert InvalidPeriod(period);

        return scheduleStart + (period * PERIOD_DURATION);
    }

    function releasedPeriodCount() external view returns (uint256 count) {
        for (uint256 i = 1; i <= TOTAL_PERIODS; i++) {
            if (periodReleased[i]) count++;
        }
    }

    function depositInStreamFlowVault(
        address from,
        uint256 amount
    ) external onlyContract {
        _deposit(from, amount);
    }
}
