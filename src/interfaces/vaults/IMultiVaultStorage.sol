// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {IProtocolAdapter} from "../adapters/IProtocolAdapter.sol";
import {IWithdrawalQueue} from "../queues/IWithdrawalQueue.sol";
import {IDepositStrategy} from "../strategies/IDepositStrategy.sol";
import {IRebalanceStrategy} from "../strategies/IRebalanceStrategy.sol";
import {IWithdrawalStrategy} from "../strategies/IWithdrawalStrategy.sol";
import {IDefaultCollateral} from "../tokens/IDefaultCollateral.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {
    ERC4626Upgradeable,
    IERC4626
} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

interface IMultiVaultStorage {
    enum Protocol {
        SYMBIOTIC,
        EIGEN_LAYER,
        ERC4626
    }

    struct Subvault {
        Protocol protocol;
        address vault;
        address withdrawalQueue;
    }

    struct RewardData {
        address distributionFarm;
        address curatorTreasury;
        address token;
        uint256 curatorFeeD6;
        Protocol protocol;
        bytes data;
    }

    struct MultiStorage {
        address depositStrategy;
        address withdrawalStrategy;
        address rebalanceStrategy;
        Subvault[] subvaults;
        mapping(address subvault => uint256 index) indexOfSubvault;
        mapping(uint256 id => RewardData) rewardData;
        EnumerableSet.UintSet farmIds;
        address defaultCollateral;
        address symbioticAdapter;
        address eigenLayerAdapter;
        address erc4626Adapter;
        bytes32[16] _gap;
    }

    function subvaultsCount() external view returns (uint256);

    function subvaultAt(uint256 index) external view returns (Subvault memory);

    function indexOfSubvault(address subvault) external view returns (uint256);

    function defaultCollateral() external view returns (IDefaultCollateral);

    function depositStrategy() external view returns (IDepositStrategy);

    function withdrawalStrategy() external view returns (IWithdrawalStrategy);

    function rebalanceStrategy() external view returns (IRebalanceStrategy);

    function eigenLayerAdapter() external view returns (IProtocolAdapter);

    function symbioticAdapter() external view returns (IProtocolAdapter);

    function erc4626Adapter() external view returns (IProtocolAdapter);

    function rewardData(uint256 farmId) external view returns (RewardData memory);
}
