// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "forge-std/Script.sol";

import "./DeployScript.sol";
import "./libraries/EigenLayerDeployLibrary.sol";
import "./libraries/SymbioticDeployLibrary.sol";

contract Deploy is Script {
    DeployScript public constant script = DeployScript(0xC70F0A380D5Bc02d237C46CEF92C6174Db496969);

    address public constant targetMellowOFT = address(0);
    address public constant targetCore = address(0);

    address public constant curator = 0xc6eA3826A7a357162d01e22044D845522f62BB4c; // 0G 3/4 
    address public constant vaultAdmin = 0xfc7350b0d7a358Db58875148faF3bDEAaFC82911; // 5/8 Mellow+0g 4+4 Ethereum+0G
    address public constant vaultProxyAdmin = 0xEF1c19bDEE7fE61a1B2b98375D2003f57e4B2B8a; // 5/8 Mellow+0g 4+4 Ethereum+0G

    string private name = "Staked OG";
    string private symbol = "stOG";
    uint256 public constant limit = type(uint256).max / 2;

    function run() external {

        uint256 deployerPk = uint256(bytes32(vm.envBytes("HOT_DEPLOYER")));
        address deployer = vm.addr(deployerPk);
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
                    asset: targetMellowOFT,
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

        console2.log("OG Vault: %s",address(vault));
        vm.stopBroadcast();
       // revert("ok");
    }
}
