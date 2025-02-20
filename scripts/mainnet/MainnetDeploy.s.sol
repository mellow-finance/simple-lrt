// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../src/utils/WhitelistedEthWrapper.sol";
import "./MultiVaultDeployScript.sol";
import "forge-std/Script.sol";

contract Deploy is Script {
    // // actors
    // address admin;
    // address proxyAdmin;
    // address curator;
    // // external contracts
    // address symbioticVault;
    // address depositWrapper;
    // address asset;
    // address defaultCollateral;
    // // vault setup
    // uint256 limit;
    // bool depositPause;
    // bool withdrawalPause;
    // string name;
    // string symbol;
    // // strategy setup
    // uint64 minRatioD18;
    // uint64 maxRatioD18;
    // // salt
    // bytes32 salt;

    address public constant VAULT_ADMIN_MULTISIG = address(0);
    address public constant VAULT_PROXY_ADMIN_MULTISIG = address(0);

    address public constant WSTETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address public constant STETH = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    function run() external {
        vm.startBroadcast(uint256(bytes32(vm.envBytes("MAINNET_DEPLOYER"))));

        WhitelistedEthWrapper depositWrapper = new WhitelistedEthWrapper(WETH, WSTETH, STETH);

        MultiVaultDeployScript.DeployParams[1] memory deployParams = [
            MultiVaultDeployScript.DeployParams({
                admin: VAULT_ADMIN_MULTISIG,
                proxyAdmin: VAULT_PROXY_ADMIN_MULTISIG,
                curator: address(0),
                symbioticVault: address(0),
                depositWrapper: address(depositWrapper),
                asset: WSTETH,
                defaultCollateral: WSTETH_DEFAULT_COLLATERAL,
                limit: 0,
                depositPause: false,
                withdrawalPause: false,
                name: "x",
                symbol: "y",
                minRatioD18: 0.9 ether,
                maxRatioD18: 0.95 ether,
                salt: bytes32(0)
            })
        ];

        vm.stopBroadcast();
    }
}
