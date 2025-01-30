// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../src/MellowVaultCompat.sol";
import "../../src/SymbioticWithdrawalQueue.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {IBurnerRouter} from "@symbiotic/burners/interfaces/router/IBurnerRouter.sol";
import {INetworkRestakeDelegator} from
    "@symbiotic/core/interfaces/delegator/INetworkRestakeDelegator.sol";
import {IVetoSlasher} from "@symbiotic/core/interfaces/slasher/IVetoSlasher.sol";
import "forge-std/Test.sol";

interface ISafe {
    function getOwners() external view returns (address[] memory);
}

interface ISymbioticFactory {
    function isEntity(address entity) external view returns (bool);
}

import "../../src/Migrator.sol";

contract CompletionMigrationTest is Test {
    address constant IMPLEMENTATION_AFTER = 0x09bBa67C316e59840699124a8DC0bBDa6A2A9d59;
    bytes32 constant INITIALIZABLE_STORAGE =
        0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00;
    address constant INITIALIZER_ADDRESS = 0x39c62c6308BeD7B0832CAfc2BeA0C0eDC7f2060c;
    address constant DEPLOYER_ADDRESS = 0x188858AC61a74350116d1CB6958fBc509FD6afA1;

    uint256 constant PARIS_BYTECODE_LENGTH = 1106;
    uint256 constant SHANGHAI_BYTECODE_LENGTH = 1076;
    uint256 constant CANCUN_BYTECODE_LENGTH = 1054;

    bytes32 constant EXPECTED_BYTECODE_HASH_PARIS =
        0x86bf442f4c724643a9602773f67abcd9c70db7092034d0e50ed084ec0bbdb1ba;
    bytes32 constant EXPECTED_BYTECODE_HASH_SHANGHAI =
        0xf0fef8f69bb49cd2a13055d413f2497fb1a5b3c3284d1cacab63d98a480c3858;
    bytes32 constant EXPECTED_BYTECODE_HASH_CANCUN =
        0xc8e791180744f196d2b9a58347a369f3b513f698e458effd4246864fae0c6ac0;

    address constant SUSDE = 0x9D39A5DE30e57443BfF2A8307A4256c8797A3497;
    address constant ENA = 0x57e114B691Db790C35207b2e685D4A43181e6061;
    address constant SYMBIOTIC_VAULT_FACTORY = 0xAEb6bdd95c502390db8f52c8909F703E9Af6a346;
    address constant SYMBIOTIC_DELEGATOR_FACTORY = 0x985Ed57AF9D475f1d83c1c1c8826A0E5A34E8C7B;
    address constant SYMBIOTIC_SLASHER_FACTORY = 0x685c2eD7D59814d2a597409058Ee7a92F21e48Fd;
    address constant SYMBIOTIC_BURNER_FACTORY = 0x99F2B89fB3C363fBafD8d826E5AA77b28bAB70a0;

    uint64 constant DELEGATOR_TYPE = 0;
    uint64 constant SLASHER_TYPE = 1;

    address constant VAULT_ADMIN_MULTISIG = 0xa5136542ECF3dCAFbb3bd213Cd7024B4741dBDE6;
    address constant VAULT_PROXY_ADMIN_MULTISIG = 0x27a907d1F809E8c03d806Dc31c8E0C545A3187fC;

    address constant DEAD_BURNER = address(0xdead);

    uint256 VAULT_INDEX = 0;

    address[2] VAULTS =
        [0x82f5104b23FF2FA54C2345F821dAc9369e9E0B26, 0xc65433845ecD16688eda196497FA9130d6C47Bd8];

    address[2] CURATORS =
        [0x9389477cf0a0C13ad0eE54f35587C9d7d121B231, 0x9389477cf0a0C13ad0eE54f35587C9d7d121B231];

    function verifiyProxyBytecode(address x) public view returns (bytes memory proxy_) {
        proxy_ = x.code;
        uint256 proxyAdmin_;
        uint256 offset = 28;
        for (uint256 i = 0; i < 20; i++) {
            proxyAdmin_ = (proxyAdmin_ << 8) + uint8(proxy_[i + offset]);
            proxy_[i + offset] = bytes1(0);
        }
        require(
            uint256(vm.load(x, ERC1967Utils.ADMIN_SLOT)) == proxyAdmin_, "proxy admin slot mismatch"
        );
        // 53 bytes for metadata
        if (proxy_.length == PARIS_BYTECODE_LENGTH + 53) {
            // paris
            uint256 length = PARIS_BYTECODE_LENGTH;
            assembly {
                mstore(proxy_, length)
            }
            require(keccak256(proxy_) == EXPECTED_BYTECODE_HASH_PARIS, "unexpected bytecode");
        } else if (proxy_.length == SHANGHAI_BYTECODE_LENGTH + 53) {
            // shanghai
            uint256 length = SHANGHAI_BYTECODE_LENGTH;
            assembly {
                mstore(proxy_, length)
            }
            require(keccak256(proxy_) == EXPECTED_BYTECODE_HASH_SHANGHAI, "unexpected bytecode");
        } else if (proxy_.length == CANCUN_BYTECODE_LENGTH + 53) {
            uint256 length = CANCUN_BYTECODE_LENGTH;
            assembly {
                mstore(proxy_, length)
            }
            require(keccak256(proxy_) == EXPECTED_BYTECODE_HASH_CANCUN, "unexpected bytecode");
        } else {
            revert("unknown bytecode length");
        }
    }

    function validateProxyBytecodes() public {
        // verification of all deployed vaults, including DVV + non-wsteth vaults.
        for (uint256 i = 0; i < VAULTS.length; i++) {
            verifiyProxyBytecode(VAULTS[i]);
        }
        // verification of new fresh deployment
        verifiyProxyBytecode(
            address(
                new TransparentUpgradeableProxy(INITIALIZER_ADDRESS, DEPLOYER_ADDRESS, new bytes(0))
            )
        );
    }

    function commitPhase(address vault) public {
        Migrator migrator = Migrator(0x89217e645D072dBf0c353809D0CE054cb3045a98);
        vm.startPrank(VAULT_PROXY_ADMIN_MULTISIG);
        ProxyAdmin proxyAdmin =
            ProxyAdmin(address(uint160(uint256(vm.load(vault, ERC1967Utils.ADMIN_SLOT)))));
        proxyAdmin.transferOwnership(address(migrator));
        migrator.migrate(vault);
        vm.stopPrank();
    }

    function completionPhase(MellowVaultCompat vault) public {
        vm.startPrank(VAULT_ADMIN_MULTISIG);

        vault.symbioticVault().setDepositorWhitelistStatus(address(vault), true);
        IBurnerRouter(vault.symbioticVault().burner()).setNetworkReceiver(
            0x9101eda106A443A0fA82375936D0D1680D5a64F5, 0xD5881f91270550B8850127f05BD6C8C203B3D33f
        );
        IBurnerRouter(vault.symbioticVault().burner()).setDelay(15 days);
        vault.grantRole(keccak256("UNPAUSE_DEPOSITS_ROLE"), VAULT_ADMIN_MULTISIG);
        vault.grantRole(keccak256("UNPAUSE_WITHDRAWALS_ROLE"), VAULT_ADMIN_MULTISIG);
        vault.unpauseDeposits();
        vault.unpauseWithdrawals();
        vm.stopPrank();
        skip(2 hours);
        IBurnerRouter(vault.symbioticVault().burner()).acceptDelay();
    }

    function testCompletionMigrationTestEthena() external virtual {
        validateProxyBytecodes();

        MellowVaultCompat vault = MellowVaultCompat(VAULTS[VAULT_INDEX]);
        commitPhase(address(vault));
        completionPhase(vault);

        address asset = VAULT_INDEX == 0 ? SUSDE : ENA;
        ISymbioticVault symbioticVault = vault.symbioticVault();
        ISymbioticWithdrawalQueue queue =
            ISymbioticWithdrawalQueue(address(vault.withdrawalQueue()));

        validateVaultState(vault, asset);
        validateSymbioticVaultState(vault, symbioticVault);
        validateSymbioticWithdrawalQueueState(vault, symbioticVault, queue);
    }

    function validateVaultState(MellowVaultCompat vault, address asset) public view {
        require(vault.getRoleMemberCount(vault.DEFAULT_ADMIN_ROLE()) == 1, "unexpected admin count");
        address vaultAdmin = vault.getRoleMember(vault.DEFAULT_ADMIN_ROLE(), 0);
        require(vaultAdmin == VAULT_ADMIN_MULTISIG, "unexpected admin");
        address proxyAdmin =
            address(uint160(uint256(vm.load(address(vault), ERC1967Utils.ADMIN_SLOT))));

        address implementation =
            address(uint160(uint256(vm.load(address(vault), ERC1967Utils.IMPLEMENTATION_SLOT))));
        require(implementation == IMPLEMENTATION_AFTER, "unexpected implementation");

        require(Ownable(proxyAdmin).owner() == VAULT_PROXY_ADMIN_MULTISIG, "unexpected proxy admin");
        require(vault.asset() == asset, "vault asset is not an expected asset");

        string[8] memory roles = [
            "SET_FARM_ROLE",
            "SET_LIMIT_ROLE",
            "PAUSE_WITHDRAWALS_ROLE",
            "UNPAUSE_WITHDRAWALS_ROLE",
            "PAUSE_DEPOSITS_ROLE",
            "UNPAUSE_DEPOSITS_ROLE",
            "SET_DEPOSIT_WHITELIST_ROLE",
            "SET_DEPOSITOR_WHITELIST_STATUS_ROLE"
        ];

        for (uint256 i = 0; i < 8; i++) {
            bytes32 role = keccak256(abi.encodePacked(roles[i]));
            uint256 count = vault.getRoleMemberCount(role);
            if (count == 0) {
                console2.log("role", roles[i], "is empty");
            } else {
                require(
                    vault.getRoleMember(role, 0) == VAULT_ADMIN_MULTISIG, "unexpected role member"
                );
            }
        }

        IDefaultCollateral collateral = vault.symbioticCollateral();

        require(address(collateral) != address(0), "collateral not set");
        require(collateral.asset() == vault.asset(), "collateral asset mismatch");
        require(address(vault.symbioticVault()) != address(0), "symbiotic vault not set");
        require(address(vault.withdrawalQueue()) != address(0), "withdrawal queue not set");
        require(vault.symbioticFarmCount() == 0, "unexpected farm count");

        if (vault.depositPause()) {
            console2.log("WARN: Deposits are currently paused. MUST be unpaused.");
        }
        if (vault.withdrawalPause()) {
            console2.log("WARN: Withdrawals are currently paused. MUST be unpaused.");
        }
        if (vault.limit() == 0) {
            console2.log("WARN: limit is 0. MUST be set to non-zero value.");
        }
        if (vault.depositWhitelist()) {
            console2.log("WARN: deposit whitelist enabled.");
        }
    }

    function validateSymbioticVaultState(MellowVaultCompat vault, ISymbioticVault symbioticVault)
        public
        view
    {
        require(
            ISymbioticFactory(SYMBIOTIC_VAULT_FACTORY).isEntity(address(symbioticVault)),
            "symbiotic vault not registered"
        );
        address owner = Ownable(address(symbioticVault)).owner();
        require(
            owner == VAULT_PROXY_ADMIN_MULTISIG
                || ISafe(owner).getOwners().length == 1
                    && ISafe(owner).getOwners()[0] == VAULT_PROXY_ADMIN_MULTISIG,
            "unexpected symbiotic vault owner"
        );

        require(symbioticVault.collateral() == vault.asset(), "symbiotic vault collateral mismatch");
        require(symbioticVault.delegator() != address(0), "symbiotic vault delegator not set");
        require(
            ISymbioticFactory(SYMBIOTIC_DELEGATOR_FACTORY).isEntity(symbioticVault.delegator()),
            "symbiotic delegator not registered"
        );
        require(symbioticVault.isDepositLimit(), "symbiotic vault deposit limit is not enabled");

        INetworkRestakeDelegator delegator = INetworkRestakeDelegator(symbioticVault.delegator());
        require(delegator.TYPE() == DELEGATOR_TYPE, "unexpected delegator type");

        require(delegator.hook() == address(0), "unexpected delegator hook");
        require(delegator.vault() == address(symbioticVault), "unexpected delegator vault");

        //     networkLimitSetRoleHolders: _createArray(curator),
        //     operatorNetworkSharesSetRoleHolders: _createArray(curator)
        require(
            IAccessControl(address(delegator)).hasRole(0x00, VAULT_ADMIN_MULTISIG),
            "missing default admin role holder"
        );
        require(
            !IAccessControl(address(delegator)).hasRole(0x00, CURATORS[VAULT_INDEX]),
            "unexpected curator role holder"
        );

        require(
            IAccessControl(address(delegator)).hasRole(
                delegator.HOOK_SET_ROLE(), VAULT_ADMIN_MULTISIG
            ),
            "missing default admin role holder"
        );
        require(
            !IAccessControl(address(delegator)).hasRole(
                delegator.HOOK_SET_ROLE(), CURATORS[VAULT_INDEX]
            ),
            "unexpected curator role holder"
        );

        require(
            !IAccessControl(address(delegator)).hasRole(
                delegator.NETWORK_LIMIT_SET_ROLE(), VAULT_ADMIN_MULTISIG
            ),
            "unexpected network limit setter role holder"
        );
        require(
            IAccessControl(address(delegator)).hasRole(
                delegator.NETWORK_LIMIT_SET_ROLE(), CURATORS[VAULT_INDEX]
            ),
            "missing network limit setter role holder"
        );

        require(
            !IAccessControl(address(delegator)).hasRole(
                delegator.OPERATOR_NETWORK_SHARES_SET_ROLE(), VAULT_ADMIN_MULTISIG
            ),
            "unexpected operator network shares setter role holder"
        );
        require(
            IAccessControl(address(delegator)).hasRole(
                delegator.OPERATOR_NETWORK_SHARES_SET_ROLE(), CURATORS[VAULT_INDEX]
            ),
            "missing operator network shares setter role holder"
        );

        require(symbioticVault.burner() != address(0), "symbiotic vault burner not set");
        require(
            ISymbioticFactory(SYMBIOTIC_BURNER_FACTORY).isEntity(symbioticVault.burner()),
            "symbiotic burner not registered"
        );

        IBurnerRouter router = IBurnerRouter(symbioticVault.burner());
        require(
            router.delay() == 15 days,
            "unexpected delay for setting a new receiver or changing the delay itself"
        );

        require(
            router.globalReceiver() == DEAD_BURNER,
            "unexpected global receiver of the slashed funds"
        );

        require(router.collateral() == vault.asset(), "unexpected router's underlying collateral");

        if (router.delay() < 15 days) {
            console2.log(
                "WARN: Burner router delay is set to %s hours. MUST be set to at least vaultEpoch * 2 + 24 hours",
                router.delay() / 1 hours
            );
        }

        require(symbioticVault.slasher() != address(0), "symbiotic vault slasher not set");
        require(
            ISymbioticFactory(SYMBIOTIC_SLASHER_FACTORY).isEntity(symbioticVault.slasher()),
            "symbiotic slasher not registered"
        );
        IVetoSlasher slasher = IVetoSlasher(symbioticVault.slasher());
        require(slasher.TYPE() == SLASHER_TYPE, "unexpected slasher type");

        require(slasher.vetoDuration() == 3 days, "unexpected duration of the veto period");

        require(slasher.slashRequestsLength() == 0, "unexpected total number of slash requests");

        require(
            slasher.resolverSetEpochsDelay() == 3,
            "unexpected delay for networks in epochs to update a resolver"
        );
    }

    function validateSymbioticWithdrawalQueueState(
        MellowVaultCompat vault,
        ISymbioticVault symbioticVault,
        ISymbioticWithdrawalQueue queue
    ) public view {
        require(address(queue) != address(0), "withdrawal queue not set");
        require(address(queue.vault()) == address(vault), "unexpected vault");
        require(
            address(queue.symbioticVault()) == address(symbioticVault), "unexpected symbiotic vault"
        );
        require(queue.collateral() == vault.asset(), "unexpected collateral");
        require(queue.getCurrentEpoch() == symbioticVault.currentEpoch(), "unexpected epoch");
        require(queue.pendingAssets() == 0, "unexpected pending assets");
    }
}
