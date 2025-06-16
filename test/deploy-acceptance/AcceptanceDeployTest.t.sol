// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "./AcceptanceTestRunner.sol";

import "forge-std/Test.sol";
import "scripts/deploy/DeployMultiVault.sol";

contract AcceptanceDeployTest is Test, AcceptanceTestRunner, DeployMultiVault {
    /// @dev acceptance for fact deployment
    function testAcceptanceDeploy() external {
        uint256 vaultIndex = deploy();

        validateState(script, vaultIndex);
    }

    function getDeployParams()
        internal
        override
        returns (DeployScript.Config memory config, DeployScript.SubvaultParams[] memory subvaults)
    {
        DeployScript.SubvaultParams[] memory subvaults = new DeployScript.SubvaultParams[](1);
        (address[] memory networks, address[] memory receivers) =
            getNetworksReceivers(NETWORK.PRIMEV);

        address asset = tBTC;

        subvaults[0] = DeployScript.SubvaultParams({
            libraryIndex: 0,
            data: SymbioticDeployLibrary(script.deployLibraries(0)).combineOptions(
                burner(asset), // burner
                10 days, // epoch duration
                3 days, // veto duration
                21 days, // burner delay = 2 * (epoch duration) + 1
                hook[HOOK.NetworkRestakeDecreaseHook],
                networks,
                receivers
            ),
            minRatioD18: 0.9 ether,
            maxRatioD18: 0.95 ether
        });

        (address vaultAdmin, address vaultProxyAdmin) = vaultAndProxyAdmin(asset);

        config = DeployScript.Config({
            vaultAdmin: 0x53980f83eCB2516168812A10cb8aCeC79B55718b,
            vaultProxyAdmin: 0x994e2478Df26E9F076D6F50b6cA18c39aa6bD6Ca,
            curator: 0xA1E38210B06A05882a7e7Bfe167Cd67F07FA234A,
            asset: asset,
            defaultCollateral: defaultCollateral(asset),
            depositWrapper: address(0),
            limit: 1000 ether,
            depositPause: false,
            withdrawalPause: false,
            name: "restaked tBTC",
            symbol: "rtBTC"
        });

        return (config, subvaults);
    }
}
