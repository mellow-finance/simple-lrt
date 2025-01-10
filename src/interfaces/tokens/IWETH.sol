// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

/**
 * @title IWETH
 * @notice Interface for interacting with WETH (Wrapped Ether).
 * @dev Provides methods to wrap and unwrap ETH into WETH.
 */
interface IWETH {
    /**
     * @notice Deposits ETH into the contract to mint WETH.
     * @dev Equivalent amount of WETH is minted and credited to the caller.
     */
    function deposit() external payable;

    /**
     * @notice Withdraws ETH from the contract by burning WETH.
     * @param _wad The amount of WETH to burn for withdrawing ETH.
     */
    function withdraw(uint256 _wad) external;
}
