// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

interface ISTETH {
    function submit(address _referral) external payable returns (uint256);
}
