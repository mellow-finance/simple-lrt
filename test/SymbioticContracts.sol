// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import {DelegatorFactory} from "@symbiotic/core/contracts/DelegatorFactory.sol";
import {SlasherFactory} from "@symbiotic/core/contracts/SlasherFactory.sol";
import {VaultConfigurator} from "@symbiotic/core/contracts/VaultConfigurator.sol";
import {VaultFactory} from "@symbiotic/core/contracts/VaultFactory.sol";
import {FullRestakeDelegator} from "@symbiotic/core/contracts/delegator/FullRestakeDelegator.sol";
import {Slasher} from "@symbiotic/core/contracts/slasher/Slasher.sol";

import {Vault} from "@symbiotic/core/contracts/vault/Vault.sol";

contract SymbioticContracts {
    address public immutable VAULT_FACTORY;
    address public immutable DELEGATOR_FACTORY;
    address public immutable SLASHER_FACTORY;
    address public immutable VAULT_CONFIGURATOR;

    // holesky deployment
    address public constant NETWORK_MIDDLEWARE_SERVICE = 0x70818a53ddE5c2e78Edfb6f6b277Be9a71fa894E;
    address public constant NETWORK_REGISTRY = 0x5dEA088d2Be1473d948895cc26104bcf103CEf3E;
    address public constant OPERATOR_VAULT_OPT_IN_SERVICE =
        0x63E459f3E2d8F7f5E4AdBA55DE6c50CbB43dD563;
    address public constant OPERATOR_NETWORK_OPT_IN_SERVICE =
        0x973ba45986FF71742129d23C4138bb3fAd4f13A5;

    constructor() {
        // fresh symbiotic deployment
        address this_ = address(this);
        VAULT_FACTORY = address(new VaultFactory(this_));
        DELEGATOR_FACTORY = address(new DelegatorFactory(this_));
        SLASHER_FACTORY = address(new SlasherFactory(this_));

        VAULT_CONFIGURATOR =
            address(new VaultConfigurator(VAULT_FACTORY, DELEGATOR_FACTORY, SLASHER_FACTORY));
        {
            address singleton =
                address(new Vault(DELEGATOR_FACTORY, SLASHER_FACTORY, VAULT_FACTORY));
            VaultFactory(VAULT_FACTORY).whitelist(singleton);
        }

        {
            address singleton = address(
                new FullRestakeDelegator(
                    NETWORK_REGISTRY,
                    VAULT_FACTORY,
                    OPERATOR_VAULT_OPT_IN_SERVICE,
                    OPERATOR_NETWORK_OPT_IN_SERVICE,
                    DELEGATOR_FACTORY,
                    uint64(0)
                )
            );
            DelegatorFactory(DELEGATOR_FACTORY).whitelist(singleton);
        }

        {
            address singleton = address(
                new Slasher(VAULT_FACTORY, NETWORK_MIDDLEWARE_SERVICE, SLASHER_FACTORY, uint64(0))
            );
            SlasherFactory(SLASHER_FACTORY).whitelist(singleton);
        }
    }

    function test() external pure {}
}
