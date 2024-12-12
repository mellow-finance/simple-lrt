// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../utils/Claimer.sol";
import "./Core.sol";

contract Instance {
    using SafeERC20 for IERC20;

    address public immutable recipient;
    Core public immutable core;

    uint256 public mmAssets;

    constructor(address recipient_, uint256 mmAssets_) {
        recipient = recipient_;
        core = Core(msg.sender);
        mmAssets = mmAssets_;
    }

    function claim(
        uint256[] calldata subvaultIndices,
        uint256[][] calldata indices,
        uint256 maxAssets
    ) external {
        uint256 assets = Claimer(core.claimer()).multiAcceptAndClaim(
            core.multiVault(), subvaultIndices, indices, address(this), maxAssets
        );

        uint256 mmAssets_ = Math.min(mmAssets, assets);
        if (mmAssets_ != 0) {
            assets -= mmAssets_;
            mmAssets -= mmAssets_;
            core.asset().safeTransfer(address(core), mmAssets_);
        }
        if (assets != 0) {
            core.asset().safeTransfer(recipient, assets);
        }
    }
}
