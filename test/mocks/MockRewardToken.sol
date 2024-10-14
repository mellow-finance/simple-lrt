// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockRewardToken is ERC20 {
    constructor(string memory name_, string memory symbol_, uint256 totalSupply_)
        ERC20(name_, symbol_)
    {
        _mint(msg.sender, totalSupply_);
    }
}
