// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "forge-std/Script.sol";

import "./DeployScript.sol";
import "./libraries/EigenLayerDeployLibrary.sol";
import "./libraries/SymbioticDeployLibrary.sol";

contract Deploy is Script {
    DeployScript public constant script = DeployScript(0xC70F0A380D5Bc02d237C46CEF92C6174Db496969);
    address public constant mellowOFT = 0xb79956D87D887Ba850efaFdefe387458f463750c; // +
    address public constant targetCore = 0xf1390f694f34bFE1aa651e8a0313fDc485A39132; // +
    address public constant curator = 0x0c2Bc4d2698820e12E6eBe863E7b9E2650CD5b7D; // +
    address public constant vaultAdmin = 0x258Ea2008C1aae005F75F1D43D4dC51d5c6c46F0; // +
    address public constant vaultProxyAdmin = 0x7377344FCD33844541cb6966ffa7FcAB05641183; // +

    string private symbol = "stSOLV";
    string private name = "Staked SOLV";
    uint256 public constant limit = 550000000 ether; // 550000000 SOLV

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
                    epochDuration: 10.5 days,
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

        uint256 g = gasleft();
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

        console2.log(address(vault));
        vm.stopBroadcast();
    }
}
