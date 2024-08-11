// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {ERC20Votes, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

import "./interfaces/IDefaultCollateral.sol";
import "./interfaces/ISymbioticVault.sol";
import "./interfaces/IStakerRewards.sol";

// TODO: Storage initializer
// TODO: Off by 1 errors
// TODO; Tests
contract BaseVault is ERC20Votes, Pausable, Ownable {
    using SafeERC20 for IERC20;

    bytes32 public constant STORAGE_SLOT = keccak256("mellow-finance.simple-lrt.rsc.BaseVault.storage");

    struct FarmData {
        address symbioticFarm;
        address distributionFarm;
        uint256 curatorFeeD4;
        address curatorTreasury;
    }

    struct Storage {
        IDefaultCollateral symbioticCollateral;
        ISymbioticVault symbioticVault;
        address token;
        uint256 limit;
        mapping(address rewardToken => FarmData data) farms;
    }

    function _contractStorage() internal pure returns (Storage storage state) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            state.slot := slot
        }
    }

    constructor(
        string memory _name,
        string memory _ticker,
        address _symbioticCollateral,
        address _symbioticVault,
        uint256 _limit,
        address _owner
    )
        // add initialRatio
        ERC20(_name, _ticker)
        EIP712(_name, "1")
        Ownable(_owner)
    {
        Storage storage s = _contractStorage();
        s.symbioticVault = ISymbioticVault(_symbioticVault);
        s.symbioticCollateral = IDefaultCollateral(_symbioticCollateral);
        s.limit = _limit;
        s.token = IDefaultCollateral(_symbioticCollateral).asset();
    }

    // Permissioned setters

    function setLimit(uint256 _limit) external onlyOwner {
        Storage storage s = _contractStorage();
        if (totalSupply() > _limit) {
            revert("BaseVault: totalSupply exceeds new limit");
        }
        s.limit = _limit;
        emit NewLimit(_limit);
    }

    function setFarmData(address rewardToken, FarmData memory farmData) external onlyOwner {
        Storage storage s = _contractStorage();
        _setFarmChecks(rewardToken, farmData);
        s.farms[rewardToken] = farmData;
        emit FarmSet(rewardToken, farmData);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    // 1. claims rewards from symbiotic farm
    // 2. tranfers curators fee to curator treasury
    // 3. tranfers remaining rewards to distribution farm
    function pushRewards(address rewardToken, bytes calldata symbioticRewardsData) external {
        Storage storage s = _contractStorage();
        FarmData memory data = s.farms[rewardToken];
        require(data.symbioticFarm != address(0), "Vault: farm not set");
        uint256 amountBefore = IERC20(rewardToken).balanceOf(address(this));
        IStakerRewards(data.symbioticFarm).claimRewards(address(this), rewardToken, symbioticRewardsData);
        uint256 rewardAmount = IERC20(rewardToken).balanceOf(address(this)) - amountBefore;
        if (rewardAmount == 0) return;

        uint256 curatorFee = Math.mulDiv(rewardAmount, data.curatorFeeD4, 1e4);
        if (curatorFee != 0) {
            IERC20(rewardToken).safeTransfer(data.curatorTreasury, curatorFee);
            rewardAmount -= curatorFee;
        }

        IERC20(rewardToken).safeTransfer(data.distributionFarm, rewardAmount);
        emit RewardsPushed(rewardToken, rewardAmount, block.timestamp);
    }

    // Virtual functions

    function _setFarmChecks(address rewardToken, FarmData memory farmData) internal virtual {
        Storage storage s = _contractStorage();
        if (
            rewardToken == s.token || rewardToken == address(this) || rewardToken == address(s.symbioticCollateral)
                || rewardToken == address(s.symbioticVault)
        ) {
            revert("Vault: forbidden reward token");
        }
        if (farmData.curatorFeeD4 > 1e4) {
            revert("Vault: invalid curator fee");
        }
    }

    // calculates the amount of staked tokens in the symbiotic vault with rouding
    function getSymbioticVaultStake(Math.Rounding rounding) public view returns (uint256 vaultActiveStake) {
        Storage storage s = _contractStorage();
        uint256 vaultActiveShares = s.symbioticVault.activeSharesOf(address(this));
        uint256 activeStake = s.symbioticVault.activeStake();
        uint256 activeShares = s.symbioticVault.activeShares();
        vaultActiveStake = Math.mulDiv(activeStake, vaultActiveShares, activeShares, rounding);
    }

    // calculates the total value locked in the vault in `token`
    function tvl(Math.Rounding rounding) public view returns (uint256 totalValueLocked) {
        Storage storage s = _contractStorage();
        return IERC20(s.token).balanceOf(address(this)) + s.symbioticCollateral.balanceOf(address(this))
            + getSymbioticVaultStake(rounding);
    }

    function deposit(address depositToken, uint256 amount, address recipient, address referral) external payable {
        Storage storage s = _contractStorage();
        uint256 totalSupply_ = totalSupply();
        uint256 valueBefore = tvl(Math.Rounding.Ceil);
        _deposit(depositToken, amount, referral);
        uint256 valueAfter = tvl(Math.Rounding.Floor);
        if (valueAfter <= valueBefore) {
            revert("BaseVault: invalid deposit amount");
        }
        uint256 depositValue = valueAfter - valueBefore;
        uint256 lpAmount = Math.mulDiv(totalSupply_, depositValue, valueBefore);
        if (lpAmount + totalSupply_ > s.limit) {
            revert("BaseVault: vault limit reached");
        } else if (lpAmount == 0) {
            revert("BaseVault: zero lpAmount");
        }
        pushIntoSymbiotic();

        _mint(recipient, lpAmount);
        emit Deposit(recipient, depositValue, lpAmount, referral);
    }

    // Withdrawal related functions

    function withdraw(uint256 lpAmount) external returns (uint256 withdrawnAmount, uint256 amountToClaim) {
        Storage storage s = _contractStorage();
        lpAmount = Math.min(lpAmount, balanceOf(msg.sender));
        if (lpAmount == 0) return (0, 0);
        _burn(msg.sender, lpAmount);

        uint256 tokenValue = IERC20(s.token).balanceOf(address(this));
        uint256 collateralValue = s.symbioticCollateral.balanceOf(address(this));
        uint256 symbioticVaultStake = getSymbioticVaultStake(Math.Rounding.Floor);

        uint256 totalValue = tokenValue + collateralValue + symbioticVaultStake;
        amountToClaim = Math.mulDiv(lpAmount, totalValue, totalSupply());
        if (tokenValue != 0) {
            uint256 tokenAmount = Math.min(amountToClaim, tokenValue);
            IERC20(s.token).safeTransfer(msg.sender, tokenAmount);
            amountToClaim -= tokenAmount;
            withdrawnAmount += tokenAmount;
            if (amountToClaim == 0) return (withdrawnAmount, 0);
        }

        if (collateralValue != 0) {
            uint256 collateralAmount = Math.min(amountToClaim, collateralValue);
            s.symbioticCollateral.withdraw(msg.sender, collateralAmount);

            amountToClaim -= collateralAmount;
            withdrawnAmount += collateralAmount;

            if (amountToClaim == 0) return (withdrawnAmount, 0);
        }

        uint256 sharesAmount = Math.mulDiv(
            amountToClaim, s.symbioticVault.activeShares(), s.symbioticVault.activeStake(), Math.Rounding.Floor
        );

        s.symbioticVault.withdraw(msg.sender, sharesAmount);
    }

    // deposits token into Collateral
    function pushIntoSymbiotic() public {
        Storage storage s = _contractStorage();
        uint256 assetAmount = IERC20(s.token).balanceOf(address(this));
        uint256 leftover = s.symbioticCollateral.limit() - s.symbioticCollateral.totalSupply();
        assetAmount = Math.min(assetAmount, leftover);
        if (assetAmount == 0) {
            return;
        }
        IERC20(s.token).safeIncreaseAllowance(address(s.symbioticCollateral), assetAmount);
        uint256 amount = s.symbioticCollateral.deposit(address(this), assetAmount);
        if (amount != assetAmount) {
            IERC20(s.token).forceApprove(address(s.symbioticCollateral), 0);
        }

        uint256 bondAmount = s.symbioticCollateral.balanceOf(address(this));
        IERC20(s.symbioticCollateral).safeIncreaseAllowance(address(s.symbioticVault), bondAmount);
        (uint256 stakedAmount,) = s.symbioticVault.deposit(address(this), bondAmount);
        if (bondAmount != stakedAmount) {
            IERC20(s.symbioticCollateral).forceApprove(address(s.symbioticVault), 0);
        }
    }

    // base implementation of deposit
    // transfers `amount` of `depositToken` from `msg.sender` to the vault
    // requires the deposit token to be the same as the vault token
    function _deposit(address depositToken, uint256 amount, address /* referral */ ) internal virtual {
        Storage storage s = _contractStorage();
        if (depositToken != s.token) revert("BaseVault: invalid deposit token");
        IERC20(depositToken).safeTransferFrom(msg.sender, address(this), amount);
    }

    // ERC20Votes overrides + Pausable modifier
    function _update(address from, address to, uint256 value) internal virtual override(ERC20Votes) whenNotPaused {
        super._update(from, to, value);
    }

    event Deposit(address indexed user, uint256 depositValue, uint256 lpAmount, address referral);
    event Withdrawal(address indexed user, uint256 amount);
    event NewLimit(uint256 limit);
    event PushToSymbioticBond(uint256 amount);
    event PushToSymbioticVault(uint256 initialAmount, uint256 amount, uint256 shares);
    event FarmSet(address rewardToken, FarmData farmData);

    event RewardsPushed(address rewardToken, uint256 rewardAmount, uint256 timestamp);
}
