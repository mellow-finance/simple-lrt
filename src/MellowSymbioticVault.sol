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

    uint256 private constant D6 = 1e6;
    bytes32 private constant SET_FARM_ROLE = keccak256("SET_FARM_ROLE");
    bytes32 private constant REMOVE_FARM_ROLE = keccak256("REMOVE_FARM_ROLE");

    constructor(bytes32 contractName_, uint256 contractVersion_)
        MellowSymbioticVaultStorage(contractName_, contractVersion_)
        VaultControlStorage(contractName_, contractVersion_)
    {}

    /// @inheritdoc IMellowSymbioticVault
    function initialize(InitParams memory initParams) public virtual initializer {
        __initialize(initParams);
    }

    function __initialize(InitParams memory initParams) internal virtual onlyInitializing {
        address collateral = ISymbioticVault(initParams.symbioticVault).collateral();
        __initializeMellowSymbioticVaultStorage(
            initParams.symbioticVault, initParams.withdrawalQueue
        );
        __initializeERC4626(
            initParams.admin,
            initParams.limit,
            initParams.depositPause,
            initParams.withdrawalPause,
            initParams.depositWhitelist,
            collateral,
            initParams.name,
            initParams.symbol
        );
    }

    /// @inheritdoc IMellowSymbioticVault
    function setFarm(uint256 farmId, FarmData memory farmData) external onlyRole(SET_FARM_ROLE) {
        _setFarmChecks(farmId, farmData);
        _setFarm(farmId, farmData);
    }

    function _setFarmChecks(uint256, /* id */ FarmData memory farmData) internal virtual {
        require(
            farmData.rewardToken != address(this)
                && farmData.rewardToken != address(symbioticVault()),
            "Vault: forbidden reward token"
        );
        require(farmData.curatorFeeD6 <= D6, "Vault: invalid curator fee");
    }

    /// @inheritdoc IERC4626
    function totalAssets()
        public
        view
        virtual
        override(ERC4626Upgradeable, IERC4626)
        returns (uint256)
    {
        return IERC20(asset()).balanceOf(address(this))
            + symbioticVault().activeBalanceOf(address(this));
    }

    /// @inheritdoc ERC4626Upgradeable
    function _deposit(address caller, address receiver, uint256 assets, uint256 shares)
        internal
        virtual
        override
    {
        super._deposit(caller, receiver, assets, shares);
        pushIntoSymbiotic();
    }

    /// @inheritdoc ERC4626Upgradeable
    function _withdraw(
        address caller,
        address receiver,
        address owner,
        uint256 assets,
        uint256 shares
    ) internal virtual override {
        address this_ = address(this);

        uint256 liquid = IERC20(asset()).balanceOf(this_);
        if (liquid >= assets) {
            return super._withdraw(caller, receiver, owner, assets, shares);
        }

        uint256 staked = assets - liquid;
        (, uint256 requestedShares) = symbioticVault().withdraw(address(withdrawalQueue()), staked);
        withdrawalQueue().request(receiver, requestedShares);

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

    /// @inheritdoc IMellowSymbioticVault
    function claimableAssetsOf(address account) external view returns (uint256 claimableAssets) {
        claimableAssets = withdrawalQueue().claimableAssetsOf(account);
    }

    /// @inheritdoc IMellowSymbioticVault
    function pendingAssetsOf(address account) external view returns (uint256 pendingAssets) {
        pendingAssets = withdrawalQueue().pendingAssetsOf(account);
    }

    /// @inheritdoc IMellowSymbioticVault
    function claim(address account, address recipient, uint256 maxAmount)
        external
        virtual
        nonReentrant
        returns (uint256)
    {
        require(account == _msgSender(), "Vault: forbidden");
        return withdrawalQueue().claim(account, recipient, maxAmount);
    }

    /// @inheritdoc IMellowSymbioticVault
    function pushIntoSymbiotic() public virtual returns (uint256 symbioticVaultStaked) {
        IERC20 asset_ = IERC20(asset());
        address this_ = address(this);
        uint256 assetAmount = asset_.balanceOf(this_);
        ISymbioticVault symbioticVault = symbioticVault();

        if (assetAmount == 0) {
            return 0;
        }

        if (symbioticVault.depositWhitelist() && !symbioticVault.isDepositorWhitelisted(this_)) {
            return 0;
        }

        if (symbioticVault.isDepositLimit()) {
            uint256 symbioticVaultTotalStake = symbioticVault.totalStake();
            uint256 symbioticVaultLimit = symbioticVault.depositLimit();
            if (symbioticVaultTotalStake >= symbioticVaultLimit) {
                return 0;
            }
            assetAmount = assetAmount.min(symbioticVaultLimit - symbioticVaultTotalStake);
        }

        asset_.safeIncreaseAllowance(address(symbioticVault), assetAmount);
        (symbioticVaultStaked,) = symbioticVault.deposit(this_, assetAmount);
        if (assetAmount != symbioticVaultStaked) {
            asset_.forceApprove(address(symbioticVault), 0);
        }

        emit SymbioticPushed(msg.sender, symbioticVaultStaked);
    }

    /// @inheritdoc IMellowSymbioticVault
    function pushRewards(uint256 farmId, bytes calldata symbioticRewardsData)
        external
        nonReentrant
    {
        FarmData memory data = symbioticFarm(farmId);
        require(data.rewardToken != address(0), "Vault: farm not set");
        IERC20 rewardToken = IERC20(data.rewardToken);
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
        emit RewardsPushed(farmId, rewardAmount, curatorFee, block.timestamp);
    }

    /// @inheritdoc IMellowSymbioticVault
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
        uint256 instantAssets = IERC20(asset()).balanceOf(address(this));
        accountShares = balanceOf(account);
        accountAssets = convertToAssets(accountShares);
        accountInstantAssets = accountAssets.min(instantAssets);
        accountInstantShares = convertToShares(accountInstantAssets);
    }
}
