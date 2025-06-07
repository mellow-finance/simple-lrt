// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "forge-std/Script.sol";

import "../../src/utils/EthWrapper.sol";
import "./DeployScript.sol";
import "./libraries/SymbioticDeployLibrary.sol";

contract Deploy is Script {
    function run() external {
        uint256 deployerPk = uint256(bytes32(vm.envBytes("MAINNET_DEPLOYER")));
        address deployer = vm.addr(deployerPk);
        vm.startBroadcast(deployerPk);

        DeployScript script = DeployScript(address(0x87795a720F7d11Ab16d04f3Bd2a664BCDD20E71d));
        DeployScript.SubvaultParams[] memory subvaults = new DeployScript.SubvaultParams[](1);
        subvaults[0] = DeployScript.SubvaultParams({
            libraryIndex: 0,
            data: SymbioticDeployLibrary(script.deployLibraries(0)).combineOptions(
                0xdCaC890b14121FD5D925E2589017Be68C2B5B324, // wsteth burner
                7 days, // epoch
                3 days, // veto duration
                15 days // burner delay
            ),
            minRatioD18: 0.9 ether,
            maxRatioD18: 0.95 ether
        });

        ( /* uint256 index */ , MultiVault vault) = script.deploy(
            DeployScript.DeployParams({
                config: DeployScript.Config({
                    vaultAdmin: 0x9437B2a8cF3b69D782a61f9814baAbc172f72003,
                    vaultProxyAdmin: 0x81698f87C6482bF1ce9bFcfC0F103C4A0Adf0Af0,
                    curator: 0xD1f59ba974E828dF68cB2592C16b967B637cB4e4,
                    asset: 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0,
                    defaultCollateral: 0xC329400492c6ff2438472D4651Ad17389fCb843a,
                    depositWrapper: 0xfD4a4922d1AFe70000Ce0Ec6806454e78256504e,
                    limit: 400 ether,
                    depositPause: false,
                    withdrawalPause: false,
                    name: "OpenbitLab Vault",
                    symbol: "oblETH"
                }),
                subvaults: subvaults,
                initialDepositAsset: address(0),
                initialDepositAmount: 0,
                salt: bytes32(0)
            })
        );

        EthWrapper w = EthWrapper(payable(0xfD4a4922d1AFe70000Ce0Ec6806454e78256504e));
        w.deposit{value: 1 gwei}(w.ETH(), 1 gwei, address(vault), deployer, deployer);

        // roundings
        require(
            vault.totalAssets() == vault.totalSupply(), "Total assets should equal total supply"
        );

        console2.log("MultiVault (%s): %s", vault.name(), address(vault));
        vm.stopBroadcast();
        revert("ok");
    }
}
