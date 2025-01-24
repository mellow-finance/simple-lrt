// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "forge-std/Script.sol";

import {EthWrapper} from "../../src/EthWrapper.sol";
import "./FactoryDeploy.sol";

contract Deploy is Script, FactoryDeploy {
    function run() external {
        uint256 vaultAdminPk = uint256(bytes32(vm.envBytes("HOLESKY_DEPLOYER")));

        revert("Success");
    }
}
