// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../scripts/mainnet/LidoV3DeployScript.sol";
import "../../src/utils/Claimer.sol";
import "../../src/utils/WhitelistedEthWrapper.sol";
import "./AcceptanceTestRunner.sol";
import "forge-std/Test.sol";

contract AcceptanceTest is Test, AcceptanceTestRunner {
    function testDeployScriptMainnetDeploymentBatch1() external {
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

    function testDeployScriptMainnetDeploymentBatch2() external {
        MultiVaultDeployScript deployScript =
            MultiVaultDeployScript(0xffAC02252657ED228e155eE06E60f8b62dC59845);
        bytes32[7] memory salts = [
            bytes32(0x247D093390D65DF91BBFA42663979A38E7E0F49451183D084936FFA591E90F25),
            bytes32(0xA01E4B8FF69BF320D7206AE4409DFFCD9839E206C79E0715F6271D7F2ED79A43),
            bytes32(0x58F59437317AD93DEFBB240AFE2BCA9205CA69451C7C794BDFC3FAE92F1F8E0D),
            bytes32(0xFF0B57973F6FF2894D473816BE2A85C38BFF36A3698BC582F26DB43F08938DA3),
            bytes32(0x1A3008E6F5A1AD12EDFFB4DC66C31062BF43459FC384BFDDB7ABD145C31FD434),
            bytes32(0xF06539F113EF78D1431B6EDE344F80658F21E6EA7921BA076068ADE120E9298A),
            bytes32(0xB8F037CBB086E32A6CD7C828FB495DA8F9229B8E45C930F56B7891A16564908F)
        ];
        for (uint256 i = 0; i < salts.length; i++) {
            validateState(deployScript, deployScript.deployments(salts[i]));
        }
    }

    function testDeployScriptMainnetDeploymentConfig() external {
        LidoV3DeployScript script = new LidoV3DeployScript();
        deal(address(this), 10 gwei);
        address(script).call{value: 10 gwei}("");
        LidoV3DeployScript.Deployment memory d = script.deploy(
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

        MultiVaultDeployScript deployScript = script.deployScript();
        validateState(deployScript, deployScript.deployments(d.mvSalt));
    }
}
