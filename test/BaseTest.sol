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

    address public constant HOLESKY_WSTETH_SYMBIOTIC_COLLATERAL =
        0x23E98253F372Ee29910e22986fe75Bb287b011fC;
    address public constant HOLESKY_WSTETH = 0x8d09a4502Cc8Cf1547aD300E066060D043f6982D;
    address HOLESKY_STETH = 0x3F1c547b21f65e10480dE3ad8E19fAAC46C95034;
    address HOLESKY_WETH = 0x94373a4919B3240D86eA41593D5eBa789FEF3848;

    address public constant MAINNET_WSTETH_SYMBIOTIC_COLLATERAL =
        0xC329400492c6ff2438472D4651Ad17389fCb843a;
    address public constant MAINNET_WSTETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;

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
