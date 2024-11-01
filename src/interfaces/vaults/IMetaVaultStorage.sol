// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

interface IMetaVaultStorage {
    struct MetaStorage {
        address depositStrategy;
        address withdrawalStrategy;
        address rebalanceStrategy;
        bytes32 subvaultsHash;
        EnumerableSet.AddressSet subvaults;
        mapping(address subvault => bool isQueuedVault) isQueuedVault;
    }

    function MAX_SUBVAULTS() external view returns (uint256);

    function subvaults() external view returns (address[] memory);

    function subvaultAt(uint256 index) external view returns (address);

    function hasSubvault(address subvault) external view returns (bool);

    function subvaultsCount() external view returns (uint256);

    function depositStrategy() external view returns (address);

    function withdrawalStrategy() external view returns (address);

    function rebalanceStrategy() external view returns (address);

    function subvaultsHash() external view returns (bytes32);

    function isQueuedVault(address subvault) external view returns (bool);

    event MetaVaultStorageInitialized(address indexed sender, address indexed idleVault);
    event DepositStrategySet(address indexed depositStrategy);
    event WithdrawalStrategySet(address indexed withdrawalStrategy);
    event RebalanceStrategySet(address indexed rebalanceStrategy);
    event SubvaultAdded(address indexed subvault, bool indexed isQueuedVault);
    event SubvaultRemoved(address indexed subvault);
}
