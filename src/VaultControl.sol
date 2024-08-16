// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import {VaultControlStorage} from "./VaultControlStorage.sol";

import "./interfaces/vaults/IVaultControl.sol";

abstract contract VaultControl is
    IVaultControl,
    VaultControlStorage,
    ERC4626Upgradeable,
    ReentrancyGuardUpgradeable,
    AccessControlEnumerableUpgradeable
{
    using SafeERC20 for IERC20;
    using Math for uint256;

    // roles

    bytes32 public constant SET_LIMIT_ROLE = keccak256("SET_LIMIT_ROLE");

    bytes32 public constant PAUSE_WITHDRAWALS_ROLE = keccak256("PAUSE_WITHDRAWALS_ROLE");
    bytes32 public constant UNPAUSE_WITHDRAWALS_ROLE = keccak256("UNPAUSE_WITHDRAWALS_ROLE");

    bytes32 public constant PAUSE_DEPOSITS_ROLE = keccak256("PAUSE_DEPOSITS_ROLE");
    bytes32 public constant UNPAUSE_DEPOSITS_ROLE = keccak256("UNPAUSE_DEPOSITS_ROLE");

    bytes32 public constant SET_DEPOSIT_WHITELIST_ROLE = keccak256("SET_DEPOSIT_WHITELIST_ROLE");
    bytes32 public constant SET_DEPOSITOR_WHITELIST_STATUS_ROLE =
        keccak256("SET_DEPOSITOR_WHITELIST_STATUS_ROLE");

    modifier onlyAuthorized(bytes32 role) {
        _checkRole(role, _msgSender());
        _;
    }

    function __initializeRoles(address _admin) internal {
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
    }

    // setters getters

    function setLimit(uint256 _limit) external onlyAuthorized(SET_LIMIT_ROLE) {
        if (totalSupply() > _limit) {
            revert("Vault: totalSupply exceeds new limit");
        }
        _setLimit(_limit);
        emit NewLimit(_limit);
    }

    function pauseWithdrawals() external onlyAuthorized(PAUSE_WITHDRAWALS_ROLE) {
        _setWithdrawalPause(true);
        _revokeRole(PAUSE_WITHDRAWALS_ROLE, _msgSender());
    }

    function unpauseWithdrawals() external onlyAuthorized(UNPAUSE_WITHDRAWALS_ROLE) {
        _setWithdrawalPause(false);
    }

    function pauseDeposits() external onlyAuthorized(PAUSE_DEPOSITS_ROLE) {
        _setDepositPause(true);
        _revokeRole(PAUSE_DEPOSITS_ROLE, _msgSender());
    }

    function unpauseDeposits() external onlyAuthorized(UNPAUSE_DEPOSITS_ROLE) {
        _setDepositPause(false);
    }

    function setDepositWhitelist(bool status) external onlyAuthorized(SET_DEPOSIT_WHITELIST_ROLE) {
        _setDepositWhitelist(status);
    }

    function setDepositorWhitelistStatus(address account, bool status)
        external
        onlyAuthorized(SET_DEPOSITOR_WHITELIST_STATUS_ROLE)
    {
        _setDepositorWhitelistStatus(account, status);
    }

    // ERC4626 overrides

    function maxMint(address account) public view virtual override returns (uint256) {
        if (depositWhitelist() && !isDepositorWhitelisted(account)) {
            return 0;
        }
        uint256 limit_ = limit();
        uint256 totalSupply_ = totalSupply();
        return limit_ >= totalSupply_ ? limit_ - totalSupply_ : 0;
    }

    function deposit(uint256 assets, address receiver, address referral)
        public
        virtual
        returns (uint256 shares)
    {
        shares = deposit(assets, receiver);
        emit ReferralDeposit(assets, receiver, referral);
    }
}
