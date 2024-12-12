// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

interface IIsolatedEigenLayerVaultFactory {
    struct Data {
        address owner;
        address operator;
        address strategy;
        address withdrawalQueue;
    }

    function delegation() external view returns (address);
    function claimer() external view returns (address);

    function instances(address isolatedVault)
        external
        view
        returns (address owner, address operator, address strategy, address withdrawalQueue);

    function isolatedVaults(bytes32 key) external view returns (address);

    function key(address owner, address operator, address strategy)
        external
        view
        returns (bytes32);

    function getOrCreate(address owner, address operator, address strategy, bytes calldata data)
        external
        returns (address isolatedVault, address withdrawalQueue);
}
