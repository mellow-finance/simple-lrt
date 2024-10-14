// SPDX-License-Identifier: BUSL-1.1
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

    struct SymbioticDeployment {
        address networkRegistry;
        address operatorRegistry;
        address vaultFactory;
        address delegatorFactory;
        address slasherFactory;
        address vaultConfigurator;
        address networkMiddlewareService;
        address operatorVaultOptInService;
        address operatorNetworkOptInService;
    }

    function symbioticDeployment() internal view returns (SymbioticDeployment memory) {
        if (block.chainid == 17000) {
            return SymbioticDeployment({
                networkRegistry: address(0xac5acD8A105C8305fb980734a5AD920b5920106A),
                operatorRegistry: address(0xAdFC41729fF447974cE27DdFa358A0f2096c3F39),
                vaultFactory: address(0x18C659a269a7172eF78BBC19Fe47ad2237Be0590),
                delegatorFactory: address(0xdE2Ad96117b48bd614A9ed8Ff6bcf5D7eB815596),
                slasherFactory: address(0xCeE813788eFD2edD87B2ABE96EAF4789Dbdb3d7D),
                vaultConfigurator: address(0x382e9c6fF81F07A566a8B0A3622dc85c47a891Df),
                networkMiddlewareService: address(0x683F470440964E353b389391CdDDf8df381C282f),
                operatorVaultOptInService: address(0xc105215C23Ed7E45eB6Bf539e52a12c09cD504A5),
                operatorNetworkOptInService: address(0xF5AFc9FA3Ca63a07E529DDbB6eae55C665cCa83E)
            });
        } else if (block.chainid == 1) {
            revert("Not yet implemented");
        } else {
            revert("Unsupported chain");
        }
    }
}
