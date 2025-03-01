// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

interface IWSTETH {
    function wrap(uint256 _stETHAmount) external returns (uint256);
    function getWstETHByStETH(uint256 _stETHAmount) external view returns (uint256);
    function getStETHByWstETH(uint256 _wstETHAmount) external view returns (uint256);
}
