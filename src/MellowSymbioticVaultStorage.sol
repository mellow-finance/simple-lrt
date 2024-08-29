// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import "./interfaces/vaults/IMellowSymbioticVaultStorage.sol";

abstract contract MellowSymbioticVaultStorage is IMellowSymbioticVaultStorage, Initializable {
    using EnumerableSet for EnumerableSet.UintSet;

    ///@notice The first slot of the storage.
    bytes32 private immutable storageSlotRef;

    constructor(bytes32 name_, uint256 version_) {
        storageSlotRef = keccak256(
            abi.encode(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            "mellow.simple-lrt.storage.MellowSymbioticVaultStorage", name_, version_
                        )
                    )
                ) - 1
            )
        ) & ~bytes32(uint256(0xff));
    }

    /**
     * @notice Initializes the storage of the Mellow Symbiotic Vault.
     * @param _symbioticCollateral The address of the underlying Symbiotic DefaultCollateral.
     * @param _symbioticVault The address of the underlying Symbiotic Vault.
     * @param _withdrawalQueue The address of the associated Withdrawal Queue.
     *
     * @custom:requirements
     * - This function MUST be called only once, during the initialization phase (i.e., it MUST not have been initialized before).
     *
     * @custom:effects
     * - Sets the Symbiotic Vault address, Symbiotic Collateral address and the Withdrawal Queue address in storage.
     * - Emits the `SymbioticCollateralSet` event, signaling that the Symbiotic Collateral has been successfully set.
     * - Emits the `SymbioticVaultSet` event, signaling that the Symbiotic Vault has been successfully set.
     * - Emits the `WithdrawalQueueSet` event, signaling that the Withdrawal Queue has been successfully set.
     */
    function __initializeMellowSymbioticVaultStorage(
        address _symbioticCollateral,
        address _symbioticVault,
        address _withdrawalQueue
    ) internal onlyInitializing {
        _setSymbioticCollateral(IDefaultCollateral(_symbioticCollateral));
        _setSymbioticVault(ISymbioticVault(_symbioticVault));
        _setWithdrawalQueue(IWithdrawalQueue(_withdrawalQueue));
    }

    /// @inheritdoc IMellowSymbioticVaultStorage
    function symbioticVault() public view returns (ISymbioticVault) {
        return _symbioticStorage().symbioticVault;
    }

    function symbioticCollateral() public view returns (IDefaultCollateral) {
        return _symbioticStorage().symbioticCollateral;
    }

    /// @inheritdoc IMellowSymbioticVaultStorage
    function withdrawalQueue() public view returns (IWithdrawalQueue) {
        return _symbioticStorage().withdrawalQueue;
    }

    /// @inheritdoc IMellowSymbioticVaultStorage
    function symbioticFarmIds() public view returns (uint256[] memory) {
        return _symbioticStorage().farmIds.values();
    }

    /// @inheritdoc IMellowSymbioticVaultStorage
    function symbioticFarmCount() public view returns (uint256) {
        return _symbioticStorage().farmIds.length();
    }

    /// @inheritdoc IMellowSymbioticVaultStorage
    function symbioticFarmIdAt(uint256 index) public view returns (uint256) {
        return _symbioticStorage().farmIds.at(index);
    }

    /// @inheritdoc IMellowSymbioticVaultStorage
    function symbioticFarmsContains(uint256 farmId) public view returns (bool) {
        return _symbioticStorage().farmIds.contains(farmId);
    }

    /// @inheritdoc IMellowSymbioticVaultStorage
    function symbioticFarm(uint256 farmId) public view returns (FarmData memory) {
        return _symbioticStorage().farms[farmId];
    }

    /**
     * @notice Sets a new Symbiotic Collateral address in the vault's storage.
     * @param _symbioticCollateral The address of the new Symbiotic DefaultCollateral to be set.
     *
     * @custom:effects
     * - Updates the Symbiotic Collateral address in the storage.
     * - Emits the `SymbioticCollateralSet` event with the new Symbiotic DefaultCollateral address and the current timestamp.
     */
    function _setSymbioticCollateral(IDefaultCollateral _symbioticCollateral) internal {
        SymbioticStorage storage s = _symbioticStorage();
        s.symbioticCollateral = _symbioticCollateral;
        emit SymbioticCollateralSet(address(_symbioticCollateral), block.timestamp);
    }

    /**
     * @notice Sets a new Symbiotic Vault address in the vault's storage.
     * @param _symbioticVault The address of the new Symbiotic Vault to be set.
     *
     * @custom:effects
     * - Updates the Symbiotic Vault address in the storage.
     * - Emits the `SymbioticVaultSet` event with the new Symbiotic Vault address and the current timestamp.
     */
    function _setSymbioticVault(ISymbioticVault _symbioticVault) internal {
        SymbioticStorage storage s = _symbioticStorage();
        s.symbioticVault = _symbioticVault;
        emit SymbioticVaultSet(address(_symbioticVault), block.timestamp);
    }

    /**
     * @notice Sets a new Withdrawal Queue address in the vault's storage.
     * @param _withdrawalQueue The address of the new Withdrawal Queue to be set.
     *
     * @custom:effects
     * - Updates the Withdrawal Queue address in storage.
     * - Emits the `WithdrawalQueueSet` event with the new Withdrawal Queue address and the current timestamp.
     */
    function _setWithdrawalQueue(IWithdrawalQueue _withdrawalQueue) internal {
        SymbioticStorage storage s = _symbioticStorage();
        s.withdrawalQueue = _withdrawalQueue;
        emit WithdrawalQueueSet(address(_withdrawalQueue), block.timestamp);
    }

    /**
     * @notice Sets a new Farm with the provided `farmId` and `farmData` in the vault's storage.
     * @param farmId The ID of the farm to be added or updated.
     * @param farmData The data structure containing details of the new or updated farm.
     *
     * @custom:effects
     * - Updates the storage with the provided `farmData` for the given `farmId`.
     * - Adds the `farmId` to the list of active farm IDs if the farm has a valid reward token address.
     * - Removes the `farmId` from the list of active farm IDs if the reward token address is zero.
     * - Emits the `FarmSet` event with the `farmId`, `farmData`, and the current timestamp.
     */
    function _setFarm(uint256 farmId, FarmData memory farmData) internal {
        SymbioticStorage storage s = _symbioticStorage();
        s.farms[farmId] = farmData;
        if (farmData.rewardToken != address(0)) {
            s.farmIds.add(farmId);
        } else {
            s.farmIds.remove(farmId);
        }
        emit FarmSet(farmId, farmData, block.timestamp);
    }

    /**
     * @notice Accesses the Symbiotic Vault storage slot.
     * @return $ A reference to the SymbioticStorage struct stored in the specified slot.
     *
     * @dev This function uses inline assembly to access a predefined storage slot.
     */
    function _symbioticStorage() private view returns (SymbioticStorage storage $) {
        bytes32 slot = storageSlotRef;
        assembly {
            $.slot := slot
        }
    }
}
