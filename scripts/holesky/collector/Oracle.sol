// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts/utils/math/Math.sol";

interface IOracle {
    function priceX96() external view returns (uint256);
}

contract Oracle {
    uint256 private constant Q96 = 2 ** 96;

    address public immutable wsteth;
    address public immutable weth;
    address public immutable steth;
    address public constant eth = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address public immutable usdc;
    address public immutable owner;

    mapping(address => address) public usdOracle;
    mapping(address => address) public ethOracle;

    function setUsdOracle(address token, address oracle) public {
        require(msg.sender == owner, "Oracle: not owner");
        usdOracle[token] = oracle;
    }

    function setEthOracle(address token, address oracle) public {
        require(msg.sender == owner, "Oracle: not owner");
        ethOracle[token] = oracle;
    }

    constructor(address owner_, address wsteth_, address weth_, address steth_, address usdc_) {
        wsteth = wsteth_;
        weth = weth_;
        steth = steth_;
        owner = owner_;
        usdc = usdc_;
    }

    function getUsdPrice(address token) public view returns (uint256 priceX96) {
        if (token == usdc) {
            return Q96;
        }
        address usdOracle = usdOracle[token];
        address ethOracle = ethOracle[token];
        require(usdOracle != address(0) || ethOracle != address(0), "Oracle: usd oracle not set");

        if (usdOracle != address(0)) {
            return IOracle(usdOracle).priceX96();
        }

        return getUsdValue(weth, getEthPrice(token));
    }

    function getEthPrice(address token) public view returns (uint256 priceX96) {
        if (token == eth || token == steth || token == weth) {
            return Q96;
        }

        address ethOracle = ethOracle[token];
        address usdOracle = usdOracle[token];
        require(ethOracle != address(0) || usdOracle != address(0), "Oracle: eth oracle not set");

        if (ethOracle != address(0)) {
            return IOracle(ethOracle).priceX96();
        }
        return getEthValue(usdc, getUsdPrice(token));
    }

    function getUsdValue(address token, uint256 amount) public view returns (uint256 value) {
        uint256 priceX96 = getUsdPrice(token);
        value = Math.mulDiv(amount, priceX96, Q96);
    }

    function getEthValue(address token, uint256 amount) public view returns (uint256 value) {
        uint256 priceX96 = getEthPrice(token);
        value = Math.mulDiv(amount, priceX96, Q96);
    }
}
