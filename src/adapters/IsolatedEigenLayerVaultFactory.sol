// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {EigenLayerWithdrawalQueue} from "../queues/EigenLayerWithdrawalQueue.sol";

import "./IsolatedEigenLayerVault.sol";
import {TransparentUpgradeableProxy} from
    "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract IsolatedEigenLayerVaultFactory {
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

    function key(address owner, address operator, address strategy) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(owner, strategy, operator));
    }

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
