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

        DeployScript script = DeployScript(address(0xC70F0A380D5Bc02d237C46CEF92C6174Db496969));
        DeployScript.SubvaultParams[] memory subvaults = new DeployScript.SubvaultParams[](1);
        address[] memory networks = new address[](1);
        address[] memory receivers = new address[](1);
        networks[0] = 0x9101eda106A443A0fA82375936D0D1680D5a64F5;
        receivers[0] = 0xD5881f91270550B8850127f05BD6C8C203B3D33f;
        subvaults[0] = DeployScript.SubvaultParams({
            libraryIndex: 0,
            data: SymbioticDeployLibrary(script.deployLibraries(0)).combineOptions(
                0xdCaC890b14121FD5D925E2589017Be68C2B5B324, // wsteth burner
                7 days, // epoch duration
                3 days, // veto duration
                15 days, // burner delay
                address(0),  // hook
                networks,
                receivers
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
                //initialDepositAsset: address(0),
                //initialDepositAmount: 0,
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
