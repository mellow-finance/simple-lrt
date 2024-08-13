// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import {ERC20, Context} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ContextUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";

import {Vault, VaultStorage} from "./Vault.sol";
import {EthWrapper} from "./EthWrapper.sol";

contract EthVaultV1 is ERC20, Vault, EthWrapper {
    constructor() ERC20("Default", "Default") VaultStorage("EthVaultV1", 1) {}

    function initialize(
        address _symbioticCollateral,
        address _symbioticVault,
        uint256 _limit,
        bool _paused,
        address _admin
    ) external initializer {
        __initializeStorage(_symbioticCollateral, _symbioticVault, _limit, _paused);
        __initializeRoles(_admin);
    }

    function _msgSender() internal view override(Context, ContextUpgradeable) returns (address) {
        return Context._msgSender();
    }

    function _msgData()
        internal
        view
        override(Context, ContextUpgradeable)
        returns (bytes calldata)
    {
        return Context._msgData();
    }

    function _contextSuffixLength()
        internal
        view
        override(Context, ContextUpgradeable)
        returns (uint256)
    {
        return Context._contextSuffixLength();
    }

    function _update(address from, address to, uint256 value)
        internal
        virtual
        override(Vault, ERC20)
    {
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
