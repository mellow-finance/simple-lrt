// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "./ISTETH.sol";

/**
 * @title IWSTETH
 * @notice Interface for interacting with wstETH (Wrapped stETH).
 * @dev Extends the `IERC20` interface and includes additional functionality for wrapping and unwrapping stETH.
 */
interface IWSTETH is IERC20 {
    /**
     * @notice Wraps stETH into wstETH.
     * @param _stETHAmount The amount of stETH to wrap.
     * returns the amount of wstETH minted.
     */
    function wrap(uint256 _stETHAmount) external returns (uint256);

    /**
     * @notice Unwraps wstETH into stETH.
     * @param _wstETHAmount The amount of wstETH to unwrap.
     * returns the amount of stETH returned.
     */
    function unwrap(uint256 _wstETHAmount) external returns (uint256);

    /**
     * @notice Converts stETH to its equivalent wstETH amount.
     * @param _stETHAmount The amount of stETH to convert.
     * returns the equivalent amount of wstETH.
     */
    function getWstETHByStETH(uint256 _stETHAmount) external view returns (uint256);

    /**
     * @notice Converts wstETH to its equivalent stETH amount.
     * @param _wstETHAmount The amount of wstETH to convert.
     * returns the equivalent amount of stETH.
     */
    function getStETHByWstETH(uint256 _wstETHAmount) external view returns (uint256);

    /**
     * @notice Returns the address of the underlying stETH contract.
     * returns the address of the stETH contract.
     */
    function stETH() external view returns (ISTETH);
}
