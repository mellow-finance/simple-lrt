// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {ISymbioticWithdrawalQueue} from "../queues/ISymbioticWithdrawalQueue.sol";
import {IProtocolAdapter} from "./IProtocolAdapter.sol";
import {IERC20, IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IVault as ISymbioticVault} from "@symbiotic/core/interfaces/vault/IVault.sol";
import {IStakerRewards} from "@symbiotic/rewards/interfaces/stakerRewards/IStakerRewards.sol";

interface ISymbioticAdapter is IProtocolAdapter {
    function claimer() external view returns (address);

    function withdrawalQueues(address symbioticVault)
        external
        view
        returns (address withdrawalQueue);
}
