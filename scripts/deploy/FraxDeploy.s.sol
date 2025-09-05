// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "forge-std/Script.sol";

import "./DeployScript.sol";
import "./libraries/EigenLayerDeployLibrary.sol";
import "./libraries/SymbioticDeployLibrary.sol";

contract Deploy is Script {
    DeployScript public constant script = DeployScript(0xC70F0A380D5Bc02d237C46CEF92C6174Db496969);
    address public constant mellowOFT = 0xf85932AcE734E3CF04b5c2a6Cb7B10f44014eCb9;
    address public constant targetCore = 0x6408a5261578E17f858ADD039dEb72E1952E9Fe9;
    address public constant curator = 0xE86399fE6d7007FdEcb08A2ee1434Ee677a04433;
    address public constant vaultAdmin = 0xa62243c7a36e74d8280781242a3B0e019ce74E64;
    address public constant vaultProxyAdmin = 0xC7e8b00a61adB658c49D2d8a377FC44572e9ECb5;

    string private symbol = "rstFRAX";
    string private name = "FRAX Vault";
    uint256 public constant limit = 1000000 ether;

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
                    burnerDelay: 15 days,
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
