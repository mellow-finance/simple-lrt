// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

library Constants {
    address public constant HOLESKY_WSTETH_SYMBIOTIC_COLLATERAL =
        0x23E98253F372Ee29910e22986fe75Bb287b011fC;
    address public constant HOLESKY_WSTETH = 0x8d09a4502Cc8Cf1547aD300E066060D043f6982D;

    address public constant MAINNET_WSTETH_SYMBIOTIC_COLLATERAL =
        0xC329400492c6ff2438472D4651Ad17389fCb843a;

    address public constant MAINNET_WSTETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;

    address public constant HOLESKY_STETH = 0x3F1c547b21f65e10480dE3ad8E19fAAC46C95034;
    address public constant HOLESKY_WETH = 0x94373a4919B3240D86eA41593D5eBa789FEF3848;

    address public constant MAINNET_STETH = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;
    address public constant MAINNET_WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    // chain-specific helper functions

    function WSTETH() internal view returns (address) {
        if (block.chainid == 1) {
            return MAINNET_WSTETH;
        } else if (block.chainid == 17000) {
            return HOLESKY_WSTETH;
        } else {
            revert("Constants: unsupported chain");
        }
    }

    function STETH() internal view returns (address) {
        if (block.chainid == 1) {
            return MAINNET_STETH;
        } else if (block.chainid == 17000) {
            return HOLESKY_STETH;
        } else {
            revert("Constants: unsupported chain");
        }
    }

    function WETH() internal view returns (address) {
        if (block.chainid == 1) {
            return MAINNET_WETH;
        } else if (block.chainid == 17000) {
            return HOLESKY_WETH;
        } else {
            revert("Constants: unsupported chain");
        }
    }

    function WSTETH_SYMBIOTIC_COLLATERAL() internal view returns (address) {
        if (block.chainid == 1) {
            return MAINNET_WSTETH_SYMBIOTIC_COLLATERAL;
        } else if (block.chainid == 17000) {
            return HOLESKY_WSTETH_SYMBIOTIC_COLLATERAL;
        } else {
            revert("Constants: unsupported chain");
        }
    }
}
