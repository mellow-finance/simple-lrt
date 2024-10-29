// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@symbiotic/rewards/interfaces/stakerRewards/IStakerRewards.sol";

import "./Imports.sol";

contract MockStakingRewards is IStakerRewards {
    function test() external pure {}

    function claimable(address token, address account, bytes calldata /* data */ )
        external
        view
        returns (uint256)
    {
        return rewards[token][account];
    }

    function claimRewards(address recipient, address token, bytes calldata /* data */ ) external {
        uint256 amount = rewards[token][msg.sender];
        rewards[token][msg.sender] = 0;
        IERC20(token).transfer(recipient, amount);
    }

    mapping(address token => mapping(address account => uint256)) public rewards;

    function increaseRewards(address account, address token, uint256 amount) external {
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        rewards[token][account] += amount;
    }

    function distributeRewards(address network, address token, uint256 amount, bytes calldata data)
        external
    {}

    function version() external pure returns (uint64) {
        return 1;
    }
}
