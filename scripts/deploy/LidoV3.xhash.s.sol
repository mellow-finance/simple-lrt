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
        string memory name = "XHash Dual-Yield Restake Vault";
        string memory symbol = "xstETH";
        address asset = wstETH;
        uint256 limit = 10000 ether;

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

        (address vaultAdmin, address vaultProxyAdmin) =
            vaultAndProxyAdmin(asset, ADMIN.Undefined);

        config = DeployScript.Config({
            vaultAdmin: vaultAdmin,
            vaultProxyAdmin: vaultProxyAdmin,
            curator: 0xD1f59ba974E828dF68cB2592C16b967B637cB4e4,
            asset: asset,
            defaultCollateral: defaultCollateral(asset),
            depositWrapper: 0xfD4a4922d1AFe70000Ce0Ec6806454e78256504e,
            limit: limit,
            depositPause: false,
            withdrawalPause: false,
            name: name,
            symbol: symbol
        });

        return (config, subvaults);
    }
}
