// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import "./interfaces/vaults/IVault.sol";
import {VaultStorage} from "./VaultStorage.sol";

// TODO:
// 1. Off by 1 errors (add test for MulDiv rounding e.t.c)
// 2. Tests (unit, int, e2e, migration)
// 3. Add is Multicall
// 4. Add is ReentrancyGuard
// 5. Add is ERC4626
abstract contract Vault is
    IVault,
    VaultStorage,
    AccessControlEnumerableUpgradeable
{
    using SafeERC20 for IERC20;

    bytes32 constant SET_LIMIT_ROLE = keccak256("SET_LIMIT_ROLE");
    bytes32 constant PAUSE_TRANSFERS_ROLE = keccak256("PAUSE_TRANSFERS_ROLE");
    bytes32 constant UNPAUSE_TRANSFERS_ROLE =
        keccak256("UNPAUSE_TRANSFERS_ROLE");
    bytes32 constant PAUSE_DEPOSITS_ROLE = keccak256("PAUSE_DEPOSITS_ROLE");
    bytes32 constant UNPAUSE_DEPOSITS_ROLE = keccak256("UNPAUSE_DEPOSITS_ROLE");

    function __initializeRoles(address admin) internal initializer {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);

        _grantRole(SET_LIMIT_ROLE, admin);
        _setRoleAdmin(SET_LIMIT_ROLE, DEFAULT_ADMIN_ROLE);

        _grantRole(PAUSE_TRANSFERS_ROLE, admin);
        _setRoleAdmin(PAUSE_TRANSFERS_ROLE, DEFAULT_ADMIN_ROLE);

        _grantRole(UNPAUSE_TRANSFERS_ROLE, admin);
        _setRoleAdmin(UNPAUSE_TRANSFERS_ROLE, DEFAULT_ADMIN_ROLE);

        _grantRole(PAUSE_DEPOSITS_ROLE, admin);
        _setRoleAdmin(PAUSE_DEPOSITS_ROLE, DEFAULT_ADMIN_ROLE);

        _grantRole(UNPAUSE_DEPOSITS_ROLE, admin);
        _setRoleAdmin(UNPAUSE_DEPOSITS_ROLE, DEFAULT_ADMIN_ROLE);
    }

    function setLimit(uint256 _limit) external onlyRole(SET_LIMIT_ROLE) {
        if (totalSupply() > _limit) {
            revert("Vault: totalSupply exceeds new limit");
        }
        _setLimit(_limit);
        emit NewLimit(_limit);
    }

    function pauseTransfers() external onlyRole(PAUSE_TRANSFERS_ROLE) {
        _setTransferPause(true);
        _revokeRole(PAUSE_TRANSFERS_ROLE, _msgSender());
    }

    function unpauseTransfers() external onlyRole(UNPAUSE_TRANSFERS_ROLE) {
        _setTransferPause(false);
    }

    function pauseDeposits() external onlyRole(PAUSE_DEPOSITS_ROLE) {
        _setDepositPause(true);
        _revokeRole(PAUSE_DEPOSITS_ROLE, _msgSender());
    }

    function unpauseDeposits() external onlyRole(UNPAUSE_DEPOSITS_ROLE) {
        _setDepositPause(false);
    }

    function pushRewards(
        IERC20 rewardToken,
        bytes calldata symbioticRewardsData
    ) external {
        FarmData memory data = symbioticFarm(address(rewardToken));
        require(data.symbioticFarm != address(0), "Vault: farm not set");
        uint256 amountBefore = rewardToken.balanceOf(address(this));
        IStakerRewards(data.symbioticFarm).claimRewards(
            address(this),
            address(rewardToken),
            symbioticRewardsData
        );
        uint256 rewardAmount = rewardToken.balanceOf(address(this)) -
            amountBefore;
        if (rewardAmount == 0) return;

        uint256 curatorFee = Math.mulDiv(rewardAmount, data.curatorFeeD4, 1e4);
        if (curatorFee != 0) {
            rewardToken.safeTransfer(data.curatorTreasury, curatorFee);
        }
        if (rewardAmount != curatorFee) {
            rewardToken.safeTransfer(
                data.distributionFarm,
                rewardAmount - curatorFee
            );
        }
        emit RewardsPushed(address(rewardToken), rewardAmount, block.timestamp);
    }

    function getSymbioticVaultStake(
        Math.Rounding rounding
    ) public view returns (uint256 vaultActiveStake) {
        ISymbioticVault symbioticVault = symbioticVault();
        uint256 vaultActiveShares = symbioticVault.activeSharesOf(
            address(this)
        );
        uint256 activeStake = symbioticVault.activeStake();
        uint256 activeShares = symbioticVault.activeShares();
        vaultActiveStake = Math.mulDiv(
            activeStake,
            vaultActiveShares,
            activeShares,
            rounding
        );
    }

    function tvl(
        Math.Rounding rounding
    ) public view returns (uint256 totalValueLocked) {
        return
            IERC20(token()).balanceOf(address(this)) +
            symbioticCollateral().balanceOf(address(this)) +
            getSymbioticVaultStake(rounding);
    }

    function deposit(
        address depositToken,
        uint256 amount,
        uint256 minLpAmount,
        address recipient,
        address referral
    ) external payable {
        if (depositPause()) revert("Vault: paused");
        uint256 totalSupply_ = totalSupply();
        uint256 valueBefore = tvl(Math.Rounding.Ceil);
        _deposit(depositToken, amount);
        if (depositToken != token()) revert("Vault: invalid deposit token");
        uint256 valueAfter = tvl(Math.Rounding.Floor);
        if (valueAfter <= valueBefore) {
            revert("Vault: invalid deposit amount");
        }
        uint256 depositValue = valueAfter - valueBefore;
        uint256 lpAmount;
        if (totalSupply_ == 0) {
            // initial deposit only on behalf of admin
            _checkRole(DEFAULT_ADMIN_ROLE);
            if (
                minLpAmount == 0 ||
                depositValue == 0 ||
                recipient != address(this)
            ) {
                revert("Vault: invalid initial deposit values");
            }
            lpAmount = minLpAmount;
        } else {
            lpAmount = Math.mulDiv(totalSupply_, depositValue, valueBefore);
            if (minLpAmount > lpAmount) revert("Vault: minLpAmount > lpAmount");
        }
        if (lpAmount + totalSupply_ > limit()) {
            revert("Vault: vault limit reached");
        } else if (lpAmount == 0) {
            revert("Vault: zero lpAmount");
        }
        pushIntoSymbiotic();

        _update(address(0), recipient, lpAmount);
        emit Deposit(recipient, depositValue, lpAmount, referral);
    }

    function withdraw(
        uint256 lpAmount,
        address recipient
    ) external returns (uint256 withdrawnAmount, uint256 amountToClaim) {
        lpAmount = Math.min(lpAmount, balanceOf(_msgSender()));
        if (lpAmount == 0) return (0, 0);

        address token = token();
        IDefaultCollateral symbioticCollateral = symbioticCollateral();
        uint256 tokenValue = IERC20(token).balanceOf(address(this));
        uint256 collateralValue = symbioticCollateral.balanceOf(address(this));
        uint256 symbioticVaultStake = getSymbioticVaultStake(
            Math.Rounding.Floor
        );

        uint256 totalValue = tokenValue + collateralValue + symbioticVaultStake;
        amountToClaim = Math.mulDiv(lpAmount, totalValue, totalSupply());
        if (tokenValue != 0) {
            uint256 tokenAmount = Math.min(amountToClaim, tokenValue);
            IERC20(token).safeTransfer(recipient, tokenAmount);
            amountToClaim -= tokenAmount;
            withdrawnAmount += tokenAmount;
            if (amountToClaim == 0) return (withdrawnAmount, 0);
        }

        if (collateralValue != 0) {
            uint256 collateralAmount = Math.min(amountToClaim, collateralValue);
            symbioticCollateral.withdraw(recipient, collateralAmount);
            amountToClaim -= collateralAmount;
            withdrawnAmount += collateralAmount;
            if (amountToClaim == 0) return (withdrawnAmount, 0);
        }

        ISymbioticVault symbioticVault = symbioticVault();

        uint256 sharesAmount = Math.mulDiv(
            amountToClaim,
            symbioticVault.activeShares(),
            symbioticVault.activeStake(),
            Math.Rounding.Floor
        );

        symbioticVault.withdraw(recipient, sharesAmount);
    }

    function pushIntoSymbiotic() public {
        IERC20 token = IERC20(token());
        uint256 assetAmount = token.balanceOf(address(this));
        IDefaultCollateral symbioticCollateral = symbioticCollateral();
        ISymbioticVault symbioticVault = symbioticVault();
        uint256 leftover = symbioticCollateral.limit() -
            symbioticCollateral.totalSupply();
        assetAmount = Math.min(assetAmount, leftover);
        if (assetAmount == 0) {
            return;
        }
        token.safeIncreaseAllowance(address(symbioticCollateral), assetAmount);
        uint256 amount = symbioticCollateral.deposit(
            address(this),
            assetAmount
        );
        if (amount != assetAmount) {
            token.forceApprove(address(symbioticCollateral), 0);
        }

        uint256 bondAmount = symbioticCollateral.balanceOf(address(this));
        IERC20(symbioticCollateral).safeIncreaseAllowance(
            address(symbioticVault),
            bondAmount
        );
        (uint256 stakedAmount, ) = symbioticVault.deposit(
            address(this),
            bondAmount
        );
        if (bondAmount != stakedAmount) {
            IERC20(symbioticCollateral).forceApprove(
                address(symbioticVault),
                0
            );
        }
    }

    function _setFarmChecks(
        address rewardToken,
        FarmData memory farmData
    ) internal virtual {
        if (
            rewardToken == address(this) ||
            rewardToken == address(symbioticCollateral()) ||
            rewardToken == address(symbioticVault())
        ) {
            revert("Vault: forbidden reward token");
        }
        if (farmData.curatorFeeD4 > 1e4) {
            revert("Vault: invalid curator fee");
        }
    }

    function totalSupply() public view virtual returns (uint256);

    function balanceOf(address account) public view virtual returns (uint256);

    function _update(
        address,
        /* from */ address,
        /* to */ uint256 /* amount */
    ) internal virtual {
        if (transferPause()) {
            revert("Vault: paused");
        }
    }

    function _deposit(address depositToken, uint256 amount) internal virtual;
}
