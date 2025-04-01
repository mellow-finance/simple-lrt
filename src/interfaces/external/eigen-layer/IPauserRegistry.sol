// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

interface IPauserRegistry {
    function isPauser(address pauser) external view returns (bool);
    function unpauser() external view returns (address);
}
