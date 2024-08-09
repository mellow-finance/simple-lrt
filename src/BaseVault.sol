// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {ERC20Votes, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import {ERC20Pausable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";

import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {DoubleEndedQueue} from "@openzeppelin/contracts/utils/structs/DoubleEndedQueue.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

import "./interfaces/IDefaultBond.sol";
import "./interfaces/ILimit.sol";
import "./interfaces/ISymbioticVault.sol";
import "./interfaces/IStakerRewards.sol";

// TODO: Upgradeable ERC20 tokens
// TODO: Storage initializer
// TODO: Off by 1 errors
// TODO; Tests
contract BaseVault is ERC20Votes, ERC20Pausable, Ownable {
    using SafeERC20 for IERC20;
    using DoubleEndedQueue for DoubleEndedQueue.Bytes32Deque;

    address public immutable symbioticBond;
    address public immutable symbioticVault;
    address public immutable token;

    uint256 public limit;

    struct FarmData {
        address symbioticFarm;
        address distributionFarm;
        uint256 curatorFeeD4;
        address curatorTreasury;
    }

    mapping(address rewardToken => FarmData data) public farms;
    mapping(address user => DoubleEndedQueue.Bytes32Deque) private _epochsToClaim;

    constructor(
        string memory _name,
        string memory _ticker,
        address _symbioticBond,
        address _symbioticVault,
        uint256 _limit,
        address _owner
    ) ERC20(_name, _ticker) EIP712(_name, "1") Ownable(_owner) {
        symbioticVault = _symbioticVault;
        symbioticBond = _symbioticBond;
        limit = _limit;
        token = IDefaultBond(symbioticBond).asset();
    }

    // Permissioned setters

    function setLimit(uint256 _limit) external onlyOwner {
        limit = _limit;
        emit NewLimit(_limit);
    }

    function setFarmData(address rewardToken, FarmData memory farmData) external onlyOwner {
        _setFarmChecks(rewardToken, farmData);
        farms[rewardToken] = farmData;
        emit FarmSet(rewardToken, farmData);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function claimRewards(address rewardToken) external onlyOwner {
        FarmData memory data = farms[rewardToken];
        require(data.symbioticFarm != address(0), "Vault: farm not set");
        IStakerRewards(data.symbioticFarm).claimRewards(address(this), rewardToken, new bytes(0));

        uint256 amount = IERC20(rewardToken).balanceOf(address(this));

        if (amount == 0) return;
        uint256 curatorFee = (amount * data.curatorFeeD4) / 10000;
        if (curatorFee != 0) {
            IERC20(rewardToken).safeTransfer(data.curatorTreasury, curatorFee);
            amount -= curatorFee;
        }
        IERC20(rewardToken).safeTransfer(data.distributionFarm, amount);
    }

    // Virtual functions

    function _setFarmChecks(address rewardToken, FarmData memory /* farmData */ ) internal virtual {
        if (
            rewardToken == token || rewardToken == address(this) || rewardToken == symbioticBond
                || rewardToken == symbioticVault
        ) {
            revert("Vault: forbidden reward token");
        }
    }

    function convertToToken(address, /* depositToken */ uint256 amount) public virtual returns (uint256) {
        return amount;
    }

    function convertToDepositToken(address, /* depositToken */ uint256 amount) public virtual returns (uint256) {
        return amount;
    }

    // Deposit / withdraw / claim functions

    function deposit(address depositToken, uint256 amount, address recipient, address referral) external payable {
        amount = convertToDepositToken(depositToken, _trimToLimit(address(this), convertToToken(depositToken, amount)));
        amount = _wrap(depositToken, amount);
        push();
        _mint(recipient, amount);
        emit Deposit(recipient, amount, referral);
    }

    function withdraw(uint256 amount) external {
        uint256 balance = IERC20(address(this)).balanceOf(msg.sender);
        amount = Math.min(amount, balance);
        if (amount == 0) return;

        _burn(msg.sender, amount);
        emit Withdrawal(msg.sender, amount);

        uint256 tokenBalance = IERC20(token).balanceOf(address(this));
        uint256 bondBalance = IERC20(symbioticBond).balanceOf(address(this));

        uint256 sharesBalance = IERC20(symbioticVault).balanceOf(address(this));
        uint256 amountToClaim = ((tokenBalance + bondBalance + sharesBalance) * amount) / totalSupply();

        uint256 tokenClaimAmount = Math.min(amountToClaim, tokenBalance);
        IERC20(token).safeTransfer(msg.sender, tokenClaimAmount);
        amountToClaim -= tokenClaimAmount;

        if (amountToClaim == 0) {
            return;
        }

        uint256 bondClaimAmount = Math.min(amountToClaim, bondBalance);
        IDefaultBond(symbioticBond).withdraw(msg.sender, bondClaimAmount);
        amountToClaim -= bondClaimAmount;

        if (amountToClaim == 0) {
            return;
        }

        ISymbioticVault(symbioticVault).withdraw(address(this), amountToClaim);
        _epochsToClaim[msg.sender].pushBack(bytes32(ISymbioticVault(symbioticVault).currentEpoch() + 1));
    }

    function claim(uint256 maxEpochs) external returns (uint256 amount) {
        address user = msg.sender;
        DoubleEndedQueue.Bytes32Deque storage queue = _epochsToClaim[user];
        maxEpochs = Math.min(maxEpochs, queue.length());
        uint256 currentEpoch = ISymbioticVault(symbioticVault).currentEpoch();
        for (uint256 index = 0; index < maxEpochs;) {
            uint256 epochToClaim = uint256(queue.front());
            if (epochToClaim >= currentEpoch) break;
            queue.popFront();
            try ISymbioticVault(symbioticVault).claim(msg.sender, epochToClaim) returns (uint256 amount_) {
                amount += amount_;
            } catch {}
            unchecked {
                ++index;
            }
        }
        emit Claimed(user, amount);
    }

    // * External helper functions

    function push() public {
        _pushToSymbioticBond();
        _pushToSymbioticVault();
    }

    function claimableWithdrawals(address user) external view returns (uint256 claimableAmount, uint256 epochs) {
        uint256 currentEpoch = ISymbioticVault(symbioticVault).currentEpoch();
        DoubleEndedQueue.Bytes32Deque storage queue = _epochsToClaim[user];
        for (uint256 index = 0; index < queue.length(); ++index) {
            uint256 epochToClaim = uint256(queue.at(index));
            if (epochToClaim >= currentEpoch) break;
            claimableAmount += ISymbioticVault(symbioticVault).withdrawalsOf(epochToClaim, user);
            unchecked {
                ++epochs;
            }
        }
    }

    function _pushToSymbioticVault() internal {
        uint256 bondAmount = IERC20(symbioticBond).balanceOf(address(this));
        // TODO: add ratio parameter
        IERC20(symbioticBond).safeIncreaseAllowance(symbioticVault, bondAmount);
        (uint256 amount, uint256 shares) = ISymbioticVault(symbioticVault).deposit(address(this), bondAmount);
        emit PushToSymbioticVault(bondAmount, amount, shares);
    }

    function _pushToSymbioticBond() internal {
        uint256 amount = IERC20(token).balanceOf(address(this));
        amount = _trimToLimit(symbioticBond, amount);
        if (amount == 0) {
            return;
        }
        IERC20(token).safeIncreaseAllowance(symbioticBond, amount);
        IDefaultBond(symbioticBond).deposit(address(this), amount);
        emit PushToSymbioticBond(amount);
    }

    function _wrap(address depositToken, uint256 amount) internal virtual returns (uint256) {
        if (depositToken != token) revert("BaseVault: invalid deposit token");
        if (amount == 0) revert("BaseVault: deposit amount must be greater than 0");
        return amount;
    }

    function _trimToLimit(address vault, uint256 amount) internal view returns (uint256) {
        uint256 leftover = ILimit(vault).limit() - ILimit(vault).totalSupply();
        return Math.min(amount, leftover);
    }

    function _update(address from, address to, uint256 value)
        internal
        virtual
        override(ERC20Votes, ERC20Pausable)
        whenNotPaused
    {
        super._update(from, to, value);
    }

    event Deposit(address indexed user, uint256 amount, address referral);
    event Withdrawal(address indexed user, uint256 amount);
    event NewLimit(uint256 limit);
    event PushToSymbioticBond(uint256 amount);
    event PushToSymbioticVault(uint256 initialAmount, uint256 amount, uint256 shares);
    event Claimed(address indexed user, uint256 amount);
    event FarmSet(address rewardToken, FarmData farmData);
}
