// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import {
    ERC20Upgradeable,
    ERC20VotesUpgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {ERC4626Upgradeable, MellowSymbioticVault} from "./MellowSymbioticVault.sol";

contract VotesVault is MellowSymbioticVault, ERC20VotesUpgradeable {
    using SafeERC20 for IERC20;

    constructor(string memory name, uint256 version)
        MellowSymbioticVault(keccak256(abi.encodePacked(name)), version)
    {}

    function initializeWithERC20(
        address _symbioticCollateral,
        address _symbioticVault,
        address _withdrawalQueue,
        uint256 _limit,
        bool _depositPause,
        bool _withdrawalPause,
        bool _depositWhitelist,
        address _admin,
        string memory name,
        string memory symbol
    ) external initializer {
        __ERC20_init(name, symbol);
        __EIP712_init(name, "1");
        __AccessManager_init(_admin);

        __initializeMellowSymbioticVaultStorage(
            _symbioticCollateral, _symbioticVault, _withdrawalQueue
        );

        __initializeVaultControlStorage(_limit, _depositPause, _withdrawalPause, _depositWhitelist);
    }

    function decimals()
        public
        view
        override(ERC4626Upgradeable, ERC20Upgradeable)
        returns (uint8)
    {
        return ERC4626Upgradeable.decimals();
    }

    function _update(address from, address to, uint256 amount)
        internal
        override(MellowSymbioticVault, ERC20VotesUpgradeable)
    {
        super._update(from, to, amount);
    }
}
