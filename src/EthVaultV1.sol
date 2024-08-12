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
    function _doBurn(address account, uint256 amount) internal override {
        ERC20._burn(account, amount);
    }

    function _doMint(address account, uint256 amount) internal override {
        ERC20._mint(account, amount);
    }

    function balanceOf(
        address account
    ) public view override(Vault, ERC20) returns (uint256) {
        return ERC20.balanceOf(account);
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
