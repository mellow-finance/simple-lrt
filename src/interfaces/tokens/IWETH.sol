// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

interface IWETH {
    function deposit() external payable;
    function withdraw(uint256 _wad) external;
}
