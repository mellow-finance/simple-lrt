// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "./Vault.sol";
import "./EthWrapper.sol";

contract EthVaultV1 is ERC20, Vault, EthWrapper {
    constructor() ERC20("Vault", "Vault") {}

    function _update(address from, address to, uint256 value) internal virtual override(Vault, ERC20) {
        super._update(from, to, value);
    }

    function _deposit(address depositToken, uint256 amount) internal override {
        _wrap(depositToken, amount);
    }

    function balanceOf(address account) public view override(Vault, ERC20) returns (uint256) {
        return ERC20.balanceOf(account);
    }

    function totalSupply() public view override(Vault, ERC20) returns (uint256) {
        return ERC20.totalSupply();
    }
}
