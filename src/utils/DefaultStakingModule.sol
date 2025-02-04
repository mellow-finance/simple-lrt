// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/tokens/IWETH.sol";
import "../interfaces/tokens/IWSTETH.sol";
import "../interfaces/utils/IStakingModule.sol";
import "@openzeppelin/contracts/access/IAccessControl.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract DefaultStakingModule is IStakingModule {
    bytes32 public constant STAKE_ROLE = keccak256("STAKE_ROLE");
    IWSTETH public immutable WSTETH;
    IWETH public immutable WETH;

    constructor(address wsteth_, address weth_) {
        WSTETH = IWSTETH(wsteth_);
        WETH = IWETH(weth_);
    }

    function stake(bytes calldata, /* data */ address caller) external {
        address this_ = address(this);
        require(IAccessControl(this_).hasRole(STAKE_ROLE, caller), "StakingModule: forbidden");
        forceStake(WETH.balanceOf(this_));
    }

    function forceStake(uint256 amount) public {
        WETH.withdraw(amount);
        Address.sendValue(payable(address(WSTETH)), amount);
    }
}
