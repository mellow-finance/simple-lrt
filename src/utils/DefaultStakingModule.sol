// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/external/lido/IDepositContract.sol";
import "../interfaces/external/lido/IDepositSecurityModule.sol";
import "../interfaces/external/lido/ILidoLocator.sol";
import "../interfaces/external/lido/ILidoWithdrawalQueue.sol";
import "../interfaces/external/lido/IStakingRouter.sol";
import "../interfaces/tokens/IWETH.sol";
import "../interfaces/tokens/IWSTETH.sol";
import "../interfaces/utils/IStakingModule.sol";
import "@openzeppelin/contracts/access/IAccessControl.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

contract DefaultStakingModule is IStakingModule {
    error InvalidDepositRoot();
    error InvalidWithdrawalQueueState();
    error InvalidAmount();
    error Forbidden();

    struct StakeParams {
        uint256 blockNumber;
        bytes32 blockHash;
        bytes32 depositRoot;
        uint256 nonce;
        bytes depositCalldata;
        IDepositSecurityModule.Signature[] sortedGuardianSignatures;
    }

    bytes32 public constant STAKE_ROLE = keccak256("STAKE_ROLE");

    ILidoLocator public immutable LOCATOR;
    IWSTETH public immutable WSTETH;
    IWETH public immutable WETH;
    uint256 public immutable STAKING_MODULE_ID;

    constructor(address lidoLocator_, address weth_, uint256 stakingModuleId_) {
        LOCATOR = ILidoLocator(lidoLocator_);
        WSTETH = IWSTETH(ILidoWithdrawalQueue(LOCATOR.withdrawalQueue()).WSTETH());
        WETH = IWETH(weth_);
        STAKING_MODULE_ID = stakingModuleId_;
    }

    function stake(bytes calldata data, address caller) external {
        address this_ = address(this);
        if (!IAccessControl(this_).hasRole(STAKE_ROLE, caller)) {
            revert Forbidden();
        }

        StakeParams memory params = abi.decode(data, (StakeParams));

        uint256 amount;
        IDepositSecurityModule depositSecurityModule =
            IDepositSecurityModule(LOCATOR.depositSecurityModule());
        if (
            IDepositContract(depositSecurityModule.DEPOSIT_CONTRACT()).get_deposit_root()
                != params.depositRoot
        ) {
            revert InvalidDepositRoot();
        }
        {
            uint256 wethBalance = WETH.balanceOf(address(this));
            uint256 unfinalizedStETH =
                ILidoWithdrawalQueue(LOCATOR.withdrawalQueue()).unfinalizedStETH();
            uint256 bufferedEther = ISTETH(LOCATOR.lido()).getBufferedEther();
            if (bufferedEther < unfinalizedStETH) {
                revert InvalidWithdrawalQueueState();
            }

            uint256 maxDepositsCount = Math.min(
                IStakingRouter(depositSecurityModule.STAKING_ROUTER())
                    .getStakingModuleMaxDepositsCount(
                    STAKING_MODULE_ID, wethBalance + bufferedEther - unfinalizedStETH
                ),
                IStakingRouter(depositSecurityModule.STAKING_ROUTER())
                    .getStakingModuleMaxDepositsPerBlock(STAKING_MODULE_ID)
            );
            amount = Math.min(wethBalance, 32 ether * maxDepositsCount);
        }
        if (amount == 0) {
            revert InvalidAmount();
        }
        forceStake(amount);
        depositSecurityModule.depositBufferedEther(
            params.blockNumber,
            params.blockHash,
            params.depositRoot,
            STAKING_MODULE_ID,
            params.nonce,
            params.depositCalldata,
            params.sortedGuardianSignatures
        );
        emit DepositCompleted(amount, params);
    }

    function forceStake(uint256 amount) public {
        WETH.withdraw(amount);
        Address.sendValue(payable(address(WSTETH)), amount);
        emit ForceStaked(amount);
    }

    event DepositCompleted(uint256 amount, StakeParams params);
    event ForceStaked(uint256 amount);
}
