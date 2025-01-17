// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "./DVVStorage.sol";
import "./MellowVaultCompat.sol";
import "./VaultControlStorage.sol";
import {ERC4626Upgradeable} from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

contract DVV is MellowVaultCompat, DVVStorage {
    using SafeERC20 for IERC20;

    constructor(bytes32 name_, uint256 version_, address wsteth_, address weth_)
        DVVStorage(name_, version_, wsteth_, weth_)
    {}

    function initialize(address _admin, address _stakingModule, address _yieldVault)
        external
        initializer
    {
        uint256 balance =
            WSTETH.balanceOf(address(this)) + WSTETH.getWstETHByStETH(WETH.balanceOf(address(this)));
        __initializeERC4626(
            _admin,
            balance,
            false,
            false,
            false,
            address(WETH),
            "Decentralized Validator Token",
            "DVstETH"
        );
        __init_DVVStorage(_stakingModule, _yieldVault);
    }

    function totalAssets()
        public
        view
        virtual
        override(IERC4626, ERC4626Upgradeable)
        returns (uint256 assets_)
    {
        address this_ = address(this);
        IERC4626 yieldVault_ = yieldVault();
        uint256 wstethBalance =
            WSTETH.balanceOf(this_) + yieldVault_.previewRedeem(yieldVault_.balanceOf(this_));
        return WSTETH.getStETHByWstETH(wstethBalance) + WETH.balanceOf(this_);
    }

    function ethDeposit(uint256 assets, address receiver, address referral)
        public
        payable
        virtual
        returns (uint256 shares)
    {
        require(msg.value == assets, "DVV: value mismatch");
        uint256 maxAssets = maxDeposit(receiver);
        if (assets > maxAssets) {
            revert ERC4626ExceededMaxDeposit(receiver, assets, maxAssets);
        }

        shares = previewDeposit(assets);

        WETH.deposit{value: assets}();

        _mint(receiver, shares);

        emit Deposit(_msgSender(), receiver, assets, shares);
        emit ReferralDeposit(assets, receiver, referral);

        return shares;
    }

    receive() external payable {
        require(_msgSender() == address(WETH), "DVV: forbidden");
    }

    function setStakingModule(address newStakingModule) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setStakingModule(newStakingModule);
    }

    function stake(bytes calldata data) external {
        Address.functionDelegateCall(
            address(stakingModule()), abi.encodeCall(IStakingModule.stake, (data, _msgSender()))
        );
        _pushIntoYieldVault();
    }

    function _withdraw(
        address caller,
        address receiver,
        address owner,
        uint256 assets,
        uint256 shares
    ) internal virtual override {
        if (caller != owner) {
            _spendAllowance(owner, caller, shares);
        }

        _burn(owner, shares);

        IERC4626 yieldVault_ = yieldVault();
        uint256 yieldAssets = yieldVault_.totalAssets();
        address this_ = address(this);
        if (yieldAssets >= assets) {
            yieldVault_.withdraw(assets, receiver, this_);
        } else {
            if (yieldAssets > 0) {
                yieldVault_.withdraw(yieldAssets, receiver, this_);
            }

            uint256 balance = WSTETH.balanceOf(this_);
            if (balance + yieldAssets < assets) {
                uint256 required = assets - balance - yieldAssets;
                Address.functionDelegateCall(
                    address(stakingModule()),
                    abi.encodeCall(IStakingModule.forceStake, (WSTETH.getStETHByWstETH(required)))
                );
                IERC20(WSTETH).safeTransfer(receiver, WSTETH.balanceOf(this_));
            } else {
                IERC20(WSTETH).safeTransfer(receiver, assets - yieldAssets);
            }
        }

        emit Withdraw(caller, receiver, owner, assets, shares);
    }

    function _pushIntoYieldVault() internal {
        address this_ = address(this);
        IERC4626 yieldVault_ = yieldVault();
        uint256 assets = Math.min(WSTETH.balanceOf(this_), yieldVault_.maxDeposit(this_));
        if (assets == 0) {
            return;
        }
        IERC20(address(WSTETH)).safeIncreaseAllowance(address(yieldVault_), assets);
        yieldVault_.deposit(assets, this_);
    }
}
