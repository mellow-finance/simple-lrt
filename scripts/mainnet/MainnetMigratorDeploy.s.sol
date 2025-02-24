// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../src/utils/Claimer.sol";

import "../../src/utils/Migrator.sol";
import "../../src/utils/WhitelistedEthWrapper.sol";
import "./MultiVaultDeployScript.sol";
import "forge-std/Script.sol";

contract Deploy is Script {
    address public constant VAULT_ADMIN_MULTISIG = 0x9437B2a8cF3b69D782a61f9814baAbc172f72003;
    address public constant VAULT_PROXY_ADMIN_MULTISIG = 0x81698f87C6482bF1ce9bFcfC0F103C4A0Adf0Af0;

    address public constant SYMBIOTIC_VAULT_FACTORY = 0xAEb6bdd95c502390db8f52c8909F703E9Af6a346;

    address public constant SIMPLE_LRT_FACTORY = 0x6EA5a344d116Db8949348648713760836D60fC5a;
    address public constant WSTETH_VAULTS_MIGRATOR = 0x643ED3c06E19A96EaBCBC32C2F665DB16282bEaB;

    WhitelistedEthWrapper public depositWrapper =
        WhitelistedEthWrapper(payable(0xfD4a4922d1AFe70000Ce0Ec6806454e78256504e));
    RatiosStrategy public strategy = RatiosStrategy(0x3aA61E6196fb3eb1170E578ad924898624f54ad6);
    MultiVault public multiVaultImplementation =
        MultiVault(0x0C5BC4C8406Fe03214D18bbf2962Ae2fa378c6f7);
    SymbioticWithdrawalQueue public symbioticWithdrawalQueueImplementation =
        SymbioticWithdrawalQueue(0xaB253B304B0BfBe38Ef7EA1f086D01A6cE1c5028);
    MultiVaultDeployScript public deployScript =
        MultiVaultDeployScript(0xffAC02252657ED228e155eE06E60f8b62dC59845);

    function _deployContracts() internal {
        Migrator migrator = new Migrator(
            SIMPLE_LRT_FACTORY,
            WSTETH_VAULTS_MIGRATOR,
            address(multiVaultImplementation),
            address(strategy),
            SYMBIOTIC_VAULT_FACTORY,
            address(symbioticWithdrawalQueueImplementation),
            4 hours
        );

        console2.log("Migrator:", address(migrator));
    }

    function run() external {
        vm.startBroadcast(uint256(bytes32(vm.envBytes("MAINNET_DEPLOYER"))));

        _deployContracts();

        vm.stopBroadcast();
    }
}
