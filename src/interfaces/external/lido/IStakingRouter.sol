// SPDX-FileCopyrightText: 2023 Lido <info@lido.fi>
// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.25;

interface IStakingRouter {
    function getStakingModuleMaxDepositsPerBlock(uint256 _stakingModuleId)
        external
        view
        returns (uint256);

    function getStakingModuleMaxDepositsCount(uint256 _stakingModuleId, uint256 _maxDepositsValue)
        external
        view
        returns (uint256);
}
