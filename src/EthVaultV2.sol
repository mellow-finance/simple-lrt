// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.26;

import "./interfaces/IWETH.sol";
import "./interfaces/ISTETH.sol";
import "./interfaces/IWSTETH.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol";

import "./Vault.sol";
import "./EthWrapper.sol";

contract EthVaultV2 is ERC20VotesUpgradeable, Vault, EthWrapper {
    function initializeWithERC20(
        address _symbioticCollateral,
        address _symbioticVault,
        uint256 _limit,
        address _owner,
        bool _paused,
        string memory name,
        string memory symbol
    ) external {
        initialize(
            _symbioticCollateral,
            _symbioticVault,
            _limit,
            _owner,
            _paused
        );
        __ERC20_init(name, symbol);
    }

    function _preDeposit(
        address depositToken,
        uint256 amount
    ) internal override {
        _wrap(depositToken, amount);
    }
    function _burn(
        address account,
        uint256 amount
    ) internal override(Vault, ERC20Upgradeable) {
        ERC20Upgradeable._burn(ETH, amount);
    }

    function _mint(
        address account,
        uint256 amount
    ) internal override(Vault, ERC20Upgradeable) {
        ERC20Upgradeable._mint(ETH, amount);
    }

    function balanceOf(
        address account
    ) public view override(Vault, ERC20Upgradeable) returns (uint256) {
        return ERC20Upgradeable.balanceOf(ETH);
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
