// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.26;

import "./interfaces/IWETH.sol";
import "./interfaces/ISTETH.sol";
import "./interfaces/IWSTETH.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "./Vault.sol";
import "./EthWrapper.sol";

contract EthVaultV1 is ERC20, Vault, EthWrapper {
    constructor() ERC20("Default", "Default") {}

    function _preDeposit(
        address depositToken,
        uint256 amount
    ) internal override {
        _wrap(depositToken, amount);
    }
    function _burn(
        address account,
        uint256 amount
    ) internal override(Vault, ERC20) {
        ERC20._burn(ETH, amount);
    }

    function _mint(
        address account,
        uint256 amount
    ) internal override(Vault, ERC20) {
        ERC20._mint(ETH, amount);
    }

    function balanceOf(
        address account
    ) public view override(Vault, ERC20) returns (uint256) {
        return ERC20.balanceOf(ETH);
    }

    function totalSupply()
        public
        view
        override(Vault, ERC20)
        returns (uint256)
    {
        return ERC20.totalSupply();
    }
}
