// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "./MultiVaultDeployScript.sol";

import {IVault} from "@symbiotic/core/interfaces/vault/IVault.sol";
import "forge-std/Script.sol";

contract Deploy is Script {
    address public constant VAULT_ADMIN_MULTISIG = 0xf1eFa099819ED4288Cf4BAAF0D3fF6c5Cc011F62;
    address public constant VAULT_PROXY_ADMIN_MULTISIG = 0x630f0c6372cFE6C915c4C127c328df18bD5Ca981;

    MultiVaultDeployScript public deployScript =
        MultiVaultDeployScript(0x0159AEA190C7bEa09873B9b42Fe8fD836DB8a254);

    address public constant WSTUSR = 0x1202F5C7b4B9E47a1A484E8B270be34dbbC75055;
    address public constant WSTUSR_DEFAULT_COLLATERAL = 0x950fdF40608800535137c61eDf3972C436d680e8;

    uint256 public constant N = 1;
    address public constant DEPLOYER = 0x188858AC61a74350116d1CB6958fBc509FD6afA1;

    address public constant WSTUSR_MULTISIG = 0xE86399fE6d7007FdEcb08A2ee1434Ee677a04433;

    function _deployVaults() internal {
        address[N] memory curators = [WSTUSR_MULTISIG];

        string[N] memory names = ["Re7 Resolv Restaked wstUSR"];

        string[N] memory symbols = ["rstUSR"];

        uint256[N] memory limits = [uint256(50e6 ether)];

        address[N] memory symbioticVaults = [address(0x821C65F4BDaC61F4938d2cf0476F85614178fb72)];

        MultiVaultDeployScript.DeployParams memory deployParams = MultiVaultDeployScript
            .DeployParams({
            admin: VAULT_ADMIN_MULTISIG,
            proxyAdmin: VAULT_PROXY_ADMIN_MULTISIG,
            curator: address(0),
            symbioticVault: address(0),
            depositWrapper: address(0),
            asset: WSTUSR,
            defaultCollateral: WSTUSR_DEFAULT_COLLATERAL,
            limit: 0,
            depositPause: false,
            withdrawalPause: false,
            name: "",
            symbol: "",
            minRatioD18: 0.9 ether,
            maxRatioD18: 0.95 ether,
            salt: bytes32(0)
        });

        for (uint256 i = 0; i < curators.length; i++) {
            deployParams.curator = curators[i];
            deployParams.symbioticVault = symbioticVaults[i];
            deployParams.limit = limits[i];
            deployParams.name = names[i];
            deployParams.symbol = symbols[i];

            (MultiVault multiVault,,) = deployScript.deploy(deployParams);
            if (symbioticVaults[i] != address(0)) {
                IVault(symbioticVaults[i]).setDepositorWhitelistStatus(address(multiVault), true);
                IAccessControl(symbioticVaults[i]).renounceRole(
                    IVault(symbioticVaults[i]).DEPOSIT_WHITELIST_SET_ROLE(), DEPLOYER
                );
            }

            string memory pattern = string.concat(
                multiVault.name(), "; MultiVault: %s; SymbioticVault: %s WithdrawalQueue %s."
            );

            console2.log(
                pattern,
                address(multiVault),
                address(deployParams.symbioticVault),
                deployParams.symbioticVault == address(0)
                    ? address(0)
                    : address(multiVault.subvaultAt(0).withdrawalQueue)
            );
        }
    }

    function run() external {
        uint256 deployerPk = uint256(bytes32(vm.envBytes("MAINNET_DEPLOYER")));
        address deployer = vm.addr(deployerPk);
        require(deployer == DEPLOYER, "not authorized");
        vm.startBroadcast(deployerPk);

        _deployVaults();

        vm.stopBroadcast();
        // revert("success");
    }
}
