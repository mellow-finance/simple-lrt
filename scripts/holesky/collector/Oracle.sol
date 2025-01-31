// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "./IOracle.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

contract Oracle {
    uint256 public constant Q96 = 2 ** 96;

    struct TokenOracle {
        uint256 constValue;
        address oracle;
    }

    address public owner;
    mapping(address token => TokenOracle) public oracles;

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

    function setOracles(address[] calldata tokens_, TokenOracle[] calldata oracles_)
        external
        onlyOwner
    {
        require(tokens_.length == oracles_.length, "EthOracle: invalid input");
        for (uint256 i = 0; i < tokens_.length; i++) {
            oracles[tokens_[i]] = oracles_[i];
        }
    }

    /// @dev returns price in Q96 math in ETH for `token`
    function priceX96(address token) public view returns (uint256) {
        TokenOracle memory oracle = oracles[token];
        if (oracle.constValue != 0) {
            return oracle.constValue;
        }
        if (oracle.oracle == address(0)) {
            revert("EthOracle: no oracle");
        }
        return IOracle(oracle.oracle).priceX96();
    }

    /// @dev returns price in Q96 math in `priceToken` for `token`
    function priceX96(address token, address priceToken) public view returns (uint256) {
        return Math.mulDiv(priceX96(token), Q96, priceX96(priceToken));
    }

    function getValue(address token, uint256 amount) public view returns (uint256) {
        if (amount > type(uint224).max) {
            return type(uint256).max;
        }
        return Math.mulDiv(priceX96(token), amount, Q96);
    }

    function getValue(address token, address priceToken, uint256 amount)
        public
        view
        returns (uint256)
    {
        if (amount > type(uint224).max) {
            return type(uint256).max;
        }
        return Math.mulDiv(priceX96(token, priceToken), amount, Q96);
    }
}
