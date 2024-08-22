// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import {ERC4626Vault} from "./ERC4626Vault.sol";
import {VaultControl, VaultControlStorage} from "./VaultControl.sol";
import "./interfaces/vaults/IMellowEigenLayerVault.sol";
import "./ERC1271.sol";

contract MellowEigenLayerVault is
    IMellowEigenLayerVault,
    ERC4626Vault,
    ERC1271
{
    using SafeERC20 for IERC20;
    using Math for uint256;

    address public strategy;
    address public delegationManager;
    address public strategyManager;

    constructor(bytes32 contractName_, uint256 contractVersion_)
        VaultControlStorage(contractName_, contractVersion_)
    {}

    function initialize(InitParams memory initParams) public virtual initializer {
        __initialize(initParams);
    }

    function __initialize(InitParams memory initParams) internal virtual onlyInitializing {
        DelegationParam memory delegationParam = initParams.delegationParam;
        delegationManager = delegationParam.delegationManager;
        strategyManager = delegationParam.strategyManager;
        strategy = delegationParam.strategy;
        uint256 expiry = block.timestamp + delegationParam.expiry;

        address delegationApprover = IDelegationManager(delegationManager).delegationApprover(delegationParam.operator);
        IDelegationManager(delegationParam.delegationManager).calculateDelegationApprovalDigestHash(address(this), delegationParam.operator, delegationApprover, delegationParam.salt, expiry);
        ISignatureUtils.SignatureWithExpiry memory signatureWithExpiry = ISignatureUtils.SignatureWithExpiry(delegationParam.delegationSignature, expiry);
        
        IDelegationManager(delegationManager).delegateTo(delegationParam.operator, signatureWithExpiry, delegationParam.salt);
        
        address underlyingToken = address(IStrategy(strategy).underlyingToken());

        __initializeERC4626(
            initParams.admin,
            initParams.limit,
            initParams.depositPause,
            initParams.withdrawalPause,
            initParams.depositWhitelist,
            underlyingToken,
            initParams.name,
            initParams.symbol
        );
    }

    // ERC4626 overrides
    function totalAssets()
        public
        view
        virtual
        override(ERC4626Upgradeable, IERC4626)
        returns (uint256)
    {
        return IERC20(asset()).balanceOf(address(this)); // TODO check
    }

    function _deposit(address caller, address receiver, uint256 assets, uint256 shares)
        internal
        virtual
        override
    {
        super._deposit(caller, receiver, assets, shares);
        uint256 actualShares = IStrategy(strategy).deposit(IERC20(asset()), assets);
        require(actualShares >= shares, "Vault: insufficient shares");
    }

    /**
     * @dev Internal conversion function (from assets to shares) with support for rounding direction.
     */
    function _convertToShares(uint256 assets, Math.Rounding rounding) internal view override returns (uint256 shares) {

        shares = IStrategy(strategy).underlyingToSharesView(assets);

        if (shares > 0 && rounding == Math.Rounding.Floor) {
            shares -= 1;
        } else if (rounding == Math.Rounding.Ceil) {
            shares += 1;
        }
    }

    /**
     * @dev Internal conversion function (from shares to assets) with support for rounding direction.
     */
    function _convertToAssets(uint256 shares, Math.Rounding rounding) internal view override returns (uint256 assets) {

        assets = IStrategy(strategy).sharesToUnderlyingView(shares);

        if (assets > 0 && rounding == Math.Rounding.Floor) {
            assets -= 1;
        } else if (rounding == Math.Rounding.Ceil) {
            assets += 1;
        }
    }

    /// @notice Internal function used to fetch this contract's current balance of `underlyingToken`.
    // slither-disable-next-line dead-code
    function _tokenBalance() internal view virtual returns (uint256) {
        return IERC20(asset()).balanceOf(strategy);
    }
}