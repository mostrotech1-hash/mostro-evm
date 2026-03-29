// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @notice Reentrancy protection for Diamond facets using a dedicated storage slot.
 * @dev OpenZeppelin `ReentrancyGuard` stores state at slot 0 of the facet layout; multiple
 *      facets delegatecalled into the same proxy would collide. This uses an explicit slot.
 */
abstract contract DiamondReentrancyGuard {
    error ReentrancyGuardReentrantCall();

    bytes32 private constant _STATUS_SLOT =
        keccak256("mostro.storage.reentrancy.vault_deployer_facet");

    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    modifier nonReentrant() {
        if (_status() == _ENTERED) revert ReentrancyGuardReentrantCall();
        _setStatus(_ENTERED);
        _;
        _setStatus(_NOT_ENTERED);
    }

    function _status() private view returns (uint256 s) {
        bytes32 slot = _STATUS_SLOT;
        assembly {
            s := sload(slot)
        }
        if (s == 0) return _NOT_ENTERED;
        return s;
    }

    function _setStatus(uint256 value) private {
        bytes32 slot = _STATUS_SLOT;
        assembly {
            sstore(slot, value)
        }
    }
}
