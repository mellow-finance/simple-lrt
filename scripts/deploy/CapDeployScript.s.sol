// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts/access/IAccessControl.sol";
import {Vault as SymbioticVault} from "@symbiotic/core/contracts/vault/Vault.sol";
import "forge-std/Script.sol";

interface ICapFactory {
    function createVault(address _owner, address _asset, address _agent, address _network)
        external
        returns (
            address vault,
            address delegator,
            address burner,
            address slasher,
            address stakerRewards
        );
}

contract Deploy is Script {
    address public immutable CAP_FACTORY = 0x0B92300C8494833E504Ad7d36a301eA80DbBAE2e;
    address public immutable CAP_NETWORK = 0x98e52Ea7578F2088c152E81b17A9a459bF089f2a;
    address public immutable WSTETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address public immutable MELLOW_REWARD_MULTISIG = 0x66e137A2D4Fdb520c4B0e4eae3f0b33ed1Cf2980;

    struct Config {
        address vaultAdmin;
        address curator;
        address agent;
        address deployer;
        uint256 limit;
        address vault;
    }

    function run() external {
        uint256 deployerPk = uint256(bytes32(vm.envBytes("HOT_DEPLOYER")));
        address deployer = vm.addr(deployerPk);
        vm.startBroadcast(deployerPk);

        Config[] memory configs = new Config[](2);
        configs[0] = Config({
            agent: address(0),
            limit: 475 ether,
            vault: 0x8c9532a60E0E7C6BbD2B2c1303F63aCE1c3E9811,
            vaultAdmin: 0x9437B2a8cF3b69D782a61f9814baAbc172f72003,
            curator: 0x6e5CaD73D00Bc8340f38afb61Fc5E34f7193F599,
            deployer: deployer
        });

        for (uint256 i = 0; i < configs.length; i++) {
            (address symbioticVault, address stakerRewards) = _deploy(configs[i]);
            string memory parameters = string(
                abi.encodePacked(
                    "Agent: ",
                    vm.toString(configs[i].agent),
                    "; Limit: ",
                    vm.toString(configs[i].limit),
                    "; MellowVault: ",
                    vm.toString(configs[i].vault),
                    "; VaultAdmin: ",
                    vm.toString(configs[i].vaultAdmin),
                    "; Curator: ",
                    vm.toString(configs[i].curator)
                )
            );
            console2.log(
                "SymbioticVault: %s;  StakerRewards: %s; %s.",
                symbioticVault,
                stakerRewards,
                parameters
            );
        }

        vm.stopBroadcast();
        // revert("ok");
    }

    function _deploy(Config memory config)
        internal
        returns (address symbioticVault, address stakerRewards)
    {
        (symbioticVault,,,, stakerRewards) =
            ICapFactory(CAP_FACTORY).createVault(config.deployer, WSTETH, config.agent, CAP_NETWORK);
        SymbioticVault vault = SymbioticVault(symbioticVault);

        vault.grantRole(vault.DEFAULT_ADMIN_ROLE(), config.vaultAdmin);
        vault.grantRole(vault.DEPOSIT_LIMIT_SET_ROLE(), config.curator);

        vault.setIsDepositLimit(true);
        vault.setDepositWhitelist(true);
        vault.setDepositorWhitelistStatus(config.vault, true);
        vault.setDepositLimit(config.limit);

        vault.renounceRole(vault.DEPOSIT_WHITELIST_SET_ROLE(), config.deployer);
        vault.renounceRole(vault.DEPOSITOR_WHITELIST_ROLE(), config.deployer);
        vault.renounceRole(vault.IS_DEPOSIT_LIMIT_SET_ROLE(), config.deployer);
        vault.renounceRole(vault.DEPOSIT_LIMIT_SET_ROLE(), config.deployer);
        vault.renounceRole(vault.DEFAULT_ADMIN_ROLE(), config.deployer);

        IAccessControl(stakerRewards).grantRole(0x00, MELLOW_REWARD_MULTISIG);

        IAccessControl(stakerRewards).renounceRole(
            keccak256("ADMIN_FEE_CLAIM_ROLE"), config.deployer
        );
        IAccessControl(stakerRewards).renounceRole(keccak256("ADMIN_FEE_SET_ROLE"), config.deployer);
        IAccessControl(stakerRewards).renounceRole(0x00, config.deployer);
    }
}
