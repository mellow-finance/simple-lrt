// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {IDefaultCollateral} from "./interfaces/IDefaultCollateral.sol";
import {ISymbioticVault} from "./interfaces/ISymbioticVault.sol";
import {IStakerRewards} from "./interfaces/IStakerRewards.sol";

// TODO: Storage initializer
// TODO: Off by 1 errors
// TODO; Tests
contract BaseVault is ERC20 {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    // keccak256(abi.encode(uint256(keccak256("mellow.storage.BaseVault")) - 1)) & ~bytes32(uint256(0xff))
    // TODO: FIX THIS
    bytes32 private constant BaseVaultStorageLocation =
        0xdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef;

    /// @param symbioticFarm address of the symbiotic farm
    /// @param distributionFarm address of the distribution farm (merkle tree or some other farm contract)
    /// @param curatorTreasury address of the curator treasury
    /// @param curatorFeeD4 curator fee in D4
    struct FarmData {
        address symbioticFarm;
        address distributionFarm;
        address curatorTreasury;
        uint256 curatorFeeD4;
    }

    /// @param symbioticCollateral address of the symbiotic collateral, base token for the symbiotic vault
    /// @param symbioticVault address of the symbiotic vault, used for (re) staking and unstaking
    /// @param token address of the vault token, used for deposits, withdrawals and tvl calculations
    /// @param owner address of the owner, can set farms, pause the vault and set the limit
    /// @param paused whether the vault is paused (no deposits, withdrawals or transfers)
    /// @param limit maximum amount of LP tokens that can be minted
    /// @param rewardTokens set of reward tokens
    /// @param farms mapping of reward token to farm data
    struct Storage {
        IDefaultCollateral symbioticCollateral;
        ISymbioticVault symbioticVault;
        address token;
        address owner;
        bool paused;
        uint256 limit;
        EnumerableSet.AddressSet rewardTokens;
        mapping(address rewardToken => FarmData data) farms;
    }

    function _contractStorage() private pure returns (Storage storage $) {
        assembly {
            $.slot := BaseVaultStorageLocation
        }
    }

    constructor(string memory _name, string memory _ticker) ERC20(_name, _ticker) {}

    function initialize(
        bytes32[] calldata _slotsForNullification,
        address _symbioticCollateral,
        address _symbioticVault,
        uint256 _limit,
        address _owner
    ) external {
        Storage storage s = _contractStorage();
        if (s.owner != address(0)) revert("BaseVault: already initialized");
        for (uint256 i = 0; i < _slotsForNullification.length; i++) {
            bytes32 slot = _slotsForNullification[i];
            assembly {
                sstore(slot, 0)
            }
        }
        s.symbioticVault = ISymbioticVault(_symbioticVault);
        s.symbioticCollateral = IDefaultCollateral(_symbioticCollateral);
        s.limit = _limit;
        s.token = IDefaultCollateral(_symbioticCollateral).asset();
        s.owner = _owner;
        s.paused = false;
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
        s.rewardTokens.add(rewardToken);
        emit FarmSet(rewardToken, farmData);
    }

    function removeFarmData(address rewardToken) external onlyOwner {
        Storage storage s = _contractStorage();
        delete s.farms[rewardToken];
        s.rewardTokens.remove(rewardToken);
    }

    function pause() external onlyOwner {
        _contractStorage().paused = true;
    }

    function unpause() external onlyOwner {
        _contractStorage().paused = false;
    }

    // 1. claims rewards from symbiotic farm
    // 2. tranfers curators fee to curator treasury
    // 3. tranfers remaining rewards to distribution farm
    function pushRewards(address rewardToken, bytes calldata symbioticRewardsData) external {
        FarmData memory data = _contractStorage().farms[rewardToken];
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
        ISymbioticVault symbioticVault = _contractStorage().symbioticVault;
        uint256 vaultActiveShares = symbioticVault.activeSharesOf(address(this));
        uint256 activeStake = symbioticVault.activeStake();
        uint256 activeShares = symbioticVault.activeShares();
        vaultActiveStake = Math.mulDiv(activeStake, vaultActiveShares, activeShares, rounding);
    }

    // calculates the total value locked in the vault in `token`
    function tvl(Math.Rounding rounding) public view returns (uint256 totalValueLocked) {
        Storage storage s = _contractStorage();
        return IERC20(s.token).balanceOf(address(this)) + s.symbioticCollateral.balanceOf(address(this))
            + getSymbioticVaultStake(rounding);
    }

    function deposit(address depositToken, uint256 amount, address recipient, address referral) external payable {
        uint256 totalSupply_ = totalSupply();
        uint256 valueBefore = tvl(Math.Rounding.Ceil);
        _deposit(depositToken, amount, referral);
        uint256 valueAfter = tvl(Math.Rounding.Floor);
        if (valueAfter <= valueBefore) {
            revert("BaseVault: invalid deposit amount");
        }
        uint256 depositValue = valueAfter - valueBefore;
        uint256 lpAmount = Math.mulDiv(totalSupply_, depositValue, valueBefore);
        if (lpAmount + totalSupply_ > _contractStorage().limit) {
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
        IERC20 token = IERC20(s.token);
        uint256 assetAmount = token.balanceOf(address(this));
        IDefaultCollateral symbioticCollateral = s.symbioticCollateral;
        ISymbioticVault symbioticVault = s.symbioticVault;
        uint256 leftover = symbioticCollateral.limit() - symbioticCollateral.totalSupply();
        assetAmount = Math.min(assetAmount, leftover);
        if (assetAmount == 0) {
            return;
        }
        token.safeIncreaseAllowance(address(symbioticCollateral), assetAmount);
        uint256 amount = symbioticCollateral.deposit(address(this), assetAmount);
        if (amount != assetAmount) {
            token.forceApprove(address(symbioticCollateral), 0);
        }

        uint256 bondAmount = symbioticCollateral.balanceOf(address(this));
        IERC20(symbioticCollateral).safeIncreaseAllowance(address(symbioticVault), bondAmount);
        (uint256 stakedAmount,) = symbioticVault.deposit(address(this), bondAmount);
        if (bondAmount != stakedAmount) {
            IERC20(symbioticCollateral).forceApprove(address(symbioticVault), 0);
        }
    }

    // base implementation of deposit
    // transfers `amount` of `depositToken` from `msg.sender` to the vault
    // requires the deposit token to be the same as the vault token
    function _deposit(address depositToken, uint256 amount, address /* referral */ ) internal virtual {
        if (depositToken != _contractStorage().token) revert("BaseVault: invalid deposit token");
        IERC20(depositToken).safeTransferFrom(msg.sender, address(this), amount);
    }

    // ERC20Votes overrides + Pausable modifier
    function _update(address from, address to, uint256 value) internal virtual override {
        require(!_contractStorage().paused, "BaseVault: paused");
        super._update(from, to, value);
    }

    modifier onlyOwner() {
        require(msg.sender == _contractStorage().owner, "BaseVault: forbidden");
        _;
    }

    event Deposit(address indexed user, uint256 depositValue, uint256 lpAmount, address referral);
    event Withdrawal(address indexed user, uint256 amount);
    event NewLimit(uint256 limit);
    event PushToSymbioticBond(uint256 amount);
    event PushToSymbioticVault(uint256 initialAmount, uint256 amount, uint256 shares);
    event FarmSet(address rewardToken, FarmData farmData);

    event RewardsPushed(address rewardToken, uint256 rewardAmount, uint256 timestamp);
}
