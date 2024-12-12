// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../vaults/MultiVault.sol";
import "./Instance.sol";

contract Core {
    using SafeERC20 for IERC20;

    uint256 public constant D18 = 1 ether;

    address public immutable mm;
    address public immutable multiVault;
    IERC20 public immutable asset;
    address public immutable claimer;

    uint256 public withdrawalDelay;
    uint256 public instantRateD18;
    uint256 public feeD18;
    uint256 public minVolume;

    modifier onlyMM() {
        require(msg.sender == mm, "Core: forbidden");
        _;
    }

    constructor(address _mm, address _multiVault, address claimer_) {
        mm = _mm;
        multiVault = _multiVault;
        asset = IERC20(MultiVault(multiVault).asset());
        claimer = claimer_;
    }

    function setWithdrawalDelay(uint256 delay) external onlyMM {
        withdrawalDelay = delay;
    }

    function deposit(uint256 amount) external onlyMM {
        asset.safeTransferFrom(mm, address(this), amount);
    }

    function withdraw(uint256 amount) external onlyMM {
        asset.safeTransfer(mm, amount);
    }

    function setParams(uint256 minVolume_, uint256 instantRateD18_, uint256 feeD18_)
        external
        onlyMM
    {
        require(instantRateD18 <= D18, "Core: invalid rate");
        require(feeD18 <= D18, "Core: invalid fee");
        minVolume = minVolume_;
        instantRateD18 = instantRateD18_;
        feeD18 = feeD18_;
    }

    function request(uint256 lpAmount, uint256 minInstant, uint256 maxFee, address recipient)
        external
        returns (Instance instance)
    {
        uint256 assets = MultiVault(multiVault).previewRedeem(lpAmount);
        require(assets >= minVolume, "Core: insufficient volume");
        uint256 instant =
            Math.min(Math.mulDiv(assets, instantRateD18, D18), asset.balanceOf(address(this)));
        require(instant >= minInstant, "Core: insufficient instant funds");
        uint256 fee = Math.mulDiv(assets - instant, feeD18, D18);
        require(fee <= maxFee, "Core: fee exceeds limit");

        instance = new Instance(recipient, claimer, instant + fee);
        MultiVault(multiVault).redeem(lpAmount, address(instance), msg.sender);
        asset.safeTransfer(recipient, instant);
    }
}
