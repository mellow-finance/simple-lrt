// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../Imports.sol";

contract MockMultiVault {
    bool private flag;

    address public asset;
    address public defaultCollateral;

    function setAsset(address asset_) external {
        asset = asset_;
    }

    function setDefaultCollateral(address defaultCollateral_) external {
        defaultCollateral = defaultCollateral_;
    }

    function setFlag(bool flag_) external {
        flag = flag_;
    }

    function hasRole(bytes32, /* role_ */ address /* account_ */ ) external view returns (bool) {
        return flag;
    }

    struct Data {
        address vault;
        uint256 deposit;
        uint256 claimable;
        uint256 pending;
        uint256 staked;
    }

    Data[] private _subvaults;

    function setSubvaults(Data[] memory data) external {
        while (_subvaults.length > 0) {
            _subvaults.pop();
        }
        for (uint256 i = 0; i < data.length; i++) {
            _subvaults.push(data[i]);
        }
    }

    function indexOfSubvault(address subvault) external view returns (uint256) {
        for (uint256 i = 0; i < _subvaults.length; i++) {
            if (_subvaults[i].vault == subvault) {
                return i + 1;
            }
        }
        return 0;
    }

    function maxDeposit(uint256 subvaultIndex) external view returns (uint256) {
        return _subvaults[subvaultIndex].deposit;
    }

    function subvaultAt(uint256 index) external view returns (IMultiVault.Subvault memory s) {
        s.vault = _subvaults[index].vault;
    }

    function assetsOf(uint256 subvaultIndex)
        external
        view
        returns (uint256 claimable, uint256 pending, uint256 staked)
    {
        claimable = _subvaults[subvaultIndex].claimable;
        pending = _subvaults[subvaultIndex].pending;
        staked = _subvaults[subvaultIndex].staked;
    }

    function subvaultsCount() external view returns (uint256) {
        return _subvaults.length;
    }

    function testMockMultiVault() internal pure {}
}
