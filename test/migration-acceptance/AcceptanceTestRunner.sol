// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../scripts/deploy/DeployScript.sol";
import "../../scripts/deploy/libraries/EigenLayerDeployLibrary.sol";
import "../../scripts/deploy/libraries/SymbioticDeployLibrary.sol";
import "../../src/utils/Claimer.sol";

import "@openzeppelin/contracts/access/IAccessControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/extensions/IAccessControlEnumerable.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "@symbiotic/core/interfaces/IDelegatorFactory.sol";
import "@symbiotic/core/interfaces/ISlasherFactory.sol";
import "@symbiotic/core/interfaces/vault/IVaultStorage.sol";

import "forge-std/StdAssertions.sol";
import "forge-std/console2.sol";

import "../../src/utils/Migrator.sol";

interface ISafe {
    function getOwners() external view returns (address[] memory);

    function getThreshold() external view returns (uint256);
}

interface IMellowSymbioticVaultQueue {
    function withdrawalQueue() external view returns (address);
}

abstract contract AcceptanceTestRunner is StdAssertions {
    struct PairAddressBytes32 {
        address address_;
        bytes32 bytes32_;
    }

    // AccessControl roles:
    bytes32 private DEFAULT_ADMIN_ROLE = 0x00;

    // VaultControl roles
    bytes32 private constant SET_LIMIT_ROLE = keccak256("SET_LIMIT_ROLE");
    bytes32 private constant PAUSE_WITHDRAWALS_ROLE = keccak256("PAUSE_WITHDRAWALS_ROLE");
    bytes32 private constant UNPAUSE_WITHDRAWALS_ROLE = keccak256("UNPAUSE_WITHDRAWALS_ROLE");
    bytes32 private constant PAUSE_DEPOSITS_ROLE = keccak256("PAUSE_DEPOSITS_ROLE");
    bytes32 private constant UNPAUSE_DEPOSITS_ROLE = keccak256("UNPAUSE_DEPOSITS_ROLE");
    bytes32 private constant SET_DEPOSIT_WHITELIST_ROLE = keccak256("SET_DEPOSIT_WHITELIST_ROLE");
    bytes32 private constant SET_DEPOSITOR_WHITELIST_STATUS_ROLE =
        keccak256("SET_DEPOSITOR_WHITELIST_STATUS_ROLE");

    // MultiVault roles
    bytes32 private constant ADD_SUBVAULT_ROLE = keccak256("ADD_SUBVAULT_ROLE");
    bytes32 private constant REMOVE_SUBVAULT_ROLE = keccak256("REMOVE_SUBVAULT_ROLE");
    bytes32 private constant SET_STRATEGY_ROLE = keccak256("SET_STRATEGY_ROLE");
    bytes32 private constant SET_FARM_ROLE = keccak256("SET_FARM_ROLE");
    bytes32 private constant REBALANCE_ROLE = keccak256("REBALANCE_ROLE");
    bytes32 private constant SET_DEFAULT_COLLATERAL_ROLE = keccak256("SET_DEFAULT_COLLATERAL_ROLE");
    bytes32 private constant SET_ADAPTER_ROLE = keccak256("SET_ADAPTER_ROLE");

    // RatiosStrategy roles:
    bytes32 private constant RATIOS_STRATEGY_SET_RATIOS_ROLE =
        keccak256("RATIOS_STRATEGY_SET_RATIOS_ROLE");

    bytes32[16] internal roles = [
        DEFAULT_ADMIN_ROLE,
        SET_LIMIT_ROLE,
        PAUSE_WITHDRAWALS_ROLE,
        UNPAUSE_WITHDRAWALS_ROLE,
        PAUSE_DEPOSITS_ROLE,
        UNPAUSE_DEPOSITS_ROLE,
        SET_DEPOSIT_WHITELIST_ROLE,
        SET_DEPOSITOR_WHITELIST_STATUS_ROLE,
        ADD_SUBVAULT_ROLE,
        REMOVE_SUBVAULT_ROLE,
        SET_STRATEGY_ROLE,
        SET_FARM_ROLE,
        REBALANCE_ROLE,
        SET_DEFAULT_COLLATERAL_ROLE,
        SET_ADAPTER_ROLE,
        RATIOS_STRATEGY_SET_RATIOS_ROLE
    ];

    Migrator internal immutable migrator = Migrator(0x37BE38A8Bd5D84DeFA072fFf6c0E1d923e9563EB);
    address internal constant VAULT_ADMIN = 0x9437B2a8cF3b69D782a61f9814baAbc172f72003;
    address internal constant VAULT_PROXY_ADMIN = 0x81698f87C6482bF1ce9bFcfC0F103C4A0Adf0Af0;
    address internal constant STRATEGY = 0x3aA61E6196fb3eb1170E578ad924898624f54ad6;
    address internal constant WSTETH_DEFAULT_COLLATERAL = 0xC329400492c6ff2438472D4651Ad17389fCb843a;
    address internal constant WSTETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;

    struct State {
        address symbioticVault;
        PairAddressBytes32[] permissions;
        uint256 limit;
        uint256 totalSupply;
        uint256 totalAssets;
        address symbioticWithdrawalQueue;
        address defaultCollateral;
        address asset;
    }

    function getCommonState(address vault) public view returns (State memory $) {
        MultiVault vault_ = MultiVault(vault);
        $.limit = vault_.limit();
        $.totalSupply = vault_.totalSupply();
        $.totalAssets = vault_.totalAssets();
        $.asset = vault_.asset();

        uint256 count = 0;
        for (uint256 i = 0; i < roles.length; i++) {
            count += vault_.getRoleMemberCount(roles[i]);
        }
        $.permissions = new PairAddressBytes32[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < roles.length; i++) {
            bytes32 role = roles[i];
            uint256 roleCount = vault_.getRoleMemberCount(role);
            for (uint256 j = 0; j < roleCount; j++) {
                $.permissions[index] =
                    PairAddressBytes32({address_: vault_.getRoleMember(role, j), bytes32_: role});
                index++;
            }
        }
    }

    function loadSimpleLRTState(address vault) public view returns (State memory $) {
        $ = getCommonState(vault);
        $.symbioticVault = IMellowSymbioticVault(vault).symbioticVault();
        $.symbioticWithdrawalQueue = IMellowSymbioticVaultQueue(vault).withdrawalQueue();
        $.defaultCollateral = address(IMellowSymbioticVault(vault).symbioticCollateral());
    }

    function loadMultiVaultState(address vault) public view returns (State memory $) {
        $ = getCommonState(vault);
        MultiVault vault_ = MultiVault(vault);
        $.symbioticVault = vault_.subvaultAt(0).vault;
        $.symbioticWithdrawalQueue = vault_.subvaultAt(0).withdrawalQueue;
        $.defaultCollateral = address(vault_.defaultCollateral());
    }

    function getProxyAdmin(address proxyAddress) public view returns (address) {
        bytes memory proxyCode = address(proxyAddress).code;
        require(proxyCode.length >= 28 + 20, "getProxyAdmin: invalid proxy code length");
        address proxyAdmin;
        assembly {
            proxyAdmin := mload(add(proxyCode, 48))
        }
        return proxyAdmin;
    }

    function getProxyAdminOwner(address proxyAddress) public view returns (address) {
        address proxyAdmin = getProxyAdmin(proxyAddress);
        return ProxyAdmin(proxyAdmin).owner();
    }

    function validateState(
        address vaultAddress,
        address curator,
        State memory before_,
        State memory after_
    ) internal view {
        assertNotEq(vaultAddress, address(0), "validateState: vault address is zero");
        assertTrue(migrator.isEntity(vaultAddress), "validateState: vault is not a migrated entity");
        assertEq(
            getProxyAdminOwner(vaultAddress),
            VAULT_PROXY_ADMIN,
            "validateState: proxy admin owner is not correct"
        );
        MultiVault vault = MultiVault(vaultAddress);
        assertTrue(
            vault.hasRole(DEFAULT_ADMIN_ROLE, VAULT_ADMIN),
            "validateState: vault admin role is not set correctly"
        );
        assertEq(before_.asset, after_.asset, "Asset should not change");
        assertEq(before_.totalSupply, after_.totalSupply, "Total supply should not change");
        assertEq(before_.totalAssets, after_.totalAssets, "Total assets should not change");
        assertEq(
            before_.defaultCollateral,
            after_.defaultCollateral,
            "Default collateral should not change"
        );
        assertEq(before_.symbioticVault, after_.symbioticVault, "Symbiotic vault should not change");
        assertEq(before_.limit, after_.limit, "Limit should not change");
        assertEq(
            before_.permissions.length,
            after_.permissions.length,
            "Permissions length should not change"
        );
        assertEq(
            before_.permissions.length,
            after_.permissions.length,
            "Permissions length should not change"
        );

        for (uint256 i = 0; i < before_.permissions.length; i++) {
            assertEq(
                before_.permissions[i].address_,
                after_.permissions[i].address_,
                "Permission address should not change"
            );
            assertEq(
                before_.permissions[i].bytes32_,
                after_.permissions[i].bytes32_,
                "Permission role should not change"
            );
        }

        assertEq(vault.asset(), WSTETH, "Asset should be WSTETH");
        assertEq(
            address(vault.defaultCollateral()),
            WSTETH_DEFAULT_COLLATERAL,
            "Default collateral should be WSTETH_DEFAULT_COLLATERAL"
        );
        assertEq(vault.subvaultsCount(), 1, "MultiVault should have exactly one subvault");
        assertNotEq(
            address(vault.symbioticAdapter()),
            address(0),
            "MultiVault should have a valid symbiotic adapter"
        );
        assertEq(
            address(vault.eigenLayerAdapter()),
            address(0),
            "MultiVault should not have an EigenLayer adapter"
        );
        assertEq(
            address(vault.erc4626Adapter()),
            address(0),
            "MultiVault should not have an ERC4626 adapter"
        );
        assertEq(
            uint256(vault.subvaultAt(0).protocol),
            uint256(0),
            "Subvault protocol should be set to 0 (Symbiotic)"
        );

        {
            IVault symbioticVault = IVault(vault.subvaultAt(0).vault);
            IAccessControl delegator = IAccessControl(symbioticVault.delegator());
            assertTrue(
                delegator.hasRole(keccak256("NETWORK_LIMIT_SET_ROLE"), curator),
                "curator should have NETWORK_LIMIT_SET_ROLE"
            );
            assertTrue(
                delegator.hasRole(keccak256("OPERATOR_NETWORK_SHARES_SET_ROLE"), curator),
                "curator should have OPERATOR_NETWORK_SHARES_SET_ROLE"
            );

            address burner = symbioticVault.burner();
            assertEq(Ownable(burner).owner(), VAULT_ADMIN, "Burner owner should be VAULT_ADMIN");
            assertTrue(
                IAccessControl(address(symbioticVault)).hasRole(0x00, VAULT_ADMIN),
                "VAULT_ADMIN should have DEFAULT_ADMIN_ROLE in symbiotic vault"
            );

            address owner = Ownable(address(symbioticVault)).owner();
            if (owner != VAULT_PROXY_ADMIN) {
                assertTrue(
                    ISafe(owner).getThreshold() == 1
                        && ISafe(owner).getOwners()[0] == VAULT_PROXY_ADMIN,
                    "Owner should be a Safe with VAULT_PROXY_ADMIN as the only owner"
                );
            } else {
                assertTrue(
                    Ownable(address(symbioticVault)).owner() == VAULT_PROXY_ADMIN,
                    "Owner should be VAULT_PROXY_ADMIN in symbiotic vault"
                );
            }
        }
    }
}
