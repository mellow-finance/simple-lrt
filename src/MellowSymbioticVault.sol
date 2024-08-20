// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import {ERC4626Vault} from "./ERC4626Vault.sol";
import {MellowSymbioticVaultStorage} from "./MellowSymbioticVaultStorage.sol";
import {VaultControl, VaultControlStorage} from "./VaultControl.sol";
import "./interfaces/vaults/IMellowSymbioticVault.sol";

contract MellowSymbioticVault is
    IMellowSymbioticVault,
    MellowSymbioticVaultStorage,
    ERC4626Vault
{
    using SafeERC20 for IERC20;
    using Math for uint256;

    // constants

    uint256 private constant D6 = 1e6;
    bytes32 private constant SET_FARM_ROLE = keccak256("SET_FARM_ROLE");
    bytes32 private constant REMOVE_FARM_ROLE = keccak256("REMOVE_FARM_ROLE");

    // initializer

    constructor(bytes32 contractName_, uint256 contractVersion_)
        MellowSymbioticVaultStorage(contractName_, contractVersion_)
        VaultControlStorage(contractName_, contractVersion_)
    {}

    function initialize(InitParams memory initParams) public virtual initializer {
        __initialize(initParams);
    }

    function __initialize(InitParams memory initParams) internal virtual onlyInitializing {
        address collateral = ISymbioticVault(initParams.symbioticVault).collateral();
        __initializeMellowSymbioticVaultStorage(
            initParams.symbioticVault, collateral, initParams.withdrawalQueue
        );
        __initializeERC4626(
            initParams.admin,
            initParams.limit,
            initParams.depositPause,
            initParams.withdrawalPause,
            initParams.depositWhitelist,
            IDefaultCollateral(collateral).asset(),
            initParams.name,
            initParams.symbol
        );
    }

    // setters getters

    function setFarm(address rewardToken, FarmData memory farmData)
        external
        onlyRole(SET_FARM_ROLE)
    {
        _setFarmChecks(rewardToken, farmData);
        _setFarm(rewardToken, farmData);
    }

    function _setFarmChecks(address rewardToken, FarmData memory farmData) internal virtual {
        require(
            rewardToken != address(this) && rewardToken != address(symbioticCollateral())
                && rewardToken != address(symbioticVault()),
            "Vault: forbidden reward token"
        );
        require(farmData.curatorFeeD6 <= D6, "Vault: invalid curator fee");
    }

    // ERC4626 overrides
    function totalAssets()
        public
        view
        virtual
        override(ERC4626Upgradeable, IERC4626)
        returns (uint256)
    {
        return IERC20(asset()).balanceOf(address(this))
            + symbioticCollateral().balanceOf(address(this))
            + symbioticVault().activeBalanceOf(address(this));
    }

    function _deposit(address caller, address receiver, uint256 assets, uint256 shares)
        internal
        virtual
        override
    {
        super._deposit(caller, receiver, assets, shares);
        pushIntoSymbiotic();
    }

    function _withdraw(
        address caller,
        address receiver,
        address owner,
        uint256 assets,
        uint256 shares
    ) internal virtual override {
        require(!withdrawalPause(), "Vault: withdrawal paused");
        address this_ = address(this);

        // 1. Check if we have enough assets to withdraw immediately
        uint256 liquid = IERC20(asset()).balanceOf(this_);
        if (liquid >= assets) {
            return super._withdraw(caller, receiver, owner, assets, shares);
        }

        // 2. If not - try to recover collateral (if any on the balance)
        uint256 collaterals_ = symbioticCollateral().balanceOf(this_);
        if (collaterals_ != 0) {
            symbioticCollateral().withdraw(this_, collaterals_.min(assets - liquid));
        }

        // 3. Second try - check if we have enough assets to withdraw immediately
        liquid = IERC20(asset()).balanceOf(this_);
        if (liquid >= assets) {
            return super._withdraw(caller, receiver, owner, assets, shares);
        }

        uint256 staked = assets - liquid;
        symbioticVault().withdraw(address(withdrawalQueue()), staked);
        withdrawalQueue().request(owner, staked);

        if (caller != owner) {
            _spendAllowance(owner, caller, shares);
        }

        _burn(owner, shares);
        if (liquid != 0) {
            IERC20(asset()).safeTransfer(receiver, liquid);
        }

        // emitting event with transfered + new pending assets
        emit Withdraw(caller, receiver, owner, assets, shares);
    }

    function _update(address from, address to, uint256 value) internal virtual override {
        super._update(from, to, value);
    }

    // withdrawalQueue proxy functions

    function claimableAssetsOf(address account) external view returns (uint256 claimableAssets) {
        claimableAssets = withdrawalQueue().claimableAssetsOf(account);
    }

    function pendingAssetsOf(address account) external view returns (uint256 pendingAssets) {
        pendingAssets = withdrawalQueue().pendingAssetsOf(account);
    }

    function claim(address account, address recipient, uint256 maxAmount)
        external
        virtual
        nonReentrant
        returns (uint256)
    {
        require(account == _msgSender(), "Vault: forbidden");
        return withdrawalQueue().claim(account, recipient, maxAmount);
    }

    // symbiotic functions

    function pushIntoSymbiotic()
        public
        virtual
        returns (uint256 symbioticCollateralStaked, uint256 symbioticVaultStaked)
    {
        IERC20 asset_ = IERC20(asset());
        address this_ = address(this);
        uint256 assetAmount = asset_.balanceOf(this_);
        IDefaultCollateral symbioticCollateral = symbioticCollateral();
        ISymbioticVault symbioticVault = symbioticVault();

        // 1. Push asset into symbiotic collateral
        uint256 leftover = symbioticCollateral.limit() - symbioticCollateral.totalSupply();
        leftover = assetAmount.min(leftover);
        if (leftover != 0) {
            asset_.safeIncreaseAllowance(address(symbioticCollateral), leftover);
            symbioticVaultStaked = symbioticCollateral.deposit(this_, leftover);
            if (leftover != symbioticVaultStaked) {
                asset_.forceApprove(address(symbioticCollateral), 0);
            }
        }

        // 2. Push collateral into symbiotic vault
        uint256 collateralAmount = symbioticCollateral.balanceOf(this_);
        if (collateralAmount != 0) {
            IERC20(symbioticCollateral).safeIncreaseAllowance(
                address(symbioticVault), collateralAmount
            );
            (symbioticVaultStaked,) = symbioticVault.deposit(this_, collateralAmount);
            if (collateralAmount != symbioticVaultStaked) {
                IERC20(symbioticCollateral).forceApprove(address(symbioticVault), 0);
            }
        }

        emit SymbioticPushed(msg.sender, symbioticCollateralStaked, symbioticVaultStaked);
    }

    function pushRewards(IERC20 rewardToken, bytes calldata symbioticRewardsData)
        external
        nonReentrant
    {
        FarmData memory data = symbioticFarm(address(rewardToken));
        require(data.symbioticFarm != address(0), "Vault: farm not set");
        uint256 amountBefore = rewardToken.balanceOf(address(this));
        IStakerRewards(data.symbioticFarm).claimRewards(
            address(this), address(rewardToken), symbioticRewardsData
        );
        uint256 rewardAmount = rewardToken.balanceOf(address(this)) - amountBefore;
        if (rewardAmount == 0) {
            return;
        }

        uint256 curatorFee = rewardAmount.mulDiv(data.curatorFeeD6, D6);
        if (curatorFee != 0) {
            rewardToken.safeTransfer(data.curatorTreasury, curatorFee);
        }
        // Guranteed to be >= 0 since data.curatorFeeD6 <= D6
        rewardAmount = rewardAmount - curatorFee;
        if (rewardAmount != 0) {
            rewardToken.safeTransfer(data.distributionFarm, rewardAmount);
        }
        emit RewardsPushed(address(rewardToken), rewardAmount, curatorFee, block.timestamp);
    }

    // helper functions

    function getBalances(address account)
        public
        view
        returns (
            uint256 accountAssets,
            uint256 accountInstantAssets,
            uint256 accountShares,
            uint256 accountInstantShares
        )
    {
        uint256 intantAssets = IERC20(asset()).balanceOf(address(this))
            + symbioticCollateral().balanceOf(address(this));
        accountShares = balanceOf(account);
        accountAssets = convertToAssets(accountShares);
        accountInstantAssets = accountAssets.min(intantAssets);
        accountInstantShares = convertToShares(accountInstantAssets);
    }
}
