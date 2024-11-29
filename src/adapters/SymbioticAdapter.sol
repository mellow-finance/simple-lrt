// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/adapters/ISymbioticAdapter.sol";
import {SymbioticWithdrawalQueue} from "../queues/SymbioticWithdrawalQueue.sol";

contract SymbioticAdapter is ISymbioticAdapter {
    uint8 public constant PAUSED_DEPOSITS = 0;
    uint8 public constant PAUSED_ENTER_WITHDRAWAL_QUEUE = 1;

    address public immutable vault;
    address public immutable claimer;

    mapping(address symbioticVault => address withdrawalQueue) public withdrawalQueues;

    constructor(address vault_, address claimer_) {
        vault = vault_;
        claimer = claimer_;
    }

    function maxDeposit(address symbioticVault) external view returns (uint256) {
        ISymbioticVault vault_ = ISymbioticVault(symbioticVault);
        if (vault_.depositWhitelist() && !vault_.isDepositorWhitelisted(vault)) {
            return 0;
        }
        if (!vault_.isDepositLimit()) {
            return type(uint256).max;
        }
        uint256 totalStake = vault_.totalStake();
        uint256 limit = vault_.depositLimit();
        if (limit > totalStake) {
            return limit - totalStake;
        }
        return 0;
    }

    function assetOf(address symbioticVault) external view returns (address) {
        return ISymbioticVault(symbioticVault).collateral();
    }

    function maxWithdraw(address symbioticVault) external view returns (uint256) {
        return ISymbioticVault(symbioticVault).activeBalanceOf(vault);
    }

    function handleVault(address symbioticVault) external returns (address withdrawalQueue) {
        require(msg.sender == vault, "Vault only");
        withdrawalQueue = withdrawalQueues[symbioticVault];
        if (withdrawalQueue != address(0)) {
            return withdrawalQueue;
        }
        bytes32 queueSalt = keccak256(abi.encodePacked(symbioticVault));
        withdrawalQueue =
            address(new SymbioticWithdrawalQueue{salt: queueSalt}(vault, symbioticVault, claimer));
        withdrawalQueues[symbioticVault] = withdrawalQueue;
    }

    function validateFarmData(bytes calldata data) external pure {
        require(data.length == 20, "INVALID_FARM_DATA");
        address symbioticFarm = abi.decode(data, (address));
        require(symbioticFarm != address(0), "INVALID_FARM_DATA");
    }

    function pushRewards(address rewardToken, bytes calldata farmData, bytes memory rewardData)
        external
    {
        require(address(this) == vault, "Delegate call only");
        address symbioticFarm = abi.decode(rewardData, (address));
        bytes memory symbioticFarmData = abi.decode(farmData, (bytes));
        IStakerRewards(symbioticFarm).claimRewards(vault, address(rewardToken), symbioticFarmData);
    }

    function withdraw(
        address symbioticVault,
        address withdrawalQueue,
        address receiver,
        uint256 request,
        address /* owner */
    ) external {
        require(address(this) == vault, "Delegate call only");
        (, uint256 requestedShares) =
            ISymbioticVault(symbioticVault).withdraw(withdrawalQueue, request);
        ISymbioticWithdrawalQueue(withdrawalQueue).request(receiver, requestedShares);
    }

    function deposit(address symbioticVault, uint256 assets) external {
        require(address(this) == vault, "Delegate call only");
        ISymbioticVault(symbioticVault).deposit(vault, assets);
    }
}
