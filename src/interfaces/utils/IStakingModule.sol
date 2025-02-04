// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

interface IStakingModule {
    function stake(bytes calldata data, address caller) external;

    function forceStake(uint256 amount) external;
}
