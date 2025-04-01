// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "./IDelegationManager.sol";
import "./IPauserRegistry.sol";
import "./IStrategy.sol";
import "./IStrategyManager.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IRewardsCoordinator {
    struct StrategyAndMultiplier {
        IStrategy strategy;
        uint96 multiplier;
    }

    struct OperatorReward {
        address operator;
        uint256 amount;
    }

    struct OperatorSplit {
        uint16 oldSplitBips;
        uint16 newSplitBips;
        uint32 activatedAt;
    }

    struct RewardsSubmission {
        StrategyAndMultiplier[] strategiesAndMultipliers;
        IERC20 token;
        uint256 amount;
        uint32 startTimestamp;
        uint32 duration;
    }

    struct OperatorDirectedRewardsSubmission {
        StrategyAndMultiplier[] strategiesAndMultipliers;
        IERC20 token;
        OperatorReward[] operatorRewards;
        uint32 startTimestamp;
        uint32 duration;
        string description;
    }

    struct DistributionRoot {
        bytes32 root;
        uint32 rewardsCalculationEndTimestamp;
        uint32 activatedAt;
        bool disabled;
    }

    struct EarnerTreeMerkleLeaf {
        address earner;
        bytes32 earnerTokenRoot;
    }

    struct TokenTreeMerkleLeaf {
        IERC20 token;
        uint256 cumulativeEarnings;
    }

    struct RewardsMerkleClaim {
        uint32 rootIndex;
        uint32 earnerIndex;
        bytes earnerTreeProof;
        EarnerTreeMerkleLeaf earnerLeaf;
        uint32[] tokenIndices;
        bytes[] tokenTreeProofs;
        TokenTreeMerkleLeaf[] tokenLeaves;
    }

    function processClaim(RewardsMerkleClaim calldata claim, address recipient) external;

    function processClaims(RewardsMerkleClaim[] calldata claims, address recipient) external;

    function submitRoot(bytes32 root, uint32 rewardsCalculationEndTimestamp) external;

    function disableRoot(uint32 rootIndex) external;

    function setClaimerFor(address claimer) external;

    function setActivationDelay(uint32 _activationDelay) external;

    function setDefaultOperatorSplit(uint16 split) external;

    function setOperatorAVSSplit(address operator, address avs, uint16 split) external;

    function setOperatorPISplit(address operator, uint16 split) external;

    function setRewardsUpdater(address _rewardsUpdater) external;

    function setRewardsForAllSubmitter(address _submitter, bool _newValue) external;

    function activationDelay() external view returns (uint32);

    function currRewardsCalculationEndTimestamp() external view returns (uint32);

    function claimerFor(address earner) external view returns (address);

    function cumulativeClaimed(address claimer, IERC20 token) external view returns (uint256);

    function defaultOperatorSplitBips() external view returns (uint16);

    function getOperatorAVSSplit(address operator, address avs) external view returns (uint16);

    function getOperatorPISplit(address operator) external view returns (uint16);

    function calculateEarnerLeafHash(EarnerTreeMerkleLeaf calldata leaf)
        external
        pure
        returns (bytes32);

    function calculateTokenLeafHash(TokenTreeMerkleLeaf calldata leaf)
        external
        pure
        returns (bytes32);

    function checkClaim(RewardsMerkleClaim calldata claim) external view returns (bool);

    function getDistributionRootsLength() external view returns (uint256);

    function getDistributionRootAtIndex(uint256 index)
        external
        view
        returns (DistributionRoot memory);

    function getCurrentDistributionRoot() external view returns (DistributionRoot memory);

    function getCurrentClaimableDistributionRoot()
        external
        view
        returns (DistributionRoot memory);

    function getRootIndexFromHash(bytes32 rootHash) external view returns (uint32);

    function rewardsUpdater() external view returns (address);

    function CALCULATION_INTERVAL_SECONDS() external view returns (uint32);

    function MAX_REWARDS_DURATION() external view returns (uint32);

    function MAX_RETROACTIVE_LENGTH() external view returns (uint32);

    function MAX_FUTURE_LENGTH() external view returns (uint32);

    function GENESIS_REWARDS_TIMESTAMP() external view returns (uint32);
}
