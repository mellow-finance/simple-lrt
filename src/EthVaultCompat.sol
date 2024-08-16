// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import {ERC20Upgradeable} from
    "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {ERC4626Upgradeable} from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import {ContextUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import {
    Context, ERC20, IERC20, IERC20Metadata
} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {MellowSymbioticVault, MellowSymbioticVaultStorage} from "./MellowSymbioticVault.sol";

contract EthVaultCompat is MellowSymbioticVault {
    // ERC20 slots
    mapping(address account => uint256) private _balances;
    mapping(address account => mapping(address spender => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    constructor() MellowSymbioticVault("EthVaultV1", 1) {}

    function initializeEthVaultCompat(
        address _symbioticVault,
        address _withdrawalQueue,
        uint256 _limit,
        bool _depositPause,
        bool _withdrawalPause,
        bool _depositWhitelist,
        address _admin
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
    }

    // ERC20Upgradeable override

    function _update(address from, address to, uint256 value) internal virtual override {
        if (from == address(0)) {
            // Overflow check required: The rest of the code assumes that totalSupply never overflows
            _totalSupply += value;
        } else {
            uint256 fromBalance = _balances[from];
            if (fromBalance < value) {
                revert ERC20InsufficientBalance(from, fromBalance, value);
            }
            unchecked {
                // Overflow not possible: value <= fromBalance <= totalSupply.
                _balances[from] = fromBalance - value;
            }
        }

        if (to == address(0)) {
            unchecked {
                // Overflow not possible: value <= totalSupply or value <= fromBalance <= totalSupply.
                _totalSupply -= value;
            }
        } else {
            unchecked {
                // Overflow not possible: balance + value is at most totalSupply, which we know fits into a uint256.
                _balances[to] += value;
            }
        }

        emit Transfer(from, to, value);
    }

    function balanceOf(address account)
        public
        view
        override(IERC20, ERC20Upgradeable)
        returns (uint256)
    {
        return _balances[account];
    }

    function allowance(address owner, address spender)
        public
        view
        override(IERC20, ERC20Upgradeable)
        returns (uint256)
    {
        return _allowances[owner][spender];
    }

    function _approve(address owner, address spender, uint256 value, bool emitEvent)
        internal
        virtual
        override
    {
        if (owner == address(0)) {
            revert ERC20InvalidApprover(address(0));
        }
        if (spender == address(0)) {
            revert ERC20InvalidSpender(address(0));
        }
        _allowances[owner][spender] = value;
        if (emitEvent) {
            emit Approval(owner, spender, value);
        }
    }

    function totalSupply() public view override(IERC20, ERC20Upgradeable) returns (uint256) {
        return _totalSupply;
    }

    function symbol()
        public
        view
        override(IERC20Metadata, ERC20Upgradeable)
        returns (string memory)
    {
        return _symbol;
    }

    function name()
        public
        view
        override(IERC20Metadata, ERC20Upgradeable)
        returns (string memory)
    {
        return _name;
    }
}
