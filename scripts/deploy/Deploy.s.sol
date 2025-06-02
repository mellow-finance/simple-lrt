// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "forge-std/Script.sol";

import "./DeployScript.sol";
import "./libraries/EigenLayerDeployLibrary.sol";
import "./libraries/SymbioticDeployLibrary.sol";

contract Deploy is Script {
    function run() external {
        uint256 deployerPk = uint256(bytes32(vm.envBytes("MAINNET_DEPLOYER")));
        address deployer = vm.addr(deployerPk);
        vm.startBroadcast(deployerPk);

        // uint256 gas = gasleft();
        bytes32 salt = bytes32(0);
        address[] memory deployLibraries = new address[](2);
        deployLibraries[0] = address(
            new SymbioticDeployLibrary{salt: salt}(
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
            new EigenLayerDeployLibrary{salt: salt}(
                0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0,
                0x858646372CC42E1A627fcE94aa7A7033e7CF075A,
                0x7750d328b314EfFa365A0402CcfD489B80B0adda,
                0x39053D51B77DC0d36036Fc1fCc8Cb819df8Ef37A,
                address(
                    new EigenLayerWithdrawalQueue{salt: salt}(
                        0x25024a3017B8da7161d8c5DCcF768F8678fB5802,
                        0x39053D51B77DC0d36036Fc1fCc8Cb819df8Ef37A
                    )
                ),
                address(new IsolatedEigenLayerVault{salt: salt}()),
                address(
                    new IsolatedEigenLayerWstETHVault{salt: salt}(
                        0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0
                    )
                )
            )
        );
        DeployScript script = new DeployScript{salt: salt}(
            0x3aA61E6196fb3eb1170E578ad924898624f54ad6,
            0x0C5BC4C8406Fe03214D18bbf2962Ae2fa378c6f7,
            deployLibraries,
            deployer
        );
        script.setIsWhitelisted(deployer, true);

        // console2.log(gas - gasleft());
        vm.stopBroadcast();
        // revert("success");
    }
}
