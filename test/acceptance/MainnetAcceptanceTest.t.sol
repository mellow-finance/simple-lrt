// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../src/utils/Claimer.sol";
import "../../src/utils/WhitelistedEthWrapper.sol";
import "./AcceptanceTestRunner.sol";
import "forge-std/Test.sol";

contract AcceptanceTest is Test, AcceptanceTestRunner {
    function testDeployScriptMainnetDeployment() external {
        MultiVaultDeployScript deployScript =
            MultiVaultDeployScript(0x10243D6aa1ef51E0Dcd8d707bE0De638DcC981D5);
        bytes32[4] memory salts = [
            // bytes32(0x4C875B0D4F93AAA5040811BD9E7D15CAC3C68FE0A32684F2CD6AC63327029C54),
            bytes32(0xCD108585EE7AD8429EDE0B4FAF36D03BBED574CF5E068D8E5F4B814A82A2BEFA),
            bytes32(0xD6731FE261C7EE4542C6F6B5F93C7BDB1F0E9A7C732ABB42830CA5D15E6AF03C),
            bytes32(0xB3667D38A35E9A18E9F1A2F120A10B84797ED2E92D9F7C5E2582E2A5726E0805),
            bytes32(0xDD121B873F86669F7ED057792C05CAA0327808F88169C973E2E7E1DCC5CB67B8) //,
                // bytes32(0x2B001399ADCB4C709320EA937FCAAA284CEE9417035A8D9D281C984D11625FBD)
        ];
        for (uint256 i = 0; i < salts.length; i++) {
            validateState(deployScript, deployScript.deployments(salts[i]));
        }
    }
}
