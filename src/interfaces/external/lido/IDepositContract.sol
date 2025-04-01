// SPDX-FileCopyrightText: 2023 Lido <info@lido.fi>
// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.25;

interface IDepositContract {
    function get_deposit_root() external view returns (bytes32 rootHash);
}
