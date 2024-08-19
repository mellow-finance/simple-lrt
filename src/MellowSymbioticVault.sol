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

    constructor(bytes32 contractName_, uint256 contractVersion_)
        MellowSymbioticVaultStorage(contractName_, contractVersion_)
        VaultControlStorage(contractName_, contractVersion_)
    {}

    // initializer

    function initialize(InitParams memory initParams) public virtual initializer {
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

    // roles

    bytes32 private constant SET_FARM_ROLE = keccak256("SET_FARM_ROLE");
    bytes32 private constant REMOVE_FARM_ROLE = keccak256("REMOVE_FARM_ROLE");

    // setters getters

    function setFarm(address rewardToken, FarmData memory farmData)
        external
        onlyRole(SET_FARM_ROLE)
    {
        _setFarmChecks(rewardToken, farmData);
        _setFarm(rewardToken, farmData);
    }

    function _setFarmChecks(address rewardToken, FarmData memory farmData) internal virtual {
        // TODO: require != ?
        require(
            rewardToken == address(this) || rewardToken == address(symbioticCollateral())
                || rewardToken == address(symbioticVault()),
            "Vault: forbidden reward token"
        );
        // TODO: Let's make 1e4 a contant and I'd make it D6.
        require(farmData.curatorFeeD4 <= 1e4, "Vault: invalid curator fee");
    }

    // ERC4626 overrides

    // TODO: deposit with referral address

    function totalAssets() public view virtual override returns (uint256) {
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
        // TODO: this should not be the requirement (in case of approved ERC20 tokens)?
        require(owner == caller, "Vault: owner != caller");
        // Doing this again here (in addition to ERC4626Vault) because the logic at the
        // bottom doesn't use the super call.
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
            symbioticCollateral().withdraw(this_, collaterals_);
        }

        // 3. Second try - check if we have enough assets to withdraw immediately
        liquid = IERC20(asset()).balanceOf(this_);
        if (liquid >= assets) {
            return super._withdraw(caller, receiver, owner, assets, shares);
        }

        uint256 staked = assets - liquid;
        symbioticVault().withdraw(address(withdrawalQueue()), staked);
        withdrawalQueue().request(owner, staked);

        // See the TODO above and keep / remove accordingly
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
        // TODO: do we really need this check? If it's reverted that the token is locked?
        uint256 pendingShares = convertToShares(withdrawalQueue().balanceOf(from));
        require(balanceOf(from) >= pendingShares, "Vault: insufficient balance");
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

    function pushIntoSymbiotic() public virtual {
        IERC20 asset_ = IERC20(asset());
        uint256 assetAmount = asset_.balanceOf(address(this));
        IDefaultCollateral symbioticCollateral = symbioticCollateral();
        ISymbioticVault symbioticVault = symbioticVault();

        // 1. Push asset into symbiotic collateral
        uint256 leftover = symbioticCollateral.limit() - symbioticCollateral.totalSupply();
        assetAmount = assetAmount.min(leftover);
        if (assetAmount == 0) {
            return;
        }
        asset_.safeIncreaseAllowance(address(symbioticCollateral), assetAmount);
        uint256 amount = symbioticCollateral.deposit(address(this), assetAmount);
        if (amount != assetAmount) {
            asset_.forceApprove(address(symbioticCollateral), 0);
        }

        // 2. Push collateral into symbiotic vault
        uint256 collateralAmount = symbioticCollateral.balanceOf(address(this));
        IERC20(symbioticCollateral).safeIncreaseAllowance(address(symbioticVault), collateralAmount);
        (uint256 stakedAmount,) = symbioticVault.deposit(address(this), collateralAmount);
        if (collateralAmount != stakedAmount) {
            IERC20(symbioticCollateral).forceApprove(address(symbioticVault), 0);
        }

        // emit SymbioticPushed(...);
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

        // TODO: remove magic numbers
        uint256 curatorFee = rewardAmount.mulDiv(data.curatorFeeD4, 1e4);
        if (curatorFee != 0) {
            rewardToken.safeTransfer(data.curatorTreasury, curatorFee);
        }
        // Guranteed to be >= 0 since data.curatorFeeD4 <= 1e4
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
