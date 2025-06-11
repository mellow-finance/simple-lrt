// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "./AcceptanceTestRunner.sol";
import "forge-std/Test.sol";

contract AcceptanceTest is Test, AcceptanceTestRunner {
    function testAcceptanceSymbioticDeployWithConfig() external {

        DeployScript script = DeployScript(address(0xC70F0A380D5Bc02d237C46CEF92C6174Db496969));

        validateState(script, 0);
    }
}
