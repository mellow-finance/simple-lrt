// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../../src/adapters/EigenLayerAdapter.sol";
import "../../../src/adapters/EigenLayerWstETHAdapter.sol";
import "../../../src/adapters/IsolatedEigenLayerVault.sol";
import "../../../src/adapters/IsolatedEigenLayerVaultFactory.sol";
import "../../../src/adapters/IsolatedEigenLayerWstETHVault.sol";
import "../../../src/vaults/MultiVault.sol";
import "./AbstractDeployLibrary.sol";
import "./EigenLayerDeployLibraryHelper.sol";

contract EigenLayerDeployLibrary is AbstractDeployLibrary {
    struct DeployParams {
        address strategy;
        address operator;
        ISignatureUtils.SignatureWithExpiry signature;
        bytes32 salt;
    }

    struct Storage {
        mapping(address proxyAdmin => mapping(bool isWstETH => address factory)) factories;
    }

    bytes32 public constant STORAGE_SLOT = keccak256("EigenLayerDeployLibrary.Storage");

    address public immutable wsteth;
    address public immutable strategyManager;
    address public immutable rewardsCoordinator;
    address public immutable delegationManager;
    address public immutable withdrawalQueueImplementation;
    address public immutable isolatedEigenLayerWstETHVaultImplementation;
    address public immutable isolatedEigenLayerVaultImplementation;
    EigenLayerDeployLibraryHelper public immutable helper;

    constructor(
        address wsteth_,
        address strategyManager_,
        address rewardsCoordinator_,
        address delegationManager_,
        address withdrawalQueueImplementation_,
        address isolatedEigenLayerVaultImplementation_,
        address isolatedEigenLayerWstETHVaultImplementation_,
        address helper_
    ) AbstractDeployLibrary() {
        wsteth = wsteth_;
        strategyManager = strategyManager_;
        rewardsCoordinator = rewardsCoordinator_;
        delegationManager = delegationManager_;
        withdrawalQueueImplementation = withdrawalQueueImplementation_;
        isolatedEigenLayerVaultImplementation = isolatedEigenLayerVaultImplementation_;
        isolatedEigenLayerWstETHVaultImplementation = isolatedEigenLayerWstETHVaultImplementation_;
        helper = EigenLayerDeployLibraryHelper(helper_);
    }

    // View functions

    function subvaultType() external pure override returns (uint256) {
        return 1;
    }

    function combineOptions(
        address strategy,
        address operator,
        ISignatureUtils.SignatureWithExpiry memory signature,
        bytes32 salt
    ) external pure returns (bytes memory) {
        return abi.encode(
            DeployParams({strategy: strategy, operator: operator, signature: signature, salt: salt})
        );
    }

    // Mutable functions

    function deployAndSetAdapter(
        address multiVault,
        DeployScript.Config calldata config,
        bytes calldata, /* data */
        bytes32 salt
    ) external override onlyDelegateCall {
        bool isWstETH = config.asset == wsteth;
        address factory = _contractStorage().factories[config.vaultProxyAdmin][isWstETH];
        if (factory == address(0)) {
            factory = address(
                new IsolatedEigenLayerVaultFactory{salt: salt}(
                    delegationManager,
                    isWstETH
                        ? isolatedEigenLayerWstETHVaultImplementation
                        : isolatedEigenLayerVaultImplementation,
                    withdrawalQueueImplementation,
                    config.vaultProxyAdmin
                )
            );
            _contractStorage().factories[config.vaultProxyAdmin][isWstETH] = factory;
        }
        if (address(MultiVault(multiVault).eigenLayerAdapter()) != address(0)) {
            return;
        }
        address adapter = helper.deployEigenLayerAdapter(
            isWstETH, salt, factory, multiVault, strategyManager, rewardsCoordinator, wsteth
        );
        MultiVault(multiVault).setEigenLayerAdapter(adapter);
    }

    function deploySubvault(
        address multiVault,
        DeployScript.Config calldata config,
        bytes calldata data,
        bytes32 /* salt */
    ) external override onlyDelegateCall returns (address isolatedVault) {
        DeployParams memory params = abi.decode(data, (DeployParams));
        address factory =
            _contractStorage().factories[config.vaultProxyAdmin][config.asset == wsteth];
        (isolatedVault,) = IsolatedEigenLayerVaultFactory(factory).getOrCreate(
            address(multiVault),
            params.strategy,
            params.operator,
            abi.encode(params.signature, params.salt)
        );
    }

    // Internal functions

    function _contractStorage() internal pure returns (Storage storage s) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            s.slot := slot
        }
    }
}
