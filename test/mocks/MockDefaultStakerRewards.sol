// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import {IDefaultStakerRewards} from
    "@symbiotic/rewards/interfaces/defaultStakerRewards/IDefaultStakerRewards.sol";
import {IStakerRewards} from "@symbiotic/rewards/interfaces/stakerRewards/IStakerRewards.sol";

import {IRegistry} from "@symbiotic/core/interfaces/common/IRegistry.sol";
import {INetworkMiddlewareService} from
    "@symbiotic/core/interfaces/service/INetworkMiddlewareService.sol";
import {IVault} from "@symbiotic/core/interfaces/vault/IVault.sol";

import {AccessControlUpgradeable} from
    "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

import {MulticallUpgradeable} from
    "@openzeppelin/contracts-upgradeable/utils/MulticallUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from
    "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {Time} from "@openzeppelin/contracts/utils/types/Time.sol";

contract MockDefaultStakerRewards is
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable,
    MulticallUpgradeable,
    IDefaultStakerRewards
{
    using SafeERC20 for IERC20;
    using Math for uint256;

    uint64 public constant version = 1;

    /**
     * @inheritdoc IDefaultStakerRewards
     */
    uint256 public constant ADMIN_FEE_BASE = 10000;

    /**
     * @inheritdoc IDefaultStakerRewards
     */
    bytes32 public constant ADMIN_FEE_CLAIM_ROLE = keccak256("ADMIN_FEE_CLAIM_ROLE");

    /**
     * @inheritdoc IDefaultStakerRewards
     */
    bytes32 public constant ADMIN_FEE_SET_ROLE = keccak256("ADMIN_FEE_SET_ROLE");

    /**
     * @inheritdoc IDefaultStakerRewards
     */
    address public immutable VAULT_FACTORY;

    /**
     * @inheritdoc IDefaultStakerRewards
     */
    address public immutable NETWORK_REGISTRY;

    /**
     * @inheritdoc IDefaultStakerRewards
     */
    address public immutable NETWORK_MIDDLEWARE_SERVICE;

    /**
     * @inheritdoc IDefaultStakerRewards
     */
    address public VAULT;

    /**
     * @inheritdoc IDefaultStakerRewards
     */
    uint256 public adminFee;

    /**
     * @inheritdoc IDefaultStakerRewards
     */
    mapping(address token => mapping(address network => RewardDistribution[] rewards_)) public
        rewards;

    /**
     * @inheritdoc IDefaultStakerRewards
     */
    mapping(
        address account => mapping(address token => mapping(address network => uint256 rewardIndex))
    ) public lastUnclaimedReward;

    /**
     * @inheritdoc IDefaultStakerRewards
     */
    mapping(address token => uint256 amount) public claimableAdminFee;

    mapping(uint48 timestamp => uint256 amount) private _activeSharesCache;

    constructor(address vaultFactory, address networkRegistry, address networkMiddlewareService) {
        _disableInitializers();

        VAULT_FACTORY = vaultFactory;
        NETWORK_REGISTRY = networkRegistry;
        NETWORK_MIDDLEWARE_SERVICE = networkMiddlewareService;
    }

    /**
     * @inheritdoc IDefaultStakerRewards
     */
    function rewardsLength(address token, address network) external view returns (uint256) {
        return rewards[token][network].length;
    }

    function claimable(address token, address account, bytes calldata data)
        external
        view
        override
        returns (uint256 amount)
    {
        // network - a network to claim rewards for
        // maxRewards - the maximum amount of rewards to process
        (address network, uint256 maxRewards) = abi.decode(data, (address, uint256));

        RewardDistribution[] storage rewardsByTokenNetwork = rewards[token][network];
        uint256 rewardIndex = lastUnclaimedReward[account][token][network];

        uint256 rewardsToClaim = Math.min(maxRewards, rewardsByTokenNetwork.length - rewardIndex);

        for (uint256 i; i < rewardsToClaim;) {
            RewardDistribution storage reward = rewardsByTokenNetwork[rewardIndex];

            amount += IVault(VAULT).activeSharesOfAt(account, reward.timestamp, new bytes(0)).mulDiv(
                reward.amount, _activeSharesCache[reward.timestamp]
            );

            unchecked {
                ++i;
                ++rewardIndex;
            }
        }
    }

    function initialize(InitParams calldata params) external 
    /**
     * initializer
     */
    {
        if (!IRegistry(VAULT_FACTORY).isEntity(params.vault)) {
            revert NotVault();
        }

        if (params.defaultAdminRoleHolder == address(0)) {
            if (params.adminFee == 0) {
                if (params.adminFeeClaimRoleHolder == address(0)) {
                    if (params.adminFeeSetRoleHolder != address(0)) {
                        revert MissingRoles();
                    }
                } else if (params.adminFeeSetRoleHolder == address(0)) {
                    revert MissingRoles();
                }
            } else if (params.adminFeeClaimRoleHolder == address(0)) {
                revert MissingRoles();
            }
        }

        // __ReentrancyGuard_init();

        VAULT = params.vault;

        _setAdminFee(params.adminFee);

        if (params.defaultAdminRoleHolder != address(0)) {
            _grantRole(DEFAULT_ADMIN_ROLE, params.defaultAdminRoleHolder);
        }
        if (params.adminFeeClaimRoleHolder != address(0)) {
            _grantRole(ADMIN_FEE_CLAIM_ROLE, params.adminFeeClaimRoleHolder);
        }
        if (params.adminFeeSetRoleHolder != address(0)) {
            _grantRole(ADMIN_FEE_SET_ROLE, params.adminFeeSetRoleHolder);
        }
    }

    function distributeRewards(address network, address token, uint256 amount, bytes calldata data)
        external
        override
        nonReentrant
    {
        // timestamp - a time point stakes must be taken into account at
        // maxAdminFee - the maximum admin fee to allow
        // activeSharesHint - a hint index to optimize `activeSharesAt()` processing
        // activeStakeHint - a hint index to optimize `activeStakeAt()` processing
        (
            uint48 timestamp,
            uint256 maxAdminFee,
            bytes memory activeSharesHint,
            bytes memory activeStakeHint
        ) = abi.decode(data, (uint48, uint256, bytes, bytes));

        if (INetworkMiddlewareService(NETWORK_MIDDLEWARE_SERVICE).middleware(network) != msg.sender)
        {
            revert NotNetworkMiddleware();
        }

        //if (timestamp >= Time.timestamp()) {
        //    revert InvalidRewardTimestamp();
        //}

        uint256 adminFee_ = adminFee;
        if (maxAdminFee < adminFee_) {
            revert HighAdminFee();
        }

        if (_activeSharesCache[timestamp] == 0) {
            uint256 activeShares_ = IVault(VAULT).activeSharesAt(timestamp, activeSharesHint);
            uint256 activeStake_ = IVault(VAULT).activeStakeAt(timestamp, activeStakeHint);

            // if (activeShares_ == 0 || activeStake_ == 0) {
            //     revert InvalidRewardTimestamp();
            // }

            _activeSharesCache[timestamp] = activeShares_;
        }

        uint256 balanceBefore = IERC20(token).balanceOf(address(this));
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        amount = IERC20(token).balanceOf(address(this)) - balanceBefore;

        if (amount == 0) {
            revert InsufficientReward();
        }

        uint256 adminFeeAmount = amount.mulDiv(adminFee_, ADMIN_FEE_BASE);
        uint256 distributeAmount = amount - adminFeeAmount;

        claimableAdminFee[token] += adminFeeAmount;

        if (distributeAmount > 0) {
            rewards[token][network].push(
                RewardDistribution({amount: distributeAmount, timestamp: timestamp})
            );
        }

        emit DistributeRewards(network, token, amount, data);
    }

    function claimRewards(address recipient, address token, bytes calldata data)
        external
        override
        nonReentrant
    {
        // network - a network to claim rewards for
        // maxRewards - the maximum amount of rewards to process
        // activeSharesOfHints - hint indexes to optimize `activeSharesOf()` processing
        (address network, uint256 maxRewards, bytes[] memory activeSharesOfHints) =
            abi.decode(data, (address, uint256, bytes[]));

        if (recipient == address(0)) {
            revert InvalidRecipient();
        }

        RewardDistribution[] storage rewardsByTokenNetwork = rewards[token][network];
        uint256 lastUnclaimedReward_ = lastUnclaimedReward[msg.sender][token][network];

        uint256 rewardsToClaim =
            Math.min(maxRewards, rewardsByTokenNetwork.length - lastUnclaimedReward_);

        if (rewardsToClaim == 0) {
            revert NoRewardsToClaim();
        }

        if (activeSharesOfHints.length == 0) {
            activeSharesOfHints = new bytes[](rewardsToClaim);
        } else if (activeSharesOfHints.length != rewardsToClaim) {
            revert InvalidHintsLength();
        }

        uint256 amount;
        uint256 rewardIndex = lastUnclaimedReward_;
        for (uint256 i; i < rewardsToClaim;) {
            RewardDistribution storage reward = rewardsByTokenNetwork[rewardIndex];

            amount += IVault(VAULT).activeSharesOfAt(
                msg.sender, reward.timestamp, activeSharesOfHints[i]
            ).mulDiv(reward.amount, _activeSharesCache[reward.timestamp]);

            unchecked {
                ++i;
                ++rewardIndex;
            }
        }

        lastUnclaimedReward[msg.sender][token][network] = rewardIndex;

        if (amount > 0) {
            IERC20(token).safeTransfer(recipient, amount);
        }

        emit ClaimRewards(
            token, network, msg.sender, recipient, lastUnclaimedReward_, rewardsToClaim, amount
        );
    }

    /**
     * @inheritdoc IDefaultStakerRewards
     */
    function claimAdminFee(address recipient, address token)
        external
        nonReentrant
        onlyRole(ADMIN_FEE_CLAIM_ROLE)
    {
        uint256 claimableAdminFee_ = claimableAdminFee[token];
        if (claimableAdminFee_ == 0) {
            revert InsufficientAdminFee();
        }

        claimableAdminFee[token] = 0;

        IERC20(token).safeTransfer(recipient, claimableAdminFee_);

        emit ClaimAdminFee(token, claimableAdminFee_);
    }

    /**
     * @inheritdoc IDefaultStakerRewards
     */
    function setAdminFee(uint256 adminFee_) external onlyRole(ADMIN_FEE_SET_ROLE) {
        if (adminFee == adminFee_) {
            revert AlreadySet();
        }

        _setAdminFee(adminFee_);

        emit SetAdminFee(adminFee_);
    }

    function _setAdminFee(uint256 adminFee_) private {
        if (adminFee_ > ADMIN_FEE_BASE) {
            revert InvalidAdminFee();
        }

        adminFee = adminFee_;
    }
}
