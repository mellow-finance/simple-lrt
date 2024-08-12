// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.26;

import "./interfaces/IWETH.sol";
import "./interfaces/ISTETH.sol";
import "./interfaces/IWSTETH.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol";

import "./Vault.sol";
import "./EthWrapper.sol";

contract EthVaultV1 is ERC20VotesUpgradeable, Vault, EthWrapper {
    // ERC20 slots
    mapping(address account => uint256) private _balances;
    mapping(address account => mapping(address spender => uint256)) private _allowances;
    uint256 private _totalSupply;
    string private _name;
    string private _symbol;

    // ERC20 && ERC20Upgradeable merge
    function name() public view virtual override(ERC20Upgradeable) returns (string memory) {
        return _name;
    }

    function symbol() public view virtual override(ERC20Upgradeable) returns (string memory) {
        return _symbol;
    }

    function totalSupply() public view virtual override(ERC20Upgradeable, Vault) returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view virtual override(ERC20Upgradeable, Vault) returns (uint256) {
        return _balances[account];
    }

    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    /// @dev added early revert for paused state
    /// @dev merged ERC20 -> ERC20VotesUpgradeable: in ERC20VotesUpgradeable/ERC20Upgradeable replaces all $ -> direct storage access
    function _update(address from, address to, uint256 value) internal virtual override {
        // ERC20Pausable
        if (paused()) revert("BaseVault: paused");
        // ERC20
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
        // ERC20Votes
        if (from == address(0)) {
            uint256 supply = totalSupply();
            uint256 cap = _maxSupply();
            if (supply > cap) {
                revert ERC20ExceededSafeSupply(supply, cap);
            }
        }
        _transferVotingUnits(from, to, value);
    }

    function _approve(address owner, address spender, uint256 value, bool emitEvent) internal virtual override {
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

    function _deposit(address depositToken, uint256 amount) internal override {
        _wrap(depositToken, amount);
    }

    function _doBurn(address account, uint256 amount) internal override {
        ERC20Upgradeable._burn(account, amount);
    }

    function _doMint(address account, uint256 amount) internal override {
        ERC20Upgradeable._mint(account, amount);
    }
}
