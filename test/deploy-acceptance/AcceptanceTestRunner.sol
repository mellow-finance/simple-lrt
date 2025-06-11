// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../scripts/deploy/DeployScript.sol";
import "../../scripts/deploy/libraries/EigenLayerDeployLibrary.sol";
import "../../scripts/deploy/libraries/SymbioticDeployLibrary.sol";
import "../../src/utils/Claimer.sol";

import "@openzeppelin/contracts/access/extensions/IAccessControlEnumerable.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
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

    function getProxyAdmin(address proxyAddress) public view returns (address) {
        bytes memory proxyCode = address(proxyAddress).code;
        require(proxyCode.length >= 28 + 20, "getProxyAdmin: invalid proxy code length");
        address proxyAdmin;
        assembly {
            proxyAdmin := mload(add(proxyCode, 48))
        }
        return proxyAdmin;
    }

    function validateState(DeployScript deployScript, uint256 deployIndex) internal {
        DeployScript.DeployParams memory deployParams = deployScript.deployParams(deployIndex);
        validateDeployScriptState(deployScript, deployIndex, deployParams);
        validateStrategyState(deployScript, deployIndex, deployParams);
        validateVaultPermissions(deployScript, deployIndex, deployParams);
        validateVaultState(deployScript, deployIndex, deployParams);
    }

    function getCleanBytecode(bytes memory contractCode) internal pure returns (bytes memory) {
        uint256 metadataIndex = contractCode.length;
        // src: https://docs.soliditylang.org/en/v0.8.25/metadata.html#encoding-of-the-metadata-hash-in-the-bytecode
        bytes1 b1 = 0xa2;
        bytes1 b2 = 0x64;
        for (uint256 i = 0; i < contractCode.length; i++) {
            if (contractCode[i] == b1 && contractCode[i + 1] == b2) {
                metadataIndex = i;
                break;
            }
        }
        assembly {
            mstore(contractCode, metadataIndex)
        }
        if (metadataIndex == 8358) {
            // cleaning EigenLayerDeployLibrary
            for (uint256 i = 0; i < 20; i++) {
                contractCode[i + 684] = bytes1(0); // this_
                contractCode[i + 1221] = bytes1(0); // modifier
            }
        } else if (metadataIndex == 13414) {
            // cleaning SymbioticDeployLibrary
            for (uint256 i = 0; i < 20; i++) {
                contractCode[i + 896] = bytes1(0); // this_
                contractCode[i + 2560] = bytes1(0); // modifier
            }
        } else if (metadataIndex == 0x41e) {
            // cleaning TransparentUpgradeableProxy
            for (uint256 i = 0; i < 20; i++) {
                contractCode[i + 28] = bytes1(0); // ProxyAdmin
            }
        }
        return contractCode;
    }

    function validateBytecode(bytes memory a, bytes memory b, string memory name) internal pure {
        a = getCleanBytecode(a);
        b = getCleanBytecode(b);
        if (keccak256(a) != keccak256(b)) {
            if (a.length != b.length) {
                revert(string.concat("validateBytecode: bytecode length mismatch for ", name));
            } else {
                for (uint256 i = 0; i < a.length; i++) {
                    if (a[i] != b[i]) {
                        revert(
                            string.concat(
                                "validateBytecode: bytecode mismatch at index ",
                                Strings.toString(a.length),
                                " ",
                                Strings.toString(i),
                                " for ",
                                name
                            )
                        );
                    }
                }
                revert(string.concat("validateBytecode: bytecode mismatch for ", name));
            }
        }
    }

    function validateVaultState(
        DeployScript deployScript,
        uint256 deployIndex,
        DeployScript.DeployParams memory deployParams
    ) internal {
        MultiVault multiVault = MultiVault(deployScript.deployments(deployIndex));
        require(
            address(multiVault) != address(0),
            "validateVaultState: invalid MultiVault contract address"
        );

        {
            bytes memory a = address(multiVault).code;
            bytes memory b = address(
                new TransparentUpgradeableProxy(
                    deployScript.multiVaultImplementation(),
                    deployParams.config.vaultProxyAdmin,
                    new bytes(0)
                )
            ).code;
            validateBytecode(a, b, "TransparentUpgradeableProxy(MultiVault)");
            address proxyAdmin = getProxyAdmin(address(multiVault));
            require(
                ProxyAdmin(proxyAdmin).owner() == deployParams.config.vaultProxyAdmin,
                "validateVaultState: invalid ProxyAdmin(MultiVault)"
            );
        }

        require(
            address(multiVault.erc4626Adapter()) == address(0),
            "validateVaultState: invalid erc4626Adapter address"
        );

        require(
            multiVault.subvaultsCount() == deployParams.subvaults.length, "Invalid subvaults count"
        );
        if (deployParams.subvaults.length != 0) {
            uint256 protocols = 0;
            for (
                uint256 subvaultIndex = 0;
                subvaultIndex < multiVault.subvaultsCount();
                subvaultIndex++
            ) {
                IMultiVault.Subvault memory subvault = multiVault.subvaultAt(subvaultIndex);
                AbstractDeployLibrary deployLibrary = AbstractDeployLibrary(
                    deployScript.deployLibraries(deployParams.subvaults[subvaultIndex].libraryIndex)
                );
                require(
                    uint256(deployLibrary.subvaultType()) == uint256(subvault.protocol),
                    "Invalid subvault protocol"
                );
                require(
                    address(subvault.withdrawalQueue) != address(0),
                    "Invalid withdrawalQueue address"
                );
                if (subvault.protocol == IMultiVaultStorage.Protocol.SYMBIOTIC) {
                    protocols |= 1;
                    bytes memory a = address(subvault.withdrawalQueue).code;
                    bytes memory b = address(
                        new TransparentUpgradeableProxy(
                            SymbioticDeployLibrary(address(deployLibrary))
                                .withdrawalQueueImplementation(),
                            deployParams.config.vaultProxyAdmin,
                            abi.encodeCall(
                                SymbioticWithdrawalQueue.initialize,
                                (address(multiVault), subvault.vault)
                            )
                        )
                    ).code;
                    validateBytecode(a, b, "TransparentUpgradeableProxy(SymbioticWithdrawalQueue)");
                    address proxyAdmin = getProxyAdmin(subvault.withdrawalQueue);
                    require(
                        ProxyAdmin(proxyAdmin).owner() == deployParams.config.vaultProxyAdmin,
                        "validateVaultState: invalid ProxyAdmin"
                    );
                    require(
                        IRegistry(
                            SymbioticDeployLibrary(address(deployLibrary)).symbioticVaultFactory()
                        ).isEntity(subvault.vault),
                        "validateVaultState: invalid symbioticVaultFactory"
                    );

                    require(
                        ISymbioticVault(subvault.vault).collateral() == multiVault.asset(),
                        "validateVaultState: invalid symbioticVault collateral"
                    );
                } else {
                    protocols |= 2;
                    EigenLayerDeployLibrary.DeployParams memory params_ = abi.decode(
                        deployParams.subvaults[subvaultIndex].data,
                        (EigenLayerDeployLibrary.DeployParams)
                    );
                    bytes memory a = address(subvault.withdrawalQueue).code;
                    bytes memory b = address(
                        new TransparentUpgradeableProxy(
                            EigenLayerDeployLibrary(address(deployLibrary))
                                .withdrawalQueueImplementation(),
                            deployParams.config.vaultProxyAdmin,
                            abi.encodeCall(
                                EigenLayerWithdrawalQueue.initialize,
                                (subvault.vault, params_.strategy, params_.operator)
                            )
                        )
                    ).code;

                    validateBytecode(a, b, "TransparentUpgradeableProxy(EigenLayerWithdrawalQueue)");
                    address proxyAdmin = getProxyAdmin(subvault.withdrawalQueue);
                    require(
                        ProxyAdmin(proxyAdmin).owner() == deployParams.config.vaultProxyAdmin,
                        "validateVaultState: invalid ProxyAdmin"
                    );

                    {
                        EigenLayerDeployLibrary deployLibrary_ =
                            EigenLayerDeployLibrary(address(deployLibrary));
                        bytes memory factoryCode =
                            address(IsolatedEigenLayerVault(subvault.vault).factory()).code;
                        bytes memory expectedFactoryCode = address(
                            new IsolatedEigenLayerVaultFactory(
                                deployLibrary_.delegationManager(),
                                deployParams.config.asset == deployLibrary_.wsteth()
                                    ? deployLibrary_.isolatedEigenLayerWstETHVaultImplementation()
                                    : deployLibrary_.isolatedEigenLayerVaultImplementation(),
                                deployLibrary_.withdrawalQueueImplementation(),
                                deployParams.config.vaultProxyAdmin
                            )
                        ).code;
                        validateBytecode(
                            factoryCode, expectedFactoryCode, "IsolatedEigenLayerVaultFactory"
                        );
                    }
                    {
                        (address owner, address strategy, address operator, address withdrawalQueue)
                        = IsolatedEigenLayerVaultFactory(
                            IsolatedEigenLayerVault(subvault.vault).factory()
                        ).instances(subvault.vault);
                        require(
                            owner == address(multiVault),
                            "validateVaultState: invalid IsolatedEigenLayerVault owner"
                        );
                        require(
                            strategy == params_.strategy,
                            "validateVaultState: invalid IsolatedEigenLayerVault strategy"
                        );
                        require(
                            operator == params_.operator,
                            "validateVaultState: invalid IsolatedEigenLayerVault operator"
                        );
                        require(
                            withdrawalQueue == address(subvault.withdrawalQueue),
                            "validateVaultState: invalid IsolatedEigenLayerVault withdrawalQueue"
                        );
                    }
                    {
                        EigenLayerDeployLibrary deployLibrary_ =
                            EigenLayerDeployLibrary(address(deployLibrary));
                        bytes memory isolatedVaultBytecode = address(subvault.vault).code;
                        bytes memory expectedIsolatedVaultBytecode = address(
                            new TransparentUpgradeableProxy(
                                deployParams.config.asset == deployLibrary_.wsteth()
                                    ? deployLibrary_.isolatedEigenLayerWstETHVaultImplementation()
                                    : deployLibrary_.isolatedEigenLayerVaultImplementation(),
                                deployParams.config.vaultProxyAdmin,
                                abi.encodeCall(
                                    IsolatedEigenLayerVault.initialize, (address(multiVault))
                                )
                            )
                        ).code;
                        validateBytecode(
                            isolatedVaultBytecode,
                            expectedIsolatedVaultBytecode,
                            "TransparentUpgradeableProxy(IsolatedEigenLayerVault/IsolatedEigenLayerWstETHVault)"
                        );
                    }
                }
            }

            if (protocols > 3) {
                revert("validateVaultState: invalid subvaults protocols");
            }
            require(
                (address(multiVault.symbioticAdapter()) != address(0)) == (protocols & 1 != 0),
                "validateVaultState: invalid symbioticAdapter address"
            );
            require(
                (address(multiVault.eigenLayerAdapter()) != address(0)) == (protocols & 2 != 0),
                "validateVaultState: invalid eigenLayerAdapter address"
            );
        }
        require(
            address(multiVault.depositStrategy()) == address(deployScript.strategy()),
            "validateVaultState: invalid strategy"
        );

        require(
            address(multiVault.withdrawalStrategy()) == address(deployScript.strategy()),
            "validateVaultState: invalid strategy"
        );

        require(
            address(multiVault.rebalanceStrategy()) == address(deployScript.strategy()),
            "validateVaultState: invalid strategy"
        );

        require(
            address(multiVault.defaultCollateral())
                == address(deployParams.config.defaultCollateral),
            "validateVaultState: invalid defaultCollateral"
        );

        require(
            address(multiVault.defaultCollateral().asset()) == multiVault.asset(),
            "validateVaultState: invalid defaultCollateral asset"
        );

        require(multiVault.farmCount() == 0, "validateVaultState: invalid farm count");

        if (multiVault.totalSupply() == 0) {
            require(
                multiVault.totalSupply() == 0 && multiVault.totalAssets() == 0,
                "validateVaultState: invalid totalSupply or totalAssets"
            );
        } else {
            require(
                multiVault.totalSupply() == multiVault.totalAssets(),
                "validateVaultState: totalSupply != totalAssets"
            );
        }

        require(multiVault.limit() == deployParams.config.limit, "Invalid limit");

        require(
            multiVault.depositPause() == deployParams.config.depositPause, "Invalid depositPause"
        );

        require(
            multiVault.withdrawalPause() == deployParams.config.withdrawalPause,
            "Invalid withdrawalPause"
        );

        if (deployParams.config.depositWrapper != address(0)) {
            require(multiVault.depositWhitelist(), "Invalid depositWhitelist");

            require(
                multiVault.isDepositorWhitelisted(deployParams.config.depositWrapper),
                "Invalid depositWrapper whitelist status"
            );
        } else {
            require(!multiVault.depositWhitelist(), "Invalid depositWhitelist");
        }
    }

    function validateStrategyState(
        DeployScript deployScript,
        uint256 deployIndex,
        DeployScript.DeployParams memory deployParams
    ) internal view {
        address vault = deployScript.deployments(deployIndex);
        RatiosStrategy strategy = RatiosStrategy(deployScript.strategy());
        require(
            MultiVault(vault).subvaultsCount() == deployParams.subvaults.length,
            "Invalid subvaults count"
        );
        for (uint256 i = 0; i < deployParams.subvaults.length; i++) {
            DeployScript.SubvaultParams memory subvault = deployParams.subvaults[i];
            (uint64 minRatioD18, uint64 maxRatioD18) =
                strategy.ratios(vault, MultiVault(vault).subvaultAt(i).vault);

            require(minRatioD18 == subvault.minRatioD18, "Invalid minRatioD18 in strategy");
            require(maxRatioD18 == subvault.maxRatioD18, "Invalid maxRatioD18 in strategy");
        }
    }

    function validateDeployScriptState(
        DeployScript deployScript,
        uint256 deployIndex,
        DeployScript.DeployParams memory deployParams
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

        require(deployScript.deploymentsCount() > deployIndex, "Invalid deploy index");
        require(
            keccak256(abi.encode(deployParams))
                == keccak256(abi.encode(deployScript.deployParams(deployIndex))),
            "Invalid deploy params"
        );

        for (uint256 i = 0; i < 16; i++) {
            address deployLibrary = deployScript.deployLibraries(i);
            if (i >= 2) {
                require(deployLibrary == address(0), "Invalid deploy library at index 2");
            } else if (deployLibrary != address(0)) {
                if (i == 0) {
                    // symbiotic deploy library
                    validateBytecode(
                        deployLibrary.code,
                        address(
                            new SymbioticDeployLibrary(
                                0x29300b1d3150B4E2b12fE80BE72f365E200441EC,
                                0x99F2B89fB3C363fBafD8d826E5AA77b28bAB70a0,
                                1,
                                3,
                                1,
                                0,
                                0xAEb6bdd95c502390db8f52c8909F703E9Af6a346,
                                0xaB253B304B0BfBe38Ef7EA1f086D01A6cE1c5028
                            )
                        ).code,
                        "SymbioticDeployLibrary"
                    );
                } else {
                    // eigenlayer deploy library
                    validateBytecode(
                        deployLibrary.code,
                        address(
                            new EigenLayerDeployLibrary(
                                0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0,
                                0x858646372CC42E1A627fcE94aa7A7033e7CF075A,
                                0x7750d328b314EfFa365A0402CcfD489B80B0adda,
                                0x39053D51B77DC0d36036Fc1fCc8Cb819df8Ef37A,
                                EigenLayerDeployLibrary(deployLibrary).withdrawalQueueImplementation(
                                ),
                                EigenLayerDeployLibrary(deployLibrary)
                                    .isolatedEigenLayerVaultImplementation(),
                                EigenLayerDeployLibrary(deployLibrary)
                                    .isolatedEigenLayerWstETHVaultImplementation(),
                                address(EigenLayerDeployLibrary(deployLibrary).helper())
                            )
                        ).code,
                        "EigenLayerDeployLibrary"
                    );
                    validateBytecode(
                        address(EigenLayerDeployLibrary(deployLibrary).helper()).code,
                        address(new EigenLayerDeployLibraryHelper()).code,
                        "EigenLayerDeployLibraryHelper"
                    );
                }
            }
        }

        address multiVault = address(deployScript.deployments(deployIndex));
        require(
            multiVault != address(0),
            string.concat("Invalid MultiVault address at index ", Strings.toString(deployIndex))
        );

        validateBytecode(
            multiVault.code,
            address(
                new TransparentUpgradeableProxy(
                    deployScript.multiVaultImplementation(),
                    deployParams.config.vaultProxyAdmin,
                    new bytes(0)
                )
            ).code,
            "TransparentUpgradeableProxy(MultiVault)"
        );
    }

    function validateVaultPermissions(
        DeployScript deployScript,
        uint256 deployIndex,
        DeployScript.DeployParams memory deployParams
    ) internal view {
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
            PairAddressBytes32(deployParams.config.vaultAdmin, DEFAULT_ADMIN_ROLE),
            PairAddressBytes32(deployParams.config.curator, SET_LIMIT_ROLE),
            PairAddressBytes32(deployParams.config.curator, ADD_SUBVAULT_ROLE),
            PairAddressBytes32(deployParams.config.vaultAdmin, SET_FARM_ROLE),
            PairAddressBytes32(deployParams.config.curator, REBALANCE_ROLE),
            PairAddressBytes32(deployParams.config.curator, RATIOS_STRATEGY_SET_RATIOS_ROLE)
        ];

        IAccessControlEnumerable vault =
            IAccessControlEnumerable(deployScript.deployments(deployIndex));
        uint256 index = 0;
        for (uint256 i = 0; i < roles.length; i++) {
            bytes32 role = roles[i];
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
