// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import "../Imports.sol";

contract MockMellowSymbioticVault is ERC20 {
    address public immutable wsteth = 0x8d09a4502Cc8Cf1547aD300E066060D043f6982D;

    constructor() ERC20("MockMellowSymbioticVault", "MSV") {}

    bool public isDepositLimit = false;
    uint256 public depositLimit = 0;
    bool public depositWhitelist = false;
    uint256 public loss = 0;

    function collateral() external view returns (address) {
        return wsteth;
    }

    function activeBalanceOf(address user) external view returns (uint256) {
        return balanceOf(user);
    }

    function setLimit(bool _isDepositLimit, uint256 _depositLimit) external {
        isDepositLimit = _isDepositLimit;
        depositLimit = _depositLimit;
    }

    function totalStake() external view returns (uint256) {
        return IERC20(wsteth).balanceOf(address(this));
    }

    function setLoss() external {
        loss = loss ^ 1;
    }

    function deposit(address onBehalfOf, uint256 amount)
        external
        returns (uint256 depositedAmount, uint256 mintedShares)
    {
        IERC20(wsteth).transferFrom(onBehalfOf, address(this), amount);
        _mint(onBehalfOf, amount);
        depositedAmount = amount - loss;
        mintedShares = amount;
    }

    function test() private pure {}
}
