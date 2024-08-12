// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import "./interfaces/IVaultStorage.sol";

contract VaultStorage is IVaultStorage {
    using EnumerableSet for EnumerableSet.AddressSet;

    uint256 public constant VERSION = 1;
    bytes32 public constant NAME = keccak256("Vault");
    // keccak256(abi.encode(uint256(keccak256("mellow.simple-lrt.storage.VaultStorage")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 public constant storageSlotRef = 0x1f29c05ab79b0f5912eb538f64277220bb5e44f5c0d8d47a80a4de692e2a2200;

    function initialize(
        address _symbioticCollateral,
        address _symbioticVault,
        uint256 _limit,
        address _owner,
        bool _paused
    ) public {
        if (owner() != address(0)) {
            revert("VaultStorage: already initialized");
        }
        _setSymbioticCollateral(IDefaultCollateral(_symbioticCollateral));
        _setSymbioticVault(ISymbioticVault(_symbioticVault));
        _setLimit(_limit);
        _setOwner(_owner);
        _setToken(IDefaultCollateral(_symbioticCollateral).asset());
        _setPaused(_paused);
    }

    function symbioticCollateral() public view returns (IDefaultCollateral) {
        return _contractStorage().symbioticCollateral;
    }

    function symbioticVault() public view returns (ISymbioticVault) {
        return _contractStorage().symbioticVault;
    }

    function token() public view returns (address) {
        return _contractStorage().token;
    }

    function owner() public view returns (address) {
        return _contractStorage().owner;
    }

    function paused() public view returns (bool) {
        return _contractStorage().paused;
    }

    function limit() public view returns (uint256) {
        return _contractStorage().limit;
    }

    function symbioticRewardTokens() public view returns (address[] memory) {
        return _contractStorage().rewardTokens.values();
    }

    function symbioticFarm(address rewardToken) public view returns (FarmData memory) {
        return _contractStorage().farms[rewardToken];
    }

    function _setLimit(uint256 _limit) internal {
        Storage storage s = _contractStorage();
        s.limit = _limit;
    }

    function _setPaused(bool _paused) internal {
        Storage storage s = _contractStorage();
        s.paused = _paused;
    }

    function _setSymbioticCollateral(IDefaultCollateral _symbioticCollateral) internal {
        Storage storage s = _contractStorage();
        s.symbioticCollateral = _symbioticCollateral;
    }

    function _setSymbioticVault(ISymbioticVault _symbioticVault) internal {
        Storage storage s = _contractStorage();
        s.symbioticVault = _symbioticVault;
    }

    function _setToken(address _token) internal {
        Storage storage s = _contractStorage();
        s.token = _token;
    }

    function _setOwner(address _owner) internal {
        Storage storage s = _contractStorage();
        s.owner = _owner;
    }

    function _setSymbioticFarm(address rewardToken, FarmData memory farmData) internal {
        Storage storage s = _contractStorage();
        s.farms[rewardToken] = farmData;
        s.rewardTokens.add(rewardToken);
    }

    function _removeSymbioticFarm(address rewardToken) internal {
        Storage storage s = _contractStorage();
        delete s.farms[rewardToken];
        s.rewardTokens.remove(rewardToken);
    }

    function _contractStorage() private pure returns (Storage storage $) {
        assembly {
            $.slot := storageSlotRef
        }
    }
}
