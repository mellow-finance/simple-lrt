// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/adapters/ISymbioticAdapter.sol";
import {SymbioticWithdrawalQueue} from "../queues/SymbioticWithdrawalQueue.sol";

contract SymbioticAdapter is ISymbioticAdapter {
    /// @inheritdoc IProtocolAdapter
    address public immutable vault;
    /// @inheritdoc ISymbioticAdapter
    address public immutable claimer;
    /// @inheritdoc ISymbioticAdapter
    mapping(address symbioticVault => address withdrawalQueue) public withdrawalQueues;

    constructor(address vault_, address claimer_) {
        vault = vault_;
        claimer = claimer_;
    }

    /// @inheritdoc IProtocolAdapter
    function maxDeposit(address symbioticVault) external view returns (uint256) {
        ISymbioticVault vault_ = ISymbioticVault(symbioticVault);
        if (vault_.depositWhitelist() && !vault_.isDepositorWhitelisted(vault)) {
            return 0;
        }
        if (!vault_.isDepositLimit()) {
            return type(uint256).max;
        }
        uint256 activeStake = vault_.activeStake();
        uint256 limit = vault_.depositLimit();
        if (limit > activeStake) {
            return limit - activeStake;
        }
        return 0;
    }

    /// @inheritdoc IProtocolAdapter
    function assetOf(address symbioticVault) external view returns (address) {
        return ISymbioticVault(symbioticVault).collateral();
    }

    /// @inheritdoc IProtocolAdapter
    function maxWithdraw(address symbioticVault) external view returns (uint256) {
        return ISymbioticVault(symbioticVault).activeBalanceOf(vault);
    }

    /// @inheritdoc IProtocolAdapter
    function handleVault(address symbioticVault) external returns (address withdrawalQueue) {
        require(msg.sender == vault, "SymbioticAdapter: only vault");
        withdrawalQueue = withdrawalQueues[symbioticVault];
        if (withdrawalQueue != address(0)) {
            return withdrawalQueue;
        }
        withdrawalQueue = address(
            new SymbioticWithdrawalQueue{salt: keccak256(abi.encodePacked(symbioticVault))}(
                vault, symbioticVault, claimer
            )
        );
        withdrawalQueues[symbioticVault] = withdrawalQueue;
    }

    /// @inheritdoc IProtocolAdapter
    function validateFarmData(bytes calldata data) external pure {
        require(data.length == 20, "SymbioticAdapter: invalid farm data");
        address symbioticFarm = abi.decode(data, (address));
        require(symbioticFarm != address(0), "SymbioticAdapter: invalid farm data");
    }

    /// @inheritdoc IProtocolAdapter
    function pushRewards(address rewardToken, bytes calldata farmData, bytes memory rewardData)
        external
    {
        require(address(this) == vault, "SymbioticAdapter: delegate call only");
        address symbioticFarm = abi.decode(rewardData, (address));
        bytes memory symbioticFarmData = abi.decode(farmData, (bytes));
        IStakerRewards(symbioticFarm).claimRewards(vault, address(rewardToken), symbioticFarmData);
    }

    /// @inheritdoc IProtocolAdapter
    function withdraw(
        address symbioticVault,
        address withdrawalQueue,
        address receiver,
        uint256 request,
        address /* owner */
    ) external {
        require(address(this) == vault, "SymbioticAdapter: delegate call only");
        (, uint256 requestedShares) =
            ISymbioticVault(symbioticVault).withdraw(withdrawalQueue, request);
        ISymbioticWithdrawalQueue(withdrawalQueue).request(receiver, requestedShares);
    }

    /// @inheritdoc IProtocolAdapter
    function deposit(address symbioticVault, uint256 assets) external {
        require(address(this) == vault, "SymbioticAdapter: delegate call only");
        ISymbioticVault(symbioticVault).deposit(vault, assets);
    }
}
