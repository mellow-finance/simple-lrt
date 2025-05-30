// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../AbstractDeployScript.sol";

abstract contract AbstractDeployLibrary {
    address private immutable _this;

    modifier onlyDelegateCall() {
        require(address(this) != _this, "AbstractDeployLibrary: must be called via delegatecall");
        _;
    }

    constructor() {
        _this = address(this);
    }

    function subvaultType() external view virtual returns (uint256);

    function deployAndSetAdapter(
        address multiVault,
        AbstractDeployScript.Config calldata config,
        bytes calldata data
    ) external virtual;

    function deploySubvault(
        address multiVault,
        AbstractDeployScript.Config calldata config,
        bytes calldata data
    ) external virtual returns (address);
}
