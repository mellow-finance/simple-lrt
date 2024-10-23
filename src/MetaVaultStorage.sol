// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "./interfaces/vaults/IMellowSymbioticVaultStorage.sol";

abstract contract MetaVaultStorage is Initializable {
    using EnumerableSet for EnumerableSet.AddressSet;

    struct MetaStorage {
        address depositStrategy;
        address withdrawalStrategy;
        address rebalanceStrategy;
        bytes32 subvaultsHash;
        EnumerableSet.AddressSet subvaults;
    }

    uint256 public constant MAX_SUBVAULTS = 10;
    bytes32 public immutable storageSlotRef;

    constructor(bytes32 name_, uint256 version_) {
        storageSlotRef = keccak256(
            abi.encode(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            "mellow.simple-lrt.storage.MetaVaultStorage", name_, version_
                        )
                    )
                ) - 1
            )
        ) & ~bytes32(uint256(0xff));
    }

    function __initializeMetaVaultStorage(
        address depositStrategy_,
        address withdrawalStrategy_,
        address rebalanceStrategy_,
        address idleVault_
    ) internal onlyInitializing {
        _setDepositStrategy(depositStrategy_);
        _setWithdrawalStrategy(withdrawalStrategy_);
        _setRebalanceStrategy(rebalanceStrategy_);
        _addSubvault(idleVault_);
    }

    function _setDepositStrategy(address newDepositStrategy) internal {
        if (newDepositStrategy == address(0)) {
            revert("MetaVaultStorage: deposit strategy is zero address");
        }
        _metaStorage().depositStrategy = newDepositStrategy;
    }

    function _setWithdrawalStrategy(address newWithdrawalStrategy) internal {
        if (newWithdrawalStrategy == address(0)) {
            revert("MetaVaultStorage: withdrawal strategy is zero address");
        }
        _metaStorage().withdrawalStrategy = newWithdrawalStrategy;
    }

    function _setRebalanceStrategy(address newRebalanceStrategy) internal {
        if (newRebalanceStrategy == address(0)) {
            revert("MetaVaultStorage: rebalance strategy is zero address");
        }
        _metaStorage().rebalanceStrategy = newRebalanceStrategy;
    }

    function subvaults() public view returns (address[] memory) {
        return _metaStorage().subvaults.values();
    }

    function subvaultAt(uint256 index) public view returns (address) {
        MetaStorage storage m = _metaStorage();
        if (m.subvaults.length() <= index) {
            revert("MetaVaultStorage: subvault index out of bounds");
        }
        return _metaStorage().subvaults.at(index);
    }

    function hasSubvault(address subvault) public view returns (bool) {
        return _metaStorage().subvaults.contains(subvault);
    }

    function subvaultsCount() public view returns (uint256) {
        return _metaStorage().subvaults.length();
    }

    function depositStrategy() public view returns (address) {
        return _metaStorage().depositStrategy;
    }

    function withdrawalStrategy() public view returns (address) {
        return _metaStorage().withdrawalStrategy;
    }

    function rebalanceStrategy() public view returns (address) {
        return _metaStorage().rebalanceStrategy;
    }

    function _addSubvault(address subvault) internal {
        MetaStorage storage m = _metaStorage();
        if (m.subvaults.length() + 1 > MAX_SUBVAULTS) {
            revert("MetaVaultStorage: subvaults limit reached");
        }
        if (!m.subvaults.add(subvault)) {
            revert("MetaVaultStorage: subvault already exists");
        }
        m.subvaultsHash = keccak256(abi.encodePacked(m.subvaults.values()));
    }

    function _removeSubvault(address subvault) internal {
        MetaStorage storage m = _metaStorage();
        if (!m.subvaults.remove(subvault)) {
            revert("MetaVaultStorage: subvault not found");
        }
        m.subvaultsHash = keccak256(abi.encodePacked(m.subvaults.values()));
    }

    function _metaStorage() private view returns (MetaStorage storage s) {
        bytes32 slot = storageSlotRef;
        assembly {
            s.slot := slot
        }
    }
}
