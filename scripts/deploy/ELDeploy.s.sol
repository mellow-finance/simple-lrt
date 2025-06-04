// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "forge-std/Script.sol";

import "../../src/utils/EthWrapper.sol";
import "./DeployScript.sol";
import "./libraries/EigenLayerDeployLibrary.sol";

contract Deploy is Script {
    function run() external {
        uint256 deployerPk = uint256(bytes32(vm.envBytes("MAINNET_DEPLOYER")));
        address deployer = vm.addr(deployerPk);
        vm.startBroadcast(deployerPk);

        DeployScript script = DeployScript(address(0x87795a720F7d11Ab16d04f3Bd2a664BCDD20E71d));
        DeployScript.SubvaultParams[] memory subvaults = new DeployScript.SubvaultParams[](1);
        ISignatureUtils.SignatureWithExpiry memory signature;
        subvaults[0] = DeployScript.SubvaultParams({
            libraryIndex: 1,
            data: EigenLayerDeployLibrary(script.deployLibraries(1)).combineOptions(
                0x93c4b944D05dfe6df7645A86cd2206016c51564D,
                0xDbEd88D83176316fc46797B43aDeE927Dc2ff2F5,
                signature,
                bytes32(0)
            ),
            minRatioD18: 0.9 ether,
            maxRatioD18: 0.95 ether
        });

        (uint256 index, MultiVault vault) = script.deploy(
            DeployScript.DeployParams({
                config: DeployScript.Config({
                    vaultAdmin: deployer,
                    vaultProxyAdmin: deployer,
                    curator: deployer,
                    asset: 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0,
                    defaultCollateral: 0xC329400492c6ff2438472D4651Ad17389fCb843a,
                    depositWrapper: address(0),
                    limit: 100 ether,
                    depositPause: false,
                    withdrawalPause: false,
                    name: "MultiVault with EigenLayer test deployment",
                    symbol: "MVwELtd"
                }),
                subvaults: subvaults,
                initialDepositAsset: address(0),
                initialDepositAmount: 0,
                salt: bytes32(0)
            })
        );

        EthWrapper w = EthWrapper(payable(0x7A69820e9e7410098f766262C326E211BFa5d1B1));
        w.deposit{value: 1 gwei}(w.ETH(), 1 gwei, address(vault), deployer, deployer);

        // roundings
        require(
            vault.totalAssets() + 2 wei == vault.totalSupply(),
            "Total assets should equal total supply"
        );

        console2.log("MultiVault with EigenLayer pair:", address(vault));
        vm.stopBroadcast();
        // revert("ok");
    }
}
