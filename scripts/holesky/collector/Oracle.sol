// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "./IOracle.sol";

contract Oracle {
    uint256 public constant Q96 = 2 ** 96;

    address public owner;
    mapping(address token => address) oracles;

    constructor(address owner_) {
        owner = owner_;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "EthOracle: not owner");
        _;
    }

    function setOwner(address owner_) external onlyOwner {
        owner = owner_;
    }

    function setEthOracles(address[] calldata tokens_, address[] calldata oracles_)
        external
        onlyOwner
    {
        require(tokens_.length == oracles_.length, "EthOracle: invalid input");
        for (uint256 i = 0; i < tokens_.length; i++) {
            oracles[tokens_[i]] = oracles_[i];
        }
    }

    /// @dev returns price in Q96 math in ETH for `token`
    function priceX96(address token) public view returns (uint256 priceX96) {
        if (token == STETH || token == WETH || token == ETH) {
            return Q96;
        }
        return IOracle(oracles[token]).priceX96();
    }

    /// @dev returns price in Q96 math in `priceToken` for `token`
    function priceX96(address token, address priceToken) external view returns (uint256) {
        return Math.mulDiv(getEthPriceX96(token), Q96, getEthPriceX96(priceToken));
    }

    function getValue(address token, uint256 amount) public view returns (uint256) {
        return Math.mulDiv(priceX96(token), amount, Q96);
    }

    function getValue(address token, address priceToken, uint256 amount)
        public
        view
        returns (uint256)
    {
        return Math.mulDiv(priceX96(token, priceToken), amount, Q96);
    }
}
