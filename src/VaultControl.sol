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
    // roles

    bytes32 private constant SET_LIMIT_ROLE = keccak256("SET_LIMIT_ROLE");
    bytes32 private constant PAUSE_WITHDRAWALS_ROLE = keccak256("PAUSE_WITHDRAWALS_ROLE");
    bytes32 private constant UNPAUSE_WITHDRAWALS_ROLE = keccak256("UNPAUSE_WITHDRAWALS_ROLE");
    bytes32 private constant PAUSE_DEPOSITS_ROLE = keccak256("PAUSE_DEPOSITS_ROLE");
    bytes32 private constant UNPAUSE_DEPOSITS_ROLE = keccak256("UNPAUSE_DEPOSITS_ROLE");
    bytes32 private constant SET_DEPOSIT_WHITELIST_ROLE = keccak256("SET_DEPOSIT_WHITELIST_ROLE");
    bytes32 private constant SET_DEPOSITOR_WHITELIST_STATUS_ROLE =
        keccak256("SET_DEPOSITOR_WHITELIST_STATUS_ROLE");

    function __initializeVaultControl(address _admin, address _asset) internal {
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        __ERC4626_init(IERC20(_asset));
        __ReentrancyGuard_init();
        __AccessControlEnumerable_init();
    }

    // setters getters

    function setLimit(uint256 _limit) external onlyRole(SET_LIMIT_ROLE) {
        require(totalSupply() <= _limit, "Vault: totalSupply exceeds new limit");
        _setLimit(_limit);
    }

    function pauseWithdrawals() external onlyRole(PAUSE_WITHDRAWALS_ROLE) {
        _setWithdrawalPause(true);
        _revokeRole(PAUSE_WITHDRAWALS_ROLE, _msgSender());
    }

    function unpauseWithdrawals() external onlyRole(UNPAUSE_WITHDRAWALS_ROLE) {
        _setWithdrawalPause(false);
    }

    function pauseDeposits() external onlyRole(PAUSE_DEPOSITS_ROLE) {
        _setDepositPause(true);
        _revokeRole(PAUSE_DEPOSITS_ROLE, _msgSender());
    }

    function unpauseDeposits() external onlyRole(UNPAUSE_DEPOSITS_ROLE) {
        _setDepositPause(false);
    }

    function setDepositWhitelist(bool status) external onlyRole(SET_DEPOSIT_WHITELIST_ROLE) {
        _setDepositWhitelist(status);
    }

    function setDepositorWhitelistStatus(address account, bool status)
        external
        onlyRole(SET_DEPOSITOR_WHITELIST_STATUS_ROLE)
    {
        _setDepositorWhitelistStatus(account, status);
    }

    // ERC4626 overrides

    function maxMint(address account) public view virtual override returns (uint256) {
        if (depositWhitelist() && !isDepositorWhitelisted(account)) {
            return 0;
        }
        uint256 limit_ = limit();
        if (limit_ == type(uint256).max) {
            return type(uint256).max;
        }
        uint256 totalSupply_ = totalSupply();
        return limit_ >= totalSupply_ ? limit_ - totalSupply_ : 0;
    }

    function maxDeposit(address account) public view virtual override returns (uint256) {
        uint256 shares = maxMint(account);
        if (shares == type(uint256).max) {
            return type(uint256).max;
        }
        return convertToAssets(shares);
    }

    function deposit(uint256 assets, address receiver, address referral)
        public
        virtual
        returns (uint256 shares)
    {
        shares = deposit(assets, receiver);
        emit ReferralDeposit(assets, receiver, referral);
    }

    function deposit(uint256 assets, address receiver)
        public
        virtual
        override
        nonReentrant
        returns (uint256)
    {
        require(!depositPause(), "Vault: deposits paused");
        return super.deposit(assets, receiver);
    }

    function mint(uint256 shares, address receiver)
        public
        virtual
        override
        nonReentrant
        returns (uint256)
    {
        require(!depositPause(), "Vault: deposits paused");
        return super.mint(shares, receiver);
    }

    function withdraw(uint256 shares, address receiver, address owner)
        public
        virtual
        override
        nonReentrant
        returns (uint256)
    {
        require(!withdrawalPause(), "Vault: withdrawals paused");
        return super.withdraw(shares, receiver, owner);
    }

    function redeem(uint256 shares, address receiver, address owner)
        public
        virtual
        override
        nonReentrant
        returns (uint256)
    {
        require(!withdrawalPause(), "Vault: withdrawals paused");
        return super.redeem(shares, receiver, owner);
    }
}
