// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import {
    ERC20Upgradeable,
    ERC20VotesUpgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {ERC4626Upgradeable, MellowSymbioticVault} from "./MellowSymbioticVault.sol";

contract MellowSymbioticVotesVault is MellowSymbioticVault, ERC20VotesUpgradeable {
    using SafeERC20 for IERC20;

    constructor(string memory name, uint256 version)
        MellowSymbioticVault(keccak256(abi.encodePacked(name)), version)
    {}

    function initializeMellowSymbioticVotesVault(
        address _symbioticVault,
        address _withdrawalQueue,
        uint256 _limit,
        bool _depositPause,
        bool _withdrawalPause,
        bool _depositWhitelist,
        address _admin,
        string memory _name,
        string memory _symbol
    ) external initializer {
        initializeMellowSymbioticVault(
            _symbioticVault,
            _withdrawalQueue,
            _limit,
            _depositPause,
            _withdrawalPause,
            _depositWhitelist,
            _admin,
            _name,
            _symbol
        );

        __EIP712_init(_name, "1");
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
