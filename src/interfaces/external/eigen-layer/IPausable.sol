// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "./IPauserRegistry.sol";

interface IPausable {
    function pauserRegistry() external view returns (IPauserRegistry);
    function pause(uint256 newPausedStatus) external;
    function pauseAll() external;
    function unpause(uint256 newPausedStatus) external;
    function paused() external view returns (uint256);
    function paused(uint8 index) external view returns (bool);
}
