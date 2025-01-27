// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../src/MellowVaultCompat.sol";
import "../../src/SymbioticWithdrawalQueue.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
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

contract CompletionMigrationTest is Test {
    address constant IMPLEMENTATION_AFTER = 0x09bBa67C316e59840699124a8DC0bBDa6A2A9d59;
    bytes32 constant INITIALIZABLE_STORAGE =
        0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00;
    address constant INITIALIZER_ADDRESS = 0x39c62c6308BeD7B0832CAfc2BeA0C0eDC7f2060c;
    address constant DEPLOYER_ADDRESS = 0x188858AC61a74350116d1CB6958fBc509FD6afA1;

    uint256 public PARIS_BYTECODE_LENGTH = 1106;
    uint256 public SHANGHAI_BYTECODE_LENGTH = 1076;
    uint256 public CANCUN_BYTECODE_LENGTH = 1054;

    bytes32 constant EXPECTED_BYTECODE_HASH_PARIS =
        0x86bf442f4c724643a9602773f67abcd9c70db7092034d0e50ed084ec0bbdb1ba;
    bytes32 constant EXPECTED_BYTECODE_HASH_SHANGHAI =
        0xf0fef8f69bb49cd2a13055d413f2497fb1a5b3c3284d1cacab63d98a480c3858;
    bytes32 constant EXPECTED_BYTECODE_HASH_CANCUN =
        0xc8e791180744f196d2b9a58347a369f3b513f698e458effd4246864fae0c6ac0;

    address constant WSTETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address constant SYMBIOTIC_VAULT_FACTORY = 0xAEb6bdd95c502390db8f52c8909F703E9Af6a346;
    address constant SYMBIOTIC_DELEGATOR_FACTORY = 0x985Ed57AF9D475f1d83c1c1c8826A0E5A34E8C7B;
    address constant SYMBIOTIC_SLASHER_FACTORY = 0x685c2eD7D59814d2a597409058Ee7a92F21e48Fd;
    address constant SYMBIOTIC_BURNER_FACTORY = 0x99F2B89fB3C363fBafD8d826E5AA77b28bAB70a0;

    uint64 constant DELEGATOR_TYPE = 0;
    uint64 constant SLASHER_TYPE = 1;

    address constant VAULT_ADMIN_MULTISIG = 0x9437B2a8cF3b69D782a61f9814baAbc172f72003;
    address constant VAULT_PROXY_ADMIN_MULTISIG = 0x81698f87C6482bF1ce9bFcfC0F103C4A0Adf0Af0;

    uint256 VAULT_INDEX = 0;

    address[18] VAULTS = [
        // 0 batch
        0x7b31F008c48EFb65da78eA0f255EE424af855249, // roETH
        // 1 batch
        0xBEEF69Ac7870777598A04B2bd4771c71212E6aBc, // steakLRT
        0x84631c0d0081FDe56DeB72F6DE77abBbF6A9f93a, // Re7LRT
        0x5fD13359Ba15A84B76f7F87568309040176167cd, // amphrETH
        0x8c9532a60E0E7C6BbD2B2c1303F63aCE1c3E9811, // pzETH
        // 2 batch
        0x49cd586dd9BA227Be9654C735A659a1dB08232a9, // ifsETH
        0x82dc3260f599f4fC4307209A1122B6eAa007163b, // LugaETH
        0xd6E09a5e6D719d1c881579C9C8670a210437931b, // coETH
        0x4f3Cc6359364004b245ad5bE36E6ad4e805dC961, // urLRT
        0x375A8eE22280076610cA2B4348d37cB1bEEBeba0, // hcETH
        0xcC36e5272c422BEE9A8144cD2493Ac472082eBaD, // isETH
        // 2.5 batch
        0x82f5104b23FF2FA54C2345F821dAc9369e9E0B26, // rsUSDe
        0xc65433845ecD16688eda196497FA9130d6C47Bd8, // rsENA
        0x7F43fDe12A40dE708d908Fb3b9BFB8540d9Ce444, // Re7rwBTC
        0x64047dD3288276d70A4F8B5Df54668c8403f877F, // amphrBTC
        0x3a828C183b3F382d030136C824844Ea30145b4c7, // Re7rtBTC
        // 3 batch
        0x7a4EffD87C2f3C55CA251080b1343b605f327E3a, // rstETH
        // 4 batch
        0x5E362eb2c0706Bd1d134689eC75176018385430B // DVstETH
    ];

    address[18] CURATORS = [
        // 0 batch
        0xf9d20f02aB533ac6F990C9D96B595651d83b4b92, // roETH
        // 1 batch
        0x2E93913A796a6C6b2bB76F41690E78a2E206Be54, // steakLRT
        0xE86399fE6d7007FdEcb08A2ee1434Ee677a04433, // Re7LRT
        0xA1E38210B06A05882a7e7Bfe167Cd67F07FA234A, // amphrETH
        0x6e5CaD73D00Bc8340f38afb61Fc5E34f7193F599, // pzETH
        // 2 batch
        address(0), // ifsETH
        address(0), // LugaETH
        address(0), // coETH
        address(0), // urLRT
        address(0), // hcETH
        address(0), // isETH
        // 2.5 batch
        address(0), // rsUSDe
        address(0), // rsENA
        address(0), // Re7rwBTC
        address(0), // amphrBTC
        address(0), // Re7rtBTC
        // 3 batch
        0xE86399fE6d7007FdEcb08A2ee1434Ee677a04433, // rstETH
        // 4 batch
        address(0) // DVstETH
    ];

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

    function testCompletionMigrationTest() external virtual {
        validateProxyBytecodes();

        MellowVaultCompat vault = MellowVaultCompat(VAULTS[VAULT_INDEX]);
        ISymbioticVault symbioticVault = vault.symbioticVault();
        ISymbioticWithdrawalQueue queue =
            ISymbioticWithdrawalQueue(address(vault.withdrawalQueue()));

        validateVaultState(vault);
        validateSymbioticVaultState(vault, symbioticVault);
        validateSymbioticWithdrawalQueueState(vault, symbioticVault, queue);
    }

    function validateVaultState(MellowVaultCompat vault) public view {
        require(vault.getRoleMemberCount(vault.DEFAULT_ADMIN_ROLE()) == 1, "unexpected admin count");
        address vaultAdmin = vault.getRoleMember(vault.DEFAULT_ADMIN_ROLE(), 0);
        require(vaultAdmin == VAULT_ADMIN_MULTISIG, "unexpected admin");
        address proxyAdmin =
            address(uint160(uint256(vm.load(address(vault), ERC1967Utils.ADMIN_SLOT))));

        address implementation =
            address(uint160(uint256(vm.load(address(vault), ERC1967Utils.IMPLEMENTATION_SLOT))));
        require(implementation == IMPLEMENTATION_AFTER, "unexpected implementation");

        require(Ownable(proxyAdmin).owner() == VAULT_PROXY_ADMIN_MULTISIG, "unexpected proxy admin");
        require(vault.asset() == WSTETH, "vault asset is not WSTETH");

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
            router.delay() == 1 hours,
            "unexpected delay for setting a new receiver or changing the delay itself"
        );

        require(
            router.globalReceiver() == CURATORS[VAULT_INDEX],
            "unexpected global receiver of the slashed funds"
        );

        require(router.collateral() == WSTETH, "unexpected router's underlying collateral");

        console2.log(
            "WARN: Burner router delay is set to 1 hour. MUST be set to at least vaultEpoch"
        );

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
        require(queue.collateral() == WSTETH, "unexpected collateral");
        require(queue.getCurrentEpoch() == symbioticVault.currentEpoch(), "unexpected epoch");
        require(queue.pendingAssets() == 0, "unexpected pending assets");
    }
}
