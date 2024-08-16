// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

// import {
//     IERC20, IERC20Metadata, ERC20, Context
// } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
// import {ContextUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
// import {ERC20Upgradeable} from
//     "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
// import {ERC4626Upgradeable} from
//     "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";

// import {Vault, VaultStorage} from "./Vault.sol";

// // ffs
// contract EthVaultV1 is ERC20, Vault {
//     constructor() ERC20("Default", "Default") VaultStorage("EthVaultV1", 1) {}

//     function initialize(
//         address _symbioticCollateral,
//         address _symbioticVault,
//         address _withdrawalQueue,
//         uint256 _limit,
//         bool _paused,
//         address _admin
//     ) external initializer {
//         __AccessManager_init(_admin);

//         __initializeStorage(
//             _symbioticCollateral, _symbioticVault, _withdrawalQueue, _limit, _paused
//         );
//     }

//     function _msgSender() internal view override(Context, ContextUpgradeable) returns (address) {
//         return Context._msgSender();
//     }

//     function _msgData()
//         internal
//         view
//         override(Context, ContextUpgradeable)
//         returns (bytes calldata)
//     {
//         return Context._msgData();
//     }

//     function _contextSuffixLength()
//         internal
//         view
//         override(Context, ContextUpgradeable)
//         returns (uint256)
//     {
//         return Context._contextSuffixLength();
//     }

//     function _update(address from, address to, uint256 value)
//         internal
//         virtual
//         override(Vault, ERC20)
//     {
//         uint256 pendingShares = convertToShares(withdrawalQueue().balanceOf(from));
//         if (balanceOf(from) < pendingShares) {
//             revert("Vault: insufficient balance");
//         }
//         ERC20._update(from, to, value);
//     }

//     function balanceOf(address account)
//         public
//         view
//         override(IERC20, ERC20, ERC20Upgradeable)
//         returns (uint256)
//     {
//         return ERC20.balanceOf(account);
//     }

//     function totalSupply()
//         public
//         view
//         override(IERC20, ERC20, ERC20Upgradeable)
//         returns (uint256)
//     {
//         return ERC20.totalSupply();
//     }

//     function transferFrom(address from, address to, uint256 amount)
//         public
//         override(IERC20, ERC20, ERC20Upgradeable)
//         returns (bool)
//     {
//         return ERC20.transferFrom(from, to, amount);
//     }

//     function transfer(address to, uint256 amount)
//         public
//         override(IERC20, ERC20, ERC20Upgradeable)
//         returns (bool)
//     {
//         return ERC20.transfer(to, amount);
//     }

//     function approve(address spender, uint256 amount)
//         public
//         override(IERC20, ERC20, ERC20Upgradeable)
//         returns (bool)
//     {
//         return ERC20.approve(spender, amount);
//     }

//     function allowance(address owner, address spender)
//         public
//         view
//         override(IERC20, ERC20, ERC20Upgradeable)
//         returns (uint256)
//     {
//         return ERC20.allowance(owner, spender);
//     }

//     function symbol()
//         public
//         view
//         override(IERC20Metadata, ERC20, ERC20Upgradeable)
//         returns (string memory)
//     {
//         return ERC20.symbol();
//     }

//     function name()
//         public
//         view
//         override(IERC20Metadata, ERC20, ERC20Upgradeable)
//         returns (string memory)
//     {
//         return ERC20.name();
//     }

//     function decimals() public view override(ERC20, ERC4626Upgradeable) returns (uint8) {
//         return ERC20.decimals();
//     }

//     function _spendAllowance(address owner, address spender, uint256 amount)
//         internal
//         override(ERC20, ERC20Upgradeable)
//     {
//         ERC20._spendAllowance(owner, spender, amount);
//     }

//     function _approve(address owner, address spender, uint256 amount, bool emitEvent)
//         internal
//         override(ERC20, ERC20Upgradeable)
//     {
//         ERC20._approve(owner, spender, amount, emitEvent);
//     }
// }
