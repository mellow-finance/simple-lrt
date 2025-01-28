// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../scripts/mainnet/MigrationDeploy.sol";
import "../BaseTest.sol";
import "../Constants.sol";
import "./AcceptanceMigrationRunner.sol";

import "./CompletionMigrationTest.t.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract FullMigrationTest is CompletionMigrationTest {
    /// docs: https://www.notion.so/mellowprotocol/Batch-1-migration-process-e44305f5c2c84a23a538843991d2a3d0#e77f95c1f81742dcb304c6d1850d7b99

    Migrator migrator = Migrator(0x643ED3c06E19A96EaBCBC32C2F665DB16282bEaB);
    address vaultAdminMultisig = 0x9437B2a8cF3b69D782a61f9814baAbc172f72003;
    address vaultProxyAdminMultisig = 0x81698f87C6482bF1ce9bFcfC0F103C4A0Adf0Af0;
    address wsteth = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address defaultCollateralWstETH = 0xC329400492c6ff2438472D4651Ad17389fCb843a;

    address IMPLEMENTATION_BEFORE = 0xaf108ae0AD8700ac41346aCb620e828c03BB8848;
    bytes32 ADMIN_DELEGATE_ROLE = keccak256("admin_delegate");
    bytes32 OPERATOR = keccak256("operator");

    struct Setup {
        string name;
        string symbol;
        address expectedSymbioticWithdrawalQueue;
        address symbioticVault;
        address strategy;
        address proxyAdmin;
        bool isPendingState;
    }

    function testCompletionMigrationTest() external override {
        Setup[12] memory setups = [
            Setup("Rockmelon ETH", "roETH", address(0), address(0), address(0), address(0), false),
            Setup(
                "Steakhouse Resteaking Vault",
                "steakLRT",
                0xC915FADA26dc6c123620A9c2a7a55c1ad45b077A,
                0xf7Ce770AbdD1895f2CB0989D7cf2A26705FF37a7,
                0x7a14b34a9a8EA235C66528dc3bF3aeFC36DFc268,
                0xed792a3fDEB9044C70c951260AaAe974Fb3dB38F,
                true
            ),
            Setup(
                "Re7 Labs LRT",
                "Re7LRT",
                0x9668bd17947b2baD83857a75737faF17575628B8,
                0x3D93b33f5E5fe74D54676720e70EA35210cdD46E,
                0xcE3A8820265AD186E8C1CeAED16ae97176D020bA,
                0xF076CF343DCfD01BBA57dFEB5C74F7B015951fcF,
                true
            ),
            Setup(
                "Amphor Restaked ETH",
                "amphrETH",
                0x2142acB6b0424578d443A4b2E396a1b7cFb5c1e9,
                0x446970400e1787814CA050A4b45AE9d21B3f7EA7,
                0xc3A149b5Ca3f4A5F17F5d865c14AA9DBb570F10A,
                0xc24891B75ef55fedC377c5e6Ec59A850b12E23ac,
                true
            ),
            Setup(
                "Renzo Restaked LST ",
                "pzETH",
                0xcDbff91f6fCcDa7367d71b065c7494526b830A89,
                0xa88e91cEF50b792f9449e2D4C699b6B3CcE1D19F,
                0xE8206Fbf2D9F9E7fbf2F7b997E20a34f9158cC14,
                0x985E459801d37749C331BBd2673B665b9114fB01,
                true
            ),
            Setup(
                "Restaking Vault ETH",
                "rstETH",
                0x351875e6348120b71281808870435bF6d5F406BD,
                0x7b276aAD6D2ebfD7e270C5a2697ac79182D9550E,
                0xA0ea6d4fe369104eD4cc18951B95C3a43573C0F6,
                0x17AC6A90eD880F9cE54bB63DAb071F2BD3FE3772,
                true
            ),
            Setup(
                "Chorus One Restaking Vault ETH",
                "coETH",
                0x351875e6348120b71281808870435bF6d5F406BD,
                0x7154633EdA7569021e5b1cfCbf953715F8775CA8,
                0xE73C97e07dF948A046505f8c63c4B54D632D4972,
                0x0375178C4D752b3ae35D806c6bB60D07faECbA5E,
                true
            ),
            Setup(
                "HashKey Cloud Restaked ETH",
                "hcETH",
                0x351875e6348120b71281808870435bF6d5F406BD,
                0x108784D6B93A010f62b652b2356697dAEF3D7341,
                0x398fDbC08D2D01FEF44dDF44FC22F992bd2C320A,
                0xFFad6500aF7814540C27EA73d45F125F5fBebAE3,
                true
            ),
            Setup(
                "InfStones Restaked ETH",
                "ifsETH",
                0x351875e6348120b71281808870435bF6d5F406BD,
                0x08144D10f6Aaa152EA88a99072a659E339d6152f,
                0x20ad4d9bbbBBeE7d3abA91558a02c17c3387b834,
                0xD09b3193bB71B98027dd0f1a34eeAebd04b2e47c,
                true
            ),
            Setup(
                "LugaETH",
                "LugaETH",
                0x351875e6348120b71281808870435bF6d5F406BD,
                0x48bef6aB76E31737d94cF7b3B1dba52EDDEe1cAd,
                0xa80575b793aabD32EDb39759c975534D75a4A2A4,
                0x3c1C6A3e94Bc607ac947D4520e2E9161a4183D4D,
                true
            ),
            Setup(
                "unified restaked LRT",
                "urLRT",
                0x351875e6348120b71281808870435bF6d5F406BD,
                0xf890434A395e3978622Ac0ae1412934bEfeB09Ff,
                0x65fFC47625200A358f5Cdf7103E6D936EcF1a7D5,
                0x75a7fB388A38E12747D147fD8d38Bbc5Bb860Cf3,
                true
            ),
            Setup(
                "InfraSingularity Restaked ETH",
                "isETH",
                0x351875e6348120b71281808870435bF6d5F406BD,
                0xbA91473072EBD125C3cB8D251fd02bf21FDea8Df,
                0x8e48Cf252Ec9E62AAAD881165674cb7403e7Ce6C,
                0xCF4E33Ae47fE9C5d6390c1868B6aBB068e1e40Ec,
                true
            )
        ];

        VAULT_INDEX = 5;
        address vault = VAULTS[VAULT_INDEX];
        string memory name = setups[VAULT_INDEX].name;
        string memory symbol = setups[VAULT_INDEX].symbol;
        address expectedSymbioticWithdrawalQueue =
            setups[VAULT_INDEX].expectedSymbioticWithdrawalQueue;
        address symbioticVault = setups[VAULT_INDEX].symbioticVault;
        address strategy = setups[VAULT_INDEX].strategy;
        address proxyAdmin = setups[VAULT_INDEX].proxyAdmin;
        bool isPendingState = setups[VAULT_INDEX].isPendingState;

        assertEq(migrator.singleton(), IMPLEMENTATION_AFTER, "Invalid singleton implementation");

        IMellowLRT.ProcessWithdrawalsStack memory stack;
        console2.log("VAULT_INDEX:", VAULT_INDEX);
        // stage phase:
        {
            if (!isPendingState) {
                assertEq(migrator.timestamps(vault), 0, "Migration already started");
                IMigrator.Parameters memory emptyParams;
                assertEq(
                    keccak256(abi.encode(migrator.migration(vault))),
                    keccak256(abi.encode(emptyParams)),
                    "Migration already started"
                );
                IMellowSymbioticVault.InitParams memory emptyInitParams;
                assertEq(
                    keccak256(abi.encode(migrator.vaultInitParams(vault))),
                    keccak256(abi.encode(emptyInitParams)),
                    "Migration already started"
                );

                // stage.2:
                vm.startPrank(vaultProxyAdminMultisig);
                migrator.stageMigration(strategy, vaultAdminMultisig, proxyAdmin, symbioticVault);
                vm.stopPrank();
                assertEq(migrator.timestamps(vault), block.timestamp, "Invalid timestamp");
            }

            {
                IMigrator.Parameters memory expectedParams = IMigrator.Parameters({
                    proxyAdmin: proxyAdmin,
                    proxyAdminOwner: vaultProxyAdminMultisig,
                    token: wsteth,
                    bond: defaultCollateralWstETH,
                    defaultBondStrategy: strategy
                });
                assertEq(
                    keccak256(abi.encode(migrator.migration(vault))),
                    keccak256(abi.encode(expectedParams)),
                    "invalid migration params"
                );

                IMellowSymbioticVault.InitParams memory expectedVaultInitParams =
                IMellowSymbioticVault.InitParams({
                    limit: 0,
                    symbioticCollateral: defaultCollateralWstETH,
                    symbioticVault: symbioticVault,
                    withdrawalQueue: expectedSymbioticWithdrawalQueue,
                    admin: vaultAdminMultisig,
                    depositPause: true,
                    withdrawalPause: true,
                    depositWhitelist: false,
                    name: name,
                    symbol: symbol
                });
                assertEq(
                    keccak256(abi.encode(migrator.vaultInitParams(vault))),
                    keccak256(abi.encode(expectedVaultInitParams)),
                    "invalid vault init params"
                );
            }

            if (!isPendingState) {
                assertFalse(
                    IAccessControl(strategy).hasRole(OPERATOR, address(migrator)),
                    "Operator role already granted"
                );

                // stage.3:
                vm.startPrank(vaultAdminMultisig);
                if (!IAccessControl(strategy).hasRole(ADMIN_DELEGATE_ROLE, vaultAdminMultisig)) {
                    IAccessControl(strategy).grantRole(ADMIN_DELEGATE_ROLE, vaultAdminMultisig);
                }
                IAccessControl(strategy).grantRole(OPERATOR, address(migrator));
                vm.stopPrank();
            }

            {
                assertTrue(
                    IAccessControl(strategy).hasRole(ADMIN_DELEGATE_ROLE, vaultAdminMultisig),
                    "Admin delegate role not granted"
                );
                assertTrue(
                    IAccessControl(strategy).hasRole(OPERATOR, address(migrator)),
                    "Operator role not granted"
                );
            }
        }

        skip(migrator.migrationDelay());

        // commit phase:
        {
            // commit.1:
            vm.startPrank(vaultAdminMultisig);
            IDefaultBondStrategy(strategy).processAll();
            vm.stopPrank();

            stack = IMellowLRT(vault).calculateStack();

            {
                assertEq(
                    IMellowLRT(vault).pendingWithdrawersCount(),
                    0,
                    "Pending withdrawals not processed"
                );
            }

            {
                assertEq(
                    ProxyAdmin(proxyAdmin).owner(),
                    vaultProxyAdminMultisig,
                    "Invalid proxy admin owner"
                );
            }

            // commit.2:
            {
                vm.startPrank(vaultProxyAdminMultisig);
                ProxyAdmin(proxyAdmin).transferOwnership(address(migrator));
                vm.stopPrank();
            }

            {
                assertEq(
                    ProxyAdmin(proxyAdmin).owner(), address(migrator), "Invalid proxy admin owner"
                );
            }

            uint256 entitiesLength = migrator.entitiesLength();
            {
                assertFalse(migrator.isEntity(vault), "Entity already exists");

                address implementationBefore =
                    address(uint160(uint256(vm.load(vault, ERC1967Utils.IMPLEMENTATION_SLOT))));

                assertEq(
                    implementationBefore, IMPLEMENTATION_BEFORE, "Invalid implementation before"
                );

                bytes32 initialization = vm.load(vault, INITIALIZABLE_STORAGE);
                assertEq(
                    initialization, bytes32(0), "Invalid initialization storage before migration"
                );
            }

            // commit.3:
            {
                vm.startPrank(vaultProxyAdminMultisig);
                migrator.migrate(vault);
                vm.stopPrank();
            }

            {
                assertEq(migrator.entitiesLength(), entitiesLength + 1, "Invalid entities length");
                assertTrue(migrator.isEntity(vault), "Entity not exists");

                address implementationAfter =
                    address(uint160(uint256(vm.load(vault, ERC1967Utils.IMPLEMENTATION_SLOT))));

                assertEq(implementationAfter, IMPLEMENTATION_AFTER, "Invalid implementation after");
                bytes32 initialization = vm.load(vault, INITIALIZABLE_STORAGE);
                assertEq(
                    initialization,
                    bytes32(uint256(1)),
                    "Invalid initialization storage after migration"
                );

                MellowVaultCompat c = MellowVaultCompat(vault);
                assertEq(c.asset(), wsteth, "Invalid asset after migration");
                assertEq(
                    address(c.symbioticVault()),
                    symbioticVault,
                    "Invalid symbiotic vault after migration"
                );
                assertEq(
                    address(c.withdrawalQueue()),
                    expectedSymbioticWithdrawalQueue,
                    "Invalid withdrawal queue after migration"
                );
                assertTrue(
                    c.hasRole(c.DEFAULT_ADMIN_ROLE(), vaultAdminMultisig),
                    "Invalid admin after migration"
                );
                assertEq(
                    c.getRoleMemberCount(c.DEFAULT_ADMIN_ROLE()),
                    1,
                    "Invalid admin count after migration"
                );

                bytes32[8] memory roles = [
                    keccak256("SET_FARM_ROLE"),
                    keccak256("SET_LIMIT_ROLE"),
                    keccak256("PAUSE_WITHDRAWALS_ROLE"),
                    keccak256("UNPAUSE_WITHDRAWALS_ROLE"),
                    keccak256("PAUSE_DEPOSITS_ROLE"),
                    keccak256("UNPAUSE_DEPOSITS_ROLE"),
                    keccak256("SET_DEPOSIT_WHITELIST_ROLE"),
                    keccak256("SET_DEPOSITOR_WHITELIST_STATUS_ROLE")
                ];
                for (uint256 i = 0; i < roles.length; i++) {
                    assertEq(
                        c.getRoleMemberCount(roles[i]),
                        0,
                        "Invalid role member count after migration"
                    );
                }

                assertEq(c.depositPause(), true, "Invalid deposit pause after migration");
                assertEq(c.withdrawalPause(), true, "Invalid withdrawal pause after migration");
                assertEq(c.depositWhitelist(), false, "Invalid deposit whitelist after migration");
                assertEq(
                    keccak256(abi.encode(c.name())),
                    keccak256(abi.encode(name)),
                    "Invalid name after migration"
                );
                assertEq(
                    keccak256(abi.encode(c.symbol())),
                    keccak256(abi.encode(symbol)),
                    "Invalid symbol after migration"
                );
                assertEq(
                    address(c.symbioticCollateral()),
                    address(defaultCollateralWstETH),
                    "Invalid symbiotic collateral after migration"
                );

                assertEq(
                    c.compatTotalSupply(), c.totalSupply(), "Invalid total supply after migration"
                );
                // NOTE: ETH->WSTETH CONVERSION!!!
                assertApproxEqAbs(
                    IWSTETH(wsteth).getWstETHByStETH(stack.totalValue),
                    c.totalAssets(),
                    c.totalAssets() / 1 gwei, // at most 1-e9 precision
                    "Invalid total assets after migration"
                );
                assertEq(stack.totalSupply, c.totalSupply(), "Invalid total supply after migration");
            }
        }

        {
            validateProxyBytecodes();

            MellowVaultCompat vault = MellowVaultCompat(VAULTS[VAULT_INDEX]);
            ISymbioticVault symbioticVault = vault.symbioticVault();
            ISymbioticWithdrawalQueue queue =
                ISymbioticWithdrawalQueue(address(vault.withdrawalQueue()));

            validateVaultState(vault);
            validateSymbioticVaultState(vault, symbioticVault);
            validateSymbioticWithdrawalQueueState(vault, symbioticVault, queue);
        }
    }
}
