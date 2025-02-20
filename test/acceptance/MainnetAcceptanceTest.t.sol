// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../src/utils/Claimer.sol";
import "../../src/utils/WhitelistedEthWrapper.sol";
import "./AcceptanceTestRunner.sol";
import "forge-std/Test.sol";

contract AcceptanceTest is Test, AcceptanceTestRunner {
    function testDeployScriptMainnetDeployment() external {
        MultiVaultDeployScript deployScript =
            MultiVaultDeployScript(0xffAC02252657ED228e155eE06E60f8b62dC59845);
        bytes32[6] memory salts = [
            bytes32(0xB010AF4CB52863FF4B28BC997022CA55F93ACE409318030A9AA325FD29C6F7ED),
            bytes32(0xF8AA64FA6FEEDA87E27ACAC338BBC94424EBA1702E297A9B6CB5F02681CD3027),
            bytes32(0x7190549DF495711D77B2D843B6C70C812DE92FCC5260A7981E55784DEB61B6BC),
            bytes32(0xE6CF73F471B572FBB53769A3CBFE17ECA0CAB04753B01229119D1515F40E9C5D),
            bytes32(0x8852FADAB8E4C372E37AF700B9A85D0A844F48810D9A84B25C6D94BEF9DD2E29),
            bytes32(0x48E6A64BBFBFB462365928967141846E51C73B5B053A8B7118E991499C02DB7A)
        ];
        for (uint256 i = 0; i < salts.length; i++) {
            validateState(deployScript, deployScript.deployments(salts[i]));
        }
    }
}
