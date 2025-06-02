// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "./LidoV3DeployScript.sol";
import "forge-std/Script.sol";

contract Deploy is Script {
    function run() external {
        uint256 deployerPk = uint256(bytes32(vm.envBytes("MAINNET_DEPLOYER")));
        address deployer = vm.addr(deployerPk);
        require(deployer == 0x188858AC61a74350116d1CB6958fBc509FD6afA1, "not authorized");
        vm.startBroadcast(deployerPk);

        LidoV3DeployScript deployScript = new LidoV3DeployScript();
        address(deployScript).call{value: 10 gwei}("");

        LidoV3DeployScript.Deployment memory d = deployScript.deploy(
            LidoV3DeployScript.Config({
                vaultAdmin: 0x9437B2a8cF3b69D782a61f9814baAbc172f72003,
                vaultProxyAdmin: 0x81698f87C6482bF1ce9bFcfC0F103C4A0Adf0Af0,
                curator: 0x79b11A9F722b0f92E9A7dFae8006D3d755C1a8c4,
                asset: 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0,
                defaultCollateral: 0xC329400492c6ff2438472D4651Ad17389fCb843a,
                burnerGlobalReceiver: 0xdCaC890b14121FD5D925E2589017Be68C2B5B324,
                depositWrapper: 0xfD4a4922d1AFe70000Ce0Ec6806454e78256504e,
                name: "UltraYield x Edge x Allnodes",
                symbol: "alluETH",
                limit: 3000 ether, // wsteth limit,
                epochDuration: 7 days,
                vetoDuration: 3 days,
                burnerDelay: 15 days,
                minRatioD18: 0.9 ether,
                maxRatioD18: 0.95 ether,
                salt: bytes32(0)
            })
        );
        console2.log(
            "MultiVault: %s; SymbioticVault: %s; WithdrawalQueue: %s.",
            d.vault,
            d.symbioticVault,
            d.withdrawalQueue
        );

        vm.stopBroadcast();
        revert("ok");
    }
}
