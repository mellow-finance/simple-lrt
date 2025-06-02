// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "./AcceptanceTestRunner.sol";
import "forge-std/Test.sol";

contract AcceptanceTest is Test, AcceptanceTestRunner {
    function testAcceptanceDeployWithConfig() external {
        address deployer = address(this);

        DeployScript script;
        {
            bytes32 salt = bytes32(0);
            address[] memory deployLibraries = new address[](2);
            deployLibraries[0] = address(
                new SymbioticDeployLibrary(
                    0x29300b1d3150B4E2b12fE80BE72f365E200441EC,
                    0x99F2B89fB3C363fBafD8d826E5AA77b28bAB70a0,
                    1,
                    3,
                    1,
                    0,
                    0xAEb6bdd95c502390db8f52c8909F703E9Af6a346,
                    0xaB253B304B0BfBe38Ef7EA1f086D01A6cE1c5028
                )
            );

            deployLibraries[1] = address(
                new EigenLayerDeployLibrary(
                    0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0,
                    0x858646372CC42E1A627fcE94aa7A7033e7CF075A,
                    0x7750d328b314EfFa365A0402CcfD489B80B0adda,
                    0x39053D51B77DC0d36036Fc1fCc8Cb819df8Ef37A,
                    address(
                        new EigenLayerWithdrawalQueue(
                            0x25024a3017B8da7161d8c5DCcF768F8678fB5802,
                            0x39053D51B77DC0d36036Fc1fCc8Cb819df8Ef37A
                        )
                    ),
                    address(new IsolatedEigenLayerVault()),
                    address(
                        new IsolatedEigenLayerWstETHVault(
                            0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0
                        )
                    )
                )
            );
            script = new DeployScript(
                0x3aA61E6196fb3eb1170E578ad924898624f54ad6,
                0x0C5BC4C8406Fe03214D18bbf2962Ae2fa378c6f7,
                deployLibraries,
                deployer
            );

            script.setHasWhitelist(true);
            script.setIsWhitelisted(deployer, true);
        }

        DeployScript.SubvaultParams[] memory subvaults = new DeployScript.SubvaultParams[](4);
        subvaults[0] = DeployScript.SubvaultParams({
            libraryIndex: 0,
            data: SymbioticDeployLibrary(script.deployLibraries(0)).combineOptions(
                address(0xdead), 7 days, 3 days, 15 days
            ),
            minRatioD18: 0.45 ether,
            maxRatioD18: 0.5 ether
        });

        subvaults[1] = DeployScript.SubvaultParams({
            libraryIndex: 0,
            data: SymbioticDeployLibrary(script.deployLibraries(0)).combineOptions(
                address(0xdead), 7 days, 3 days, 15 days
            ),
            minRatioD18: 0.45 ether,
            maxRatioD18: 0.5 ether
        });

        ISignatureUtils.SignatureWithExpiry memory signature;
        subvaults[2] = DeployScript.SubvaultParams({
            libraryIndex: 1,
            data: EigenLayerDeployLibrary(script.deployLibraries(1)).combineOptions(
                0x93c4b944D05dfe6df7645A86cd2206016c51564D,
                0xDbEd88D83176316fc46797B43aDeE927Dc2ff2F5, // random operator 1
                signature,
                bytes32(0)
            ),
            minRatioD18: 0.45 ether,
            maxRatioD18: 0.5 ether
        });

        subvaults[3] = DeployScript.SubvaultParams({
            libraryIndex: 1,
            data: EigenLayerDeployLibrary(script.deployLibraries(1)).combineOptions(
                0x93c4b944D05dfe6df7645A86cd2206016c51564D,
                0x5ACCC90436492F24E6aF278569691e2c942A676d, // random operator 2
                signature,
                bytes32(0)
            ),
            minRatioD18: 0.45 ether,
            maxRatioD18: 0.5 ether
        });

        (uint256 index, /* MultiVault vault */ ) = script.deploy(
            DeployScript.DeployParams({
                config: DeployScript.Config({
                    vaultAdmin: vm.createWallet("vaultAdmin").addr,
                    vaultProxyAdmin: vm.createWallet("vaultProxyAdmin").addr,
                    curator: vm.createWallet("curator").addr,
                    asset: 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0,
                    defaultCollateral: 0xC329400492c6ff2438472D4651Ad17389fCb843a,
                    depositWrapper: address(0),
                    limit: 100 ether,
                    depositPause: false,
                    withdrawalPause: false,
                    name: "Empty multiVault",
                    symbol: "EMV"
                }),
                subvaults: subvaults,
                initialDepositAsset: address(0),
                initialDepositAmount: 0,
                salt: bytes32(0)
            })
        );
        validateState(script, index);
    }
}
