// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title ISTETH
 * @notice Interface for interacting with the stETH token from Lido.
 * @dev Extends the `IERC20` interface and includes additional functionality for submitting ETH to mint stETH.
 */
interface ISTETH is IERC20 {
    /**
     * @notice Submits ETH to the Lido protocol in exchange for stETH.
     * @param _referral The address of the referral (optional, can be set to zero address).
     * returns the amount of stETH minted in exchange for the submitted ETH.
     */
    function submit(address _referral) external payable returns (uint256);
}
