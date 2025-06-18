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
        
        string name = "restaked tBTC";
        string symbol = "rtBTC";
        address asset = tBTC;

        uint48 epochDuration = 10 days;
        uint48 vetoDuration = 3 days;
        uint48 burnerDelay = 21 days; // 2 * (epoch duration) + 1
        uint256 limit = 1000 ether;

        subvaults[0] = DeployScript.SubvaultParams({
            libraryIndex: 0,
            data: SymbioticDeployLibrary(script.deployLibraries(0)).combineOptions(
                burner(asset),
                epochDuration,
                vetoDuration,
                burnerDelay,
                hook(HOOK.NetworkRestakeDecreaseHook),
                networks,
                receivers
            ),
            minRatioD18: 0.9 ether,
            maxRatioD18: 0.95 ether
        });

        (address vaultAdmin, address vaultProxyAdmin) = vaultAndProxyAdmin(asset, CURATOR.MEV);

        config = DeployScript.Config({
            vaultAdmin: vaultAdmin,
            vaultProxyAdmin: vaultProxyAdmin,
            curator: 0xA1E38210B06A05882a7e7Bfe167Cd67F07FA234A,
            asset: asset,
            defaultCollateral: defaultCollateral(asset),
            depositWrapper: depositWrapper(asset),
            limit: limit,
            depositPause: false,
            withdrawalPause: false,
            name: name,
            symbol: symbol
        });

        return (config, subvaults);
    }
}
