// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../scripts/mainnet/MultiVaultDeployScript.sol";
import "../../src/utils/Claimer.sol";
import "./AcceptanceTestRunner.sol";
import "@openzeppelin/contracts/access/extensions/IAccessControlEnumerable.sol";
import "forge-std/console2.sol";

contract AcceptanceTestRunner {
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

    function validateState(
        MultiVaultDeployScript deployScript,
        MultiVaultDeployScript.Deployment memory deployParams
    ) internal {
        validateDeployScriptState(deployScript, deployParams);
        validateStrategyState(deployScript, deployParams);
        validateVaultPermissions(deployParams);
        validateVaultState(deployScript, deployParams);
    }

    function getCleanBytecode(bytes memory contractCode) internal pure returns (bytes memory) {
        uint256 metadataIndex = contractCode.length;
        // src: https://docs.soliditylang.org/en/v0.8.25/metadata.html#encoding-of-the-metadata-hash-in-the-bytecode
        bytes1 b1 = 0xa2;
        bytes1 b2 = 0x64;
        for (uint256 i = contractCode.length - 2; i >= 0; i--) {
            if (contractCode[i] == b1 && contractCode[i + 1] == b2) {
                metadataIndex = i;
                break;
            }
        }
        assembly {
            mstore(contractCode, metadataIndex)
        }
        return contractCode;
    }

    function validateBytecode(bytes memory a, bytes memory b, string memory name) internal pure {
        a = getCleanBytecode(a);
        b = getCleanBytecode(b);
        if (keccak256(a) != keccak256(b)) {
            if (a.length != b.length) {
                revert(string.concat("Bytecode length mismatch for ", name));
            } else {
                revert(string.concat("Bytecode mismatch for ", name));
            }
        }
    }

    function validateVaultState(
        MultiVaultDeployScript deployScript,
        MultiVaultDeployScript.Deployment memory deployParams
    ) internal {
        MultiVault multiVault = MultiVault(deployParams.multiVault);
        require(address(multiVault) != address(0), "Invalid MultiVault contract address");
        bytes32 salt = deployScript.calculateSalt(deployParams.params);

        {
            bytes memory a = address(multiVault).code;
            bytes memory b = address(
                new TransparentUpgradeableProxy{salt: salt}(
                    deployScript.multiVaultImplementation(),
                    deployParams.params.proxyAdmin,
                    new bytes(0)
                )
            ).code;
            a = getCleanBytecode(a);
            b = getCleanBytecode(b);
            require(a.length == b.length, "Invalid TransparentUpgradeableProxy bytecode length");
            uint160 proxyAdmin;
            for (uint256 i = 0; i < a.length; i++) {
                if (i < 28 || i >= 28 + 20) {
                    // ProxyAdmin
                    require(a[i] == b[i], "Invalid TransparentUpgradeableProxy bytecode");
                } else {
                    proxyAdmin = (proxyAdmin << 8) | uint8(a[i]);
                }
            }
            require(
                ProxyAdmin(address(proxyAdmin)).owner() == deployParams.params.proxyAdmin,
                "Invalid ProxyAdmin"
            );
        }

        require(
            address(multiVault.symbioticAdapter()) == address(deployParams.symbioticAdapter),
            "Invalid symbioticAdapter"
        );

        require(
            address(multiVault.eigenLayerAdapter()) == address(0),
            "Invalid eigenLayerAdapter address"
        );

        require(
            address(multiVault.erc4626Adapter()) == address(0), "Invalid erc4626Adapter address"
        );

        if (deployParams.params.symbioticVault != address(0)) {
            require(multiVault.subvaultsCount() == 1, "Invalid subvaults count");
            IMultiVault.Subvault memory subvault = multiVault.subvaultAt(0);
            require(subvault.vault == deployParams.params.symbioticVault, "Invalid symbioticVault");
            require(
                uint256(subvault.protocol) == uint256(IMultiVaultStorage.Protocol.SYMBIOTIC),
                "Invalid protocol"
            );
            require(
                address(subvault.withdrawalQueue) != address(0), "Invalid withdrawalQueue address"
            );

            {
                bytes memory a = address(subvault.withdrawalQueue).code;
                bytes memory b = address(
                    new TransparentUpgradeableProxy{
                        salt: keccak256(abi.encodePacked(deployParams.params.symbioticVault))
                    }(
                        deployScript.symbioticWithdrawalQueueImplementation(),
                        deployParams.params.proxyAdmin,
                        abi.encodeCall(
                            SymbioticWithdrawalQueue.initialize,
                            (
                                address(deployParams.multiVault),
                                address(deployParams.params.symbioticVault)
                            )
                        )
                    )
                ).code;

                a = getCleanBytecode(a);
                b = getCleanBytecode(b);

                require(a.length == b.length, "Invalid TransparentUpgradeableProxy bytecode length");
                uint160 proxyAdmin;
                for (uint256 i = 0; i < a.length; i++) {
                    if (i < 28 || i >= 28 + 20) {
                        // ProxyAdmin
                        require(a[i] == b[i], "Invalid TransparentUpgradeableProxy bytecode");
                    } else {
                        proxyAdmin = (proxyAdmin << 8) | uint8(a[i]);
                    }
                }
                require(
                    ProxyAdmin(address(proxyAdmin)).owner() == deployParams.params.proxyAdmin,
                    "Invalid ProxyAdmin"
                );
            }

            require(
                IRegistry(deployScript.symbioticVaultFactory()).isEntity(
                    deployParams.params.symbioticVault
                ),
                "Invalid symbioticVaultFactory"
            );

            require(
                ISymbioticVault(deployParams.params.symbioticVault).collateral()
                    == multiVault.asset(),
                "Invalid symbioticVault collateral"
            );
        } else {
            require(multiVault.subvaultsCount() == 0, "Invalid subvaults count");
        }

        require(
            address(multiVault.depositStrategy()) == address(deployScript.strategy()),
            "Invalid strategy"
        );

        require(
            address(multiVault.withdrawalStrategy()) == address(deployScript.strategy()),
            "Invalid strategy"
        );

        require(
            address(multiVault.rebalanceStrategy()) == address(deployScript.strategy()),
            "Invalid strategy"
        );

        require(
            address(multiVault.defaultCollateral())
                == address(deployParams.params.defaultCollateral),
            "Invalid defaultCollateral"
        );

        require(
            address(multiVault.defaultCollateral().asset()) == multiVault.asset(),
            "Invalid defaultCollateral asset"
        );

        require(multiVault.farmCount() == 0, "Invalid farm count");

        require(
            multiVault.totalSupply() == 0 && multiVault.totalAssets() == 0,
            "Invalid totalSupply or totalAssets"
        );

        require(multiVault.limit() == deployParams.params.limit, "Invalid limit");

        require(
            multiVault.depositPause() == deployParams.params.depositPause, "Invalid depositPause"
        );

        require(
            multiVault.withdrawalPause() == deployParams.params.withdrawalPause,
            "Invalid withdrawalPause"
        );

        if (deployParams.params.depositWrapper != address(0)) {
            require(multiVault.depositWhitelist(), "Invalid depositWhitelist");

            require(
                multiVault.isDepositorWhitelisted(deployParams.params.depositWrapper),
                "Invalid depositWrapper whitelist status"
            );
        } else {
            require(!multiVault.depositWhitelist(), "Invalid depositWhitelist");
        }
    }

    function validateStrategyState(
        MultiVaultDeployScript deployScript,
        MultiVaultDeployScript.Deployment memory deployParams
    ) internal view {
        if (deployParams.params.symbioticVault != address(0)) {
            RatiosStrategy strategy = RatiosStrategy(deployScript.strategy());
            (uint64 minRatioD18, uint64 maxRatioD18) =
                strategy.ratios(deployParams.multiVault, deployParams.params.symbioticVault);
            require(
                minRatioD18 == deployParams.params.minRatioD18, "Invalid minRatioD18 in strategy"
            );
            require(
                maxRatioD18 == deployParams.params.maxRatioD18, "Invalid maxRatioD18 in strategy"
            );
        }
    }

    function validateDeployScriptState(
        MultiVaultDeployScript deployScript,
        MultiVaultDeployScript.Deployment memory deployParams
    ) internal {
        validateBytecode(
            address(deployScript.multiVaultImplementation()).code,
            address(new MultiVault("MultiVault", 1)).code,
            "MultiVault"
        );

        validateBytecode(
            address(deployScript.strategy()).code,
            address(new RatiosStrategy()).code,
            "RatiosStrategy"
        );

        require(
            address(deployScript.symbioticVaultFactory()) != address(0),
            "Invalid symbioticVaultFactory address"
        );

        {
            address claimer = SymbioticWithdrawalQueue(
                deployScript.symbioticWithdrawalQueueImplementation()
            ).claimer();
            validateBytecode(claimer.code, address(new Claimer()).code, "Claimer");

            validateBytecode(
                address(deployScript.symbioticWithdrawalQueueImplementation()).code,
                address(new SymbioticWithdrawalQueue(claimer)).code,
                "SymbioticWithdrawalQueue"
            );
        }

        bytes32 salt = deployScript.calculateSalt(deployParams.params);
        MultiVaultDeployScript.Deployment memory actualDeployParams = deployScript.deployments(salt);
        require(
            keccak256(abi.encode(deployParams)) == keccak256(abi.encode(actualDeployParams)),
            "Invalid deployment state"
        );
    }

    function validateVaultPermissions(MultiVaultDeployScript.Deployment memory deployParams)
        internal
        view
    {
        bytes32[16] memory roles = [
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

        PairAddressBytes32[6] memory expectedRoles = [
            PairAddressBytes32(deployParams.params.admin, DEFAULT_ADMIN_ROLE),
            PairAddressBytes32(deployParams.params.curator, SET_LIMIT_ROLE),
            PairAddressBytes32(deployParams.params.curator, ADD_SUBVAULT_ROLE),
            PairAddressBytes32(deployParams.params.admin, SET_FARM_ROLE),
            PairAddressBytes32(deployParams.params.curator, REBALANCE_ROLE),
            PairAddressBytes32(deployParams.params.curator, RATIOS_STRATEGY_SET_RATIOS_ROLE)
        ];

        uint256 index = 0;
        for (uint256 i = 0; i < roles.length; i++) {
            bytes32 role = roles[i];
            IAccessControlEnumerable vault = IAccessControlEnumerable(deployParams.multiVault);
            uint256 n = vault.getRoleMemberCount(role);
            for (uint256 j = 0; j < n; j++) {
                address member = vault.getRoleMember(role, j);
                if (
                    index == expectedRoles.length || expectedRoles[index].address_ != member
                        || expectedRoles[index].bytes32_ != role
                ) {
                    revert("Invalid permission set");
                } else {
                    index++;
                }
            }
        }
        if (index != expectedRoles.length) {
            revert("Invalid permission set");
        }
    }
}
