// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "./DeployMultiVault.sol";
import "forge-std/Test.sol";

contract AcceptanceDeployTest is DeployMultiVault {
    /// @dev acceptance for fact deployment
    function testAcceptanceDeploy() external {
        uint256 vaultIndex = deploy();

        validateState(script, vaultIndex);
    }

    function getDeployParams()
        internal
        view
        override
        returns (DeployScript.Config memory config, DeployScript.SubvaultParams[] memory subvaults)
    {
        string memory name = "Re7 Aegis Restaked sYUSD Vault";
        string memory symbol = "rsYUSD";
        address asset = sYUSD;
        uint256 limit = 5000000 ether; // 5 million sYUSD, 18 decimals

        subvaults = new DeployScript.SubvaultParams[](1);

        (address[] memory networks, address[] memory receivers) =
            getNetworksReceivers(NETWORK.PRIMEV);

        uint48 epochDuration = 7 days;
        uint48 vetoDuration = 3 days;
        uint48 burnerDelay = 15 days; // 2 * (epoch duration) + 1
        address hook = hook(HOOK.None);

        subvaults[0] = DeployScript.SubvaultParams({
            libraryIndex: 0,
            data: SymbioticDeployLibrary(script.deployLibraries(0)).combineOptions(
                burner(asset), epochDuration, vetoDuration, burnerDelay, hook, networks, receivers
            ),
            minRatioD18: 0.9 ether,
            maxRatioD18: 0.95 ether
        });

        config = DeployScript.Config({
            vaultAdmin: 0x40216F728EF746a6fB282972fbA7fCeb4A50eB1E,
            vaultProxyAdmin: 0x007D6cc51d3dEeEb2351edCb403a4a7D9Be6f885,
            curator: 0xE86399fE6d7007FdEcb08A2ee1434Ee677a04433,
            asset: asset,
            defaultCollateral: defaultCollateral(asset),
            depositWrapper: address(0),
            limit: limit,
            depositPause: false,
            withdrawalPause: false,
            name: name,
            symbol: symbol
        });

        return (config, subvaults);
    }
}
