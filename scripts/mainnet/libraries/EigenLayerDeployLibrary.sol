// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../../src/adapters/EigenLayerAdapter.sol";
import "../../../src/adapters/IsolatedEigenLayerVault.sol";

import "../../../src/adapters/IsolatedEigenLayerVaultFactory.sol";
import "../../../src/adapters/IsolatedEigenLayerWstETHVault.sol";
import "../../../src/vaults/MultiVault.sol";
import "./AbstractDeployLibrary.sol";

contract EigenLayerDeployLibrary is AbstractDeployLibrary {
    struct DeployParams {
        address strategy;
        address operator;
        bytes signature;
        bytes32 salt;
    }

    struct Storage {
        mapping(address proxyAdmin => mapping(bool isWstETH => address factory)) factories;
    }

    address public constant WSTETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address public constant STRATEGY_MANAGER = 0x858646372CC42E1A627fcE94aa7A7033e7CF075A;
    address public constant REWARDS_COORDINATOR = 0x7750d328b314EfFa365A0402CcfD489B80B0adda;
    address public constant DELEGATION_MANAGER = 0x39053D51B77DC0d36036Fc1fCc8Cb819df8Ef37A;
    bytes32 public constant STORAGE_SLOT = keccak256("EigenLayerDeployLibrary.Storage");

    address public immutable withdrawalQueueImplementation;
    address public immutable isolatedEigenLayerWstETHVaultImplementation;
    address public immutable isolatedEigenLayerVaultImplementation;

    constructor(
        address withdrawalQueueImplementation_,
        address isolatedEigenLayerVaultImplementation_,
        address isolatedEigenLayerWstETHVaultImplementation_
    ) {
        withdrawalQueueImplementation = withdrawalQueueImplementation_;
        isolatedEigenLayerVaultImplementation = isolatedEigenLayerVaultImplementation_;
        isolatedEigenLayerWstETHVaultImplementation = isolatedEigenLayerWstETHVaultImplementation_;
    }

    // View functions

    function subvaultType() external pure override returns (uint256) {
        return 1; // Symbiotic vault type
    }

    // Mutable functions

    function deployAndSetAdapter(
        address multiVault,
        AbstractDeployScript.Config calldata config,
        bytes calldata /* data */
    ) external override onlyDelegateCall {
        bool isWstETH = config.asset == WSTETH;
        address factory = _contractStorage().factories[config.vaultProxyAdmin][isWstETH];
        if (factory == address(0)) {
            factory = address(
                new IsolatedEigenLayerVaultFactory{
                    salt: keccak256(abi.encodePacked(config.vaultProxyAdmin, isWstETH))
                }(
                    DELEGATION_MANAGER,
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
        address adapter = address(
            new EigenLayerAdapter{salt: bytes32(bytes20(multiVault))}(
                factory,
                multiVault,
                IStrategyManager(STRATEGY_MANAGER),
                IRewardsCoordinator(REWARDS_COORDINATOR)
            )
        );
        MultiVault(multiVault).setEigenLayerAdapter(adapter);
    }

    function deploySubvault(
        address multiVault,
        AbstractDeployScript.Config calldata config,
        bytes calldata data
    ) external override onlyDelegateCall returns (address isolatedVault) {
        DeployParams memory params = abi.decode(data, (DeployParams));
        address factory =
            _contractStorage().factories[config.vaultProxyAdmin][config.asset == WSTETH];
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
