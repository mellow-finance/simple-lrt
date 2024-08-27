// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import "./interfaces/vaults/IERC4626Vault.sol";

import {VaultControl} from "./VaultControl.sol";

/**
 * @dev Abstract contract implementation of the ERC4626 "Tokenized Vault Standard", as defined in
 * https://eips.ethereum.org/EIPS/eip-4626[ERC-4626].
 */
abstract contract ERC4626Vault is VaultControl, ERC4626Upgradeable, IERC4626Vault {
    function __initializeERC4626(
        address _admin,
        uint256 _limit,
        bool _depositPause,
        bool _withdrawalPause,
        bool _depositWhitelist,
        address _asset,
        string memory _name,
        string memory _symbol
    ) internal onlyInitializing {
        __initializeVaultControl(_admin, _limit, _depositPause, _withdrawalPause, _depositWhitelist);
        __ERC20_init(_name, _symbol);
        __ERC4626_init(IERC20(_asset));
    }

    /**
     * @notice Maximum amount of shares that can be minted from the Vault for the receiver, through a mint call.
     * @param account Receiver address.
     */
    function maxMint(address account)
        public
        view
        virtual
        override(ERC4626Upgradeable, IERC4626)
        returns (uint256)
    {
        if (depositPause()) {
            return 0;
        }
        uint256 assets = maxDeposit(account);
        if (assets == type(uint256).max) {
            return type(uint256).max;
        }
        return convertToShares(assets);
    }

    /**
     * @notice Maximum amount of the underlying asset that can be deposited into the Vault for the receiver, through a deposit call.
     * @param account Receiver address.
     */
    function maxDeposit(address account)
        public
        view
        virtual
        override(ERC4626Upgradeable, IERC4626)
        returns (uint256)
    {
        if (depositPause()) {
            return 0;
        }
        if (depositWhitelist() && !isDepositorWhitelisted(account)) {
            return 0;
        }
        uint256 limit_ = limit();
        if (limit_ == type(uint256).max) {
            return type(uint256).max;
        }
        uint256 assets_ = totalAssets();
        return limit_ >= assets_ ? limit_ - assets_ : 0;
    }

    /**
     * @notice Maximum amount of the underlying asset that can be withdrawn from the owner balance in the Vault, through a withdraw call.
     * @param account Receiver address
     */
    function maxWithdraw(address account)
        public
        view
        virtual
        override(ERC4626Upgradeable, IERC4626)
        returns (uint256)
    {
        if (withdrawalPause()) {
            return 0;
        }
        return super.maxWithdraw(account);
    }

    /**
     * @notice Maximum amount of Vault shares that can be redeemed from the owner balance in the Vault, through a redeem call.
     * @param account Owner address.
     */
    function maxRedeem(address account)
        public
        view
        virtual
        override(ERC4626Upgradeable, IERC4626)
        returns (uint256)
    {
        if (withdrawalPause()) {
            return 0;
        }
        return super.maxRedeem(account);
    }

    /// @inheritdoc IERC4626Vault
    function deposit(uint256 assets, address receiver, address referral)
        public
        virtual
        returns (uint256 shares)
    {
        shares = deposit(assets, receiver);
        emit ReferralDeposit(assets, receiver, referral);
    }
}
