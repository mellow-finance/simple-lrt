// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import {ERC4626Upgradeable, MellowSymbioticVault} from "./MellowSymbioticVault.sol";
import "./interfaces/vaults/IMellowSymbioticVotesVault.sol";

contract MellowSymbioticVotesVault is
    IMellowSymbioticVotesVault,
    MellowSymbioticVault,
    ERC20VotesUpgradeable
{
    constructor(string memory name, uint256 version)
        MellowSymbioticVault(keccak256(abi.encodePacked(name)), version)
    {}

    function initialize(IMellowSymbioticVault.InitParams memory initParams)
        public
        virtual
        override
        initializer
    {
        super.initialize(initParams);
        __EIP712_init(initParams.name, "1");
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
