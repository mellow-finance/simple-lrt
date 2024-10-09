// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import "./Imports.sol";

abstract contract BaseTest is Test {
    // Roles
    bytes32 public constant SET_FARM_ROLE = keccak256("SET_FARM_ROLE");
    bytes32 public constant REMOVE_FARM_ROLE = keccak256("REMOVE_FARM_ROLE");
    bytes32 public constant SET_LIMIT_ROLE = keccak256("SET_LIMIT_ROLE");
    bytes32 public constant PAUSE_WITHDRAWALS_ROLE = keccak256("PAUSE_WITHDRAWALS_ROLE");
    bytes32 public constant UNPAUSE_WITHDRAWALS_ROLE = keccak256("UNPAUSE_WITHDRAWALS_ROLE");
    bytes32 public constant PAUSE_DEPOSITS_ROLE = keccak256("PAUSE_DEPOSITS_ROLE");
    bytes32 public constant UNPAUSE_DEPOSITS_ROLE = keccak256("UNPAUSE_DEPOSITS_ROLE");
    bytes32 public constant SET_DEPOSIT_WHITELIST_ROLE = keccak256("SET_DEPOSIT_WHITELIST_ROLE");
    bytes32 public constant SET_DEPOSITOR_WHITELIST_STATUS_ROLE =
        keccak256("SET_DEPOSITOR_WHITELIST_STATUS_ROLE");

    // Constants

    uint256 public constant MAX_ERROR = 10 wei;
    uint256 public constant Q96 = 2 ** 96;
    uint256 public constant D18 = 1e18;

    // Helper contracts
    SymbioticHelper public immutable symbioticHelper = new SymbioticHelper();

    // Helper functions
    function shrinkDefaultCollateralLimit(address collateral) public {
        IDefaultCollateral c = IDefaultCollateral(collateral);
        if (c.limit() != c.totalSupply()) {
            vm.store(
                collateral,
                bytes32(uint256(9)), // limit slot
                bytes32(c.totalSupply())
            );
        }
    }

    function testBaseMock() private pure {}
}
