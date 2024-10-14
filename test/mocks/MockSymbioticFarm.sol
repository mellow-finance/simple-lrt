// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../Imports.sol";

contract MockSymbioticFarm is IStakerRewards {
    function version() external pure returns (uint64) {
        return 1;
    }

    function claimable(address, address, bytes calldata) external pure returns (uint256) {
        return 0;
    }

    function distributeRewards(address network, address token, uint256 amount, bytes calldata data)
        external
    {}

    function claimRewards(address recipient, address token, bytes calldata /* data */ ) external {
        IERC20(token).transfer(recipient, IERC20(token).balanceOf(address(this)));
    }

    function test() private pure {}
}
