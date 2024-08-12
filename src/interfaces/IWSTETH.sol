// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.26;

interface IWSTETH {
    function wrap(uint256 _stETHAmount) external returns (uint256);

    function getWstETHByStETH(uint256 _stETHAmount) external view returns (uint256);
    function getStETHByWstETH(uint256 _wstETHAmount) external view returns (uint256);
}
