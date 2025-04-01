// SPDX-FileCopyrightText: 2023 Lido <info@lido.fi>
// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.25;

interface IDepositSecurityModule {
    struct Signature {
        bytes32 r;
        bytes32 vs;
    }

    function VERSION() external view returns (uint256);
    function ATTEST_MESSAGE_PREFIX() external view returns (bytes32);
    function PAUSE_MESSAGE_PREFIX() external view returns (bytes32);
    function UNVET_MESSAGE_PREFIX() external view returns (bytes32);
    function LIDO() external view returns (address);
    function STAKING_ROUTER() external view returns (address);
    function DEPOSIT_CONTRACT() external view returns (address);
    function isDepositsPaused() external view returns (bool);
    function getOwner() external view returns (address);
    function getPauseIntentValidityPeriodBlocks() external view returns (uint256);
    function getMaxOperatorsPerUnvetting() external view returns (uint256);
    function getGuardianQuorum() external view returns (uint256);
    function canDeposit(uint256 stakingModuleId) external view returns (bool);
    function getLastDepositBlock() external view returns (uint256);
    function isMinDepositDistancePassed(uint256 stakingModuleId) external view returns (bool);
    function depositBufferedEther(
        uint256 blockNumber,
        bytes32 blockHash,
        bytes32 depositRoot,
        uint256 stakingModuleId,
        uint256 nonce,
        bytes calldata depositCalldata,
        Signature[] calldata sortedGuardianSignatures
    ) external;
}
