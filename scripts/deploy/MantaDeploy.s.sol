// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "forge-std/Script.sol";

import "./DeployScript.sol";
import "./libraries/EigenLayerDeployLibrary.sol";
import "./libraries/SymbioticDeployLibrary.sol";

contract Deploy is Script {
    DeployScript public constant script = DeployScript(0xC70F0A380D5Bc02d237C46CEF92C6174Db496969);
    address public constant mellowOFT = 0xF3A1C44d1825Fb49d633F681Cb2B4e7dE2e071D4;
    address public constant targetCore = 0x48E69cB6c6F05e194589BE37408c5717E7cCE1C7;
    address public constant curator = 0xBEE16D4331B0AD6aa60E07bA55427b56E0f578fb;
    address public constant vaultAdmin = 0x0e5c716aA17106E6f6B74b2c0E1A015B643CE308;
    address public constant vaultProxyAdmin = 0xD4aFEe5cCe62128F3ACb67202e7Ae85fD3888f2A;

    string private symbol = "mstManta";
    string private name = "Manta Restaking Vault";
    uint256 public constant limit = type(uint256).max;

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
