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

        bytes32 salt = bytes32(uint256(1));
        address[] memory deployLibraries = new address[](2);
        deployLibraries[0] = address(
            new SymbioticDeployLibrary{salt: salt}(
                0x29300b1d3150B4E2b12fE80BE72f365E200441EC,
                0x99F2B89fB3C363fBafD8d826E5AA77b28bAB70a0,
                1, // vaultVersion
                3, // resolverSetEpochsDelay
                1,
                0, // delegation type
                0xAEb6bdd95c502390db8f52c8909F703E9Af6a346,
                0xaB253B304B0BfBe38Ef7EA1f086D01A6cE1c5028
            )
        );
        EigenLayerDeployLibrary prevLib = EigenLayerDeployLibrary(0x0653EE9315eAe918430e061D38246832311F81A7);
        deployLibraries[1] = address(
            new EigenLayerDeployLibrary{salt: salt}(
                0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0,
                0x858646372CC42E1A627fcE94aa7A7033e7CF075A,
                0x7750d328b314EfFa365A0402CcfD489B80B0adda,
                0x39053D51B77DC0d36036Fc1fCc8Cb819df8Ef37A,
                prevLib.withdrawalQueueImplementation(),
                prevLib.isolatedEigenLayerVaultImplementation(),
                prevLib.isolatedEigenLayerWstETHVaultImplementation(),
                address(prevLib.helper())
            )
        );
        DeployScript script = new DeployScript{salt: salt}(
            0x3aA61E6196fb3eb1170E578ad924898624f54ad6,
            0x0C5BC4C8406Fe03214D18bbf2962Ae2fa378c6f7,
            deployLibraries,
            deployer
        );
        script.setIsWhitelisted(deployer, true);

        vm.stopBroadcast();
        console2.log("           DeployScript:", address(script));
        console2.log(" SymbioticDeployLibrary:", deployLibraries[0]);
        console2.log("EigenLayerDeployLibrary:", deployLibraries[1]);
        revert("success");
    }
}
