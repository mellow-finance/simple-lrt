// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {
    ERC20VotesUpgradeable,
    ERC20Upgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol";

import {Vault, VaultStorage} from "./Vault.sol";

contract SimpleVault is ERC20VotesUpgradeable, Vault {
    using SafeERC20 for IERC20;

    constructor(string memory name, uint256 version)
        VaultStorage(keccak256(abi.encodePacked(name)), version)
    {}

    function initializeWithERC20(
        address _symbioticCollateral,
        address _symbioticVault,
        address _withdrawalQueue,
        uint256 _limit,
        bool _paused,
        address _admin,
        string memory name,
        string memory symbol
    ) external initializer {
        __ERC20_init(name, symbol);
        __EIP712_init(name, "1");
        __AccessManager_init(_admin);

        __initializeStorage(
            _symbioticCollateral, _symbioticVault, _withdrawalQueue, _limit, _paused
        );
    }

    function _update(address from, address to, uint256 amount)
        internal
        override(Vault, ERC20VotesUpgradeable)
    {
        super._update(from, to, amount);
    }

    function _deposit(address depositToken, uint256 amount) internal virtual override {
        if (depositToken != asset()) {
            revert("SimpleVault: invalid token");
        }
        IERC20(depositToken).safeTransferFrom(_msgSender(), address(this), amount);
    }

    function balanceOf(address account)
        public
        view
        override(Vault, ERC20Upgradeable)
        returns (uint256)
    {
        return ERC20Upgradeable.balanceOf(account);
    }

    function totalSupply() public view override(Vault, ERC20Upgradeable) returns (uint256) {
        return ERC20Upgradeable.totalSupply();
    }
}
