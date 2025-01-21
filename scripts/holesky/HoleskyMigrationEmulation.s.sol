// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "forge-std/Script.sol";

import {EthWrapper} from "../../src/EthWrapper.sol";
import "./FactoryDeploy.sol";
import {IDelegatorFactory} from "@symbiotic/core/interfaces/IDelegatorFactory.sol";

import {INetworkRegistry} from "@symbiotic/core/interfaces/INetworkRegistry.sol";
import {IOperatorRegistry} from "@symbiotic/core/interfaces/IOperatorRegistry.sol";
import {ISlasherFactory} from "@symbiotic/core/interfaces/ISlasherFactory.sol";
import {IVaultConfigurator} from "@symbiotic/core/interfaces/IVaultConfigurator.sol";
import {IVaultFactory} from "@symbiotic/core/interfaces/IVaultFactory.sol";
import {
    IBaseDelegator,
    IFullRestakeDelegator,
    IFullRestakeDelegator
} from "@symbiotic/core/interfaces/delegator/IFullRestakeDelegator.sol";
import {INetworkRestakeDelegator} from
    "@symbiotic/core/interfaces/delegator/INetworkRestakeDelegator.sol";
import {INetworkMiddlewareService} from
    "@symbiotic/core/interfaces/service/INetworkMiddlewareService.sol";

import "@openzeppelin/contracts/access/AccessControl.sol";
import {IBaseSlasher} from "@symbiotic/core/interfaces/slasher/IBaseSlasher.sol";
import {ISlasher} from "@symbiotic/core/interfaces/slasher/ISlasher.sol";
import {IVetoSlasher} from "@symbiotic/core/interfaces/slasher/IVetoSlasher.sol";
import {IVault} from "@symbiotic/core/interfaces/vault/IVault.sol";

import "../../src/MellowVaultCompat.sol";
import "../../src/Migrator.sol";

import "@openzeppelin/contracts/utils/Strings.sol";

interface IMellowLRTExt is IMellowLRT, IERC20 {
    function deposit(address to, uint256[] memory amounts, uint256 minLpAmount, uint256 deadline)
        external
        returns (uint256[] memory actualAmounts, uint256 lpAmount);

    function registerWithdrawal(
        address to,
        uint256 lpAmount,
        uint256[] memory minAmounts,
        uint256 deadline,
        uint256 requestDeadline,
        bool closePrevious
    ) external;
}

contract Deploy is Script, FactoryDeploy {
    function run() external {
        uint256 deployerPk = uint256(bytes32(vm.envBytes("HOLESKY_DEPLOYER")));

        address vault1 = 0xab6B95B7F8feF87b1297516F5F8Bb8e4F33C6461;
        address deployer = vm.addr(deployerPk);
        vm.startBroadcast(deployerPk);

        IERC20 wsteth = IERC20(0x8d09a4502Cc8Cf1547aD300E066060D043f6982D);
        wsteth.approve(address(vault1), type(uint256).max);

        IMellowLRTExt mellowLRT = IMellowLRTExt(vault1);

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = wsteth.balanceOf(deployer) / 2;
        (, uint256 lpAmount) = mellowLRT.deposit(deployer, amounts, 0, type(uint256).max);

        for (uint256 i = 0; i < 10; i++) {
            address rndAddress = vm.createWallet(Strings.toString(i)).addr;
            mellowLRT.transfer(rndAddress, lpAmount / 11);
        }

        mellowLRT.registerWithdrawal(
            deployer,
            mellowLRT.balanceOf(deployer),
            new uint256[](1),
            type(uint256).max,
            type(uint256).max,
            true
        );

        vm.stopBroadcast();
        // revert("Success");
    }
}
