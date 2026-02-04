// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "forge-std/Script.sol";

import "./DeployScript.sol";
import "./libraries/EigenLayerDeployLibrary.sol";
import "./libraries/SymbioticDeployLibrary.sol";

contract Deploy is Script {
    DeployScript public constant script = DeployScript(0xC70F0A380D5Bc02d237C46CEF92C6174Db496969);
    address public constant mellowOFT = 0xA9402c888102fc725902caf5B243300bE24B77EF;
    address public constant targetCore = 0xA2598154978aBE38f017617972ED989283975fDD;
    address public constant curator = 0x96ACD1963B5D65a87E4402909e585AF06c93d3C9;
    address public constant vaultAdmin = 0x0526E260950A4E592c3e3Eaa0438F1FD88526E24;
    address public constant vaultProxyAdmin = 0x0526E260950A4E592c3e3Eaa0438F1FD88526E24;

    string private symbol = "BaseTHQInternal";
    string private name = "Base Omnichain Theoriq Token (Internal)";
    uint256 public constant limit = type(uint256).max;

    function run() external {
        uint256 deployerPk = uint256(bytes32(vm.envBytes("HOT_DEPLOYER")));
        vm.startBroadcast(deployerPk);

        DeployScript.SubvaultParams[] memory subvaults = new DeployScript.SubvaultParams[](1);
        subvaults[0] = DeployScript.SubvaultParams({
            libraryIndex: 0,
            data: abi.encode(
                SymbioticDeployLibrary.DeployParams({
                    burnerGlobalReceiver: address(0xdead),
                    epochDuration: 7 days,
                    vetoDuration: 3 days,
                    burnerDelay: 1 days,
                    hook: address(0),
                    networks: new address[](0),
                    receivers: new address[](0)
                })
            ),
            minRatioD18: 0.95 ether,
            maxRatioD18: 1 ether
        });

        (, MultiVault vault) = script.deploy(
            DeployScript.DeployParams({
                config: DeployScript.Config({
                    vaultAdmin: vaultAdmin,
                    vaultProxyAdmin: vaultProxyAdmin,
                    curator: curator,
                    asset: mellowOFT,
                    defaultCollateral: address(0),
                    depositWrapper: targetCore,
                    depositPause: false,
                    withdrawalPause: false,
                    limit: limit,
                    name: name,
                    symbol: symbol
                }),
                subvaults: subvaults,
                salt: bytes32(0)
            })
        );

        console2.log("BaseTHQInternal: %s", address(vault));
        vm.stopBroadcast();
        // revert("ok");
    }
}
