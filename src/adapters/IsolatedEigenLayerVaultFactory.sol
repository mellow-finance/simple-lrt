// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {EigenLayerWithdrawalQueue} from "../queues/EigenLayerWithdrawalQueue.sol";

import "./IsolatedEigenLayerVault.sol";
import {TransparentUpgradeableProxy} from
    "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

/**
 * @title IsolatedEigenLayerVaultFactory
 * @notice Factory contract for deploying and managing isolated EigenLayer vaults and their associated withdrawal queues.
 */
contract IsolatedEigenLayerVaultFactory {
    /**
     * @notice Data structure representing an isolated vault instance.
     * @param owner The owner of the isolated vault.
     * @param operator The operator assigned to the isolated vault.
     * @param strategy The strategy associated with the isolated vault.
     * @param withdrawalQueue The address of the withdrawal queue linked to the isolated vault.
     */
    struct Data {
        address owner;
        address operator;
        address strategy;
        address withdrawalQueue;
    }

    address public immutable delegation;
    address public immutable isolatedVaultSingleton;
    address public immutable withdrawalQueueSingleton;
    address public immutable proxyAdmin;

    mapping(address isolatedVault => Data) public instances;
    mapping(bytes32 key => address isolatedVault) public isolatedVaults;

    constructor(
        address delegation_,
        address isolatedVaultSingleton_,
        address withdrawalQueueSingleton_,
        address proxyAdmin_
    ) {
        delegation = delegation_;
        isolatedVaultSingleton = isolatedVaultSingleton_;
        withdrawalQueueSingleton = withdrawalQueueSingleton_;
        proxyAdmin = proxyAdmin_;
    }
    
    /**
     * @notice Generates a unique key for an isolated vault based on its owner, operator, and strategy.
     * @param owner The address of the vault owner.
     * @param operator The address of the operator.
     * @param strategy The address of the associated strategy.
     * returns a unique `bytes32` key for the vault.
     */
    function key(address owner, address operator, address strategy) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(owner, strategy, operator));
    }

    /**
     * @notice Retrieves or creates an isolated EigenLayer vault and its associated withdrawal queue.
     * @dev If the vault already exists, it returns the existing addresses; otherwise, it deploys new instances.
     * @param owner The address of the vault owner.
     * @param operator The address of the operator.
     * @param strategy The address of the associated strategy.
     * @param data Encoded initialization data, including delegation signature and salt.
     * @return isolatedVault The address of the isolated vault.
     * @return withdrawalQueue The address of the withdrawal queue linked to the isolated vault.
     */
    function getOrCreate(address owner, address operator, address strategy, bytes calldata data)
        external
        returns (address isolatedVault, address withdrawalQueue)
    {
        bytes32 key_ = key(owner, strategy, operator);
        isolatedVault = isolatedVaults[key_];
        if (isolatedVault != address(0)) {
            return (isolatedVault, instances[isolatedVault].withdrawalQueue);
        }

        isolatedVault = address(
            new TransparentUpgradeableProxy(
                isolatedVaultSingleton,
                proxyAdmin,
                abi.encodeCall(IsolatedEigenLayerVault.initialize, (owner))
            )
        );
        (ISignatureUtils.SignatureWithExpiry memory signature, bytes32 salt) =
            abi.decode(data, (ISignatureUtils.SignatureWithExpiry, bytes32));
        IIsolatedEigenLayerVault(isolatedVault).delegateTo(delegation, operator, signature, salt);
        withdrawalQueue = address(
            new TransparentUpgradeableProxy(
                withdrawalQueueSingleton,
                proxyAdmin,
                abi.encodeCall(
                    EigenLayerWithdrawalQueue.initialize, (isolatedVault, strategy, operator)
                )
            )
        );

        instances[isolatedVault] = Data(owner, operator, strategy, withdrawalQueue);
    }
}
