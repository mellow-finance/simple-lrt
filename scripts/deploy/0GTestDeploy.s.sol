// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "forge-std/Script.sol";

import "./DeployScript.sol";
import "./libraries/EigenLayerDeployLibrary.sol";
import "./libraries/SymbioticDeployLibrary.sol";

contract Deploy is Script {
    DeployScript public constant script = DeployScript(0xeb74327A74788469Cdf87105eec1F80CED50a963);

    address public constant targetMellowOFT = 0x4fed2B4d6c797f22026283a7a10A14B86Bd0636C;
    address public constant targetCore = 0xD48b09Fc5fB2c3C8a24DD67e90542a8f443BA21b;
    address public constant testWallet = 0x3622B8C85C9a4A2ecda005349045FB80912D38f7;

    address public constant curator = testWallet;
    address public constant vaultAdmin = testWallet;
    address public constant vaultProxyAdmin = testWallet;

    string private symbol = "stOG";
    string private name = "Staked OG";
    uint256 public constant limit = type(uint256).max / 2;

    function run() external {
        {
            uint256 deployerPk = uint256(bytes32(vm.envBytes("ADMIN_OG_TEST")));
            address deployer = vm.addr(deployerPk);
            vm.startBroadcast(deployerPk);
            MultiVault vault = MultiVault(payable(0x6908E3Ae07178dc58CCdc18FFCFc9953beEda0a2)); // OG Test Vault
            address admin = 0x7A58D9a1CB44c05a240C18DFf1f1D17DE42f1954;

            
            vault.grantRole(IRatiosStrategy(address(vault.rebalanceStrategy())).RATIOS_STRATEGY_SET_RATIOS_ROLE(), admin);
            //vault.grantRole(vault.ADD_SUBVAULT_ROLE(), admin);
            //vault.grantRole(vault.REMOVE_SUBVAULT_ROLE(), admin);
            //vault.grantRole(vault.SET_STRATEGY_ROLE(), admin);
            //vault.grantRole(vault.SET_DEFAULT_COLLATERAL_ROLE(), admin);
            //vault.grantRole(vault.SET_ADAPTER_ROLE(), admin);
            //vault.grantRole(vault.REBALANCE_ROLE(), admin);
        }
        //revert("ok");
        return;

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
