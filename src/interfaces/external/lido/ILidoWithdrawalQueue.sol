// SPDX-FileCopyrightText: 2023 Lido <info@lido.fi>
// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.25;

interface ILidoWithdrawalQueue {
    function WSTETH() external view returns (address);

    function unfinalizedStETH() external view returns (uint256);
}
