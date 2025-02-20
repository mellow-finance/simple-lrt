// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../src/utils/Claimer.sol";
import "../../src/utils/WhitelistedEthWrapper.sol";
import "./AcceptanceTestRunner.sol";
import "forge-std/Test.sol";

contract AcceptanceTest is Test, AcceptanceTestRunner {
    function testDeployScriptTestDeployment() external {
        Claimer claimer = new Claimer();
        MultiVaultDeployScript deployScript = new MultiVaultDeployScript(
            0x407A039D94948484D356eFB765b3c74382A050B4,
            address(new RatiosStrategy()),
            address(new MultiVault("MultiVault", 1)),
            address(new SymbioticWithdrawalQueue(address(claimer)))
        );

        address admin = vm.createWallet("admin-wallet").addr;
        address proxyAdmin = vm.createWallet("proxy-admin-wallet").addr;
        address curator = vm.createWallet("curator-wallet").addr;

        MultiVaultDeployScript.DeployParams memory deployParams = MultiVaultDeployScript
            .DeployParams({
            symbioticVault: 0x0fD2C2886B40e87dB3b1e7ED1BB486991a9Fb808,
            admin: admin,
            proxyAdmin: proxyAdmin,
            curator: curator,
            depositWrapper: address(0x6dea56807061086eA259865345739021AE043D71),
            minRatioD18: 0.9 ether,
            maxRatioD18: 0.95 ether,
            salt: bytes32(0),
            limit: 100 ether,
            depositPause: false,
            withdrawalPause: false,
            asset: 0x8d09a4502Cc8Cf1547aD300E066060D043f6982D,
            name: "Mellow pre-launch vault",
            symbol: "MPLV3",
            defaultCollateral: 0x23E98253F372Ee29910e22986fe75Bb287b011fC
        });

        bytes32 salt = deployScript.calculateSalt(deployParams);
        (,, deployParams) = deployScript.deploy(deployParams);

        validateState(deployScript, deployScript.deployments(salt));
    }
}
