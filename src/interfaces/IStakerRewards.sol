// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

interface IStakerRewards {
    /**
     * @notice Get an amount of rewards claimable by a particular account of a given token.
     * @param token address of the token
     * @param account address of the claimer
     * @param data some data to use
     * @return amount of claimable tokens
     */
    function claimable(
        address token,
        address account,
        bytes calldata data
    ) external view returns (uint256);

    /**
     * @notice Claim rewards using a given token.
     * @param recipient address of the tokens' recipient
     * @param token address of the token
     * @param data some data to use
     */
    function claimRewards(
        address recipient,
        address token,
        bytes calldata data
    ) external;
}
