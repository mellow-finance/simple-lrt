// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IAToken is IERC20 {
    function POOL() external view returns (IAPool);
}

interface IAPool {
    function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode)
        external;

    function withdraw(address asset, uint256 amount, address to) external returns (uint256);

    struct ReserveConfigurationMap {
        uint256 data;
    }

    struct ReserveDataLegacy {
        ReserveConfigurationMap configuration;
        uint128 liquidityIndex;
        uint128 currentLiquidityRate;
        uint128 variableBorrowIndex;
        uint128 currentVariableBorrowRate;
        uint128 currentStableBorrowRate;
        uint40 lastUpdateTimestamp;
        uint16 id;
        address aTokenAddress;
        address stableDebtTokenAddress;
        address variableDebtTokenAddress;
        address interestRateStrategyAddress;
        uint128 accruedToTreasury;
        uint128 unbacked;
        uint128 isolationModeTotalDebt;
    }

    function getReserveData(address asset) external view returns (ReserveDataLegacy memory);
}

contract AaveToken is ERC4626Upgradeable {
    using SafeERC20 for IERC20;

    IERC4626 public vault;
    IAToken public aToken;
    IAPool public pool;

    function initialize(IERC4626 vault_, IAToken aToken_) external initializer {
        vault = vault_;
        __ERC20_init(
            string.concat("AaveERC4626_", vault_.name()), string.concat("AAVE-", vault_.symbol())
        );
        __ERC4626_init(IERC20(vault_.asset()));
        aToken = aToken_;
        pool = aToken_.POOL();
    }

    function totalAssets() public view override returns (uint256) {
        return IERC20(aToken).balanceOf(address(this));
    }

    function areDepositsLocked() public view returns (bool) {
        return (pool.getReserveData(asset()).configuration.data & 0x1300000000000000) != 0;
    }

    function areWithdrawalsLocked() public view returns (bool) {
        return (pool.getReserveData(asset()).configuration.data & 0x1100000000000000) != 0;
    }

    function maxDeposit(address) public view override returns (uint256) {
        return areDepositsLocked() ? 0 : type(uint256).max;
    }

    function maxMint(address) public view override returns (uint256) {
        return areDepositsLocked() ? 0 : type(uint256).max;
    }

    function maxWithdraw(address owner) public view override returns (uint256) {
        return areWithdrawalsLocked() ? 0 : _convertToAssets(balanceOf(owner), Math.Rounding.Floor);
    }

    function maxRedeem(address owner) public view override returns (uint256) {
        return areWithdrawalsLocked() ? 0 : balanceOf(owner);
    }

    function _deposit(address caller, address receiver, uint256 assets, uint256 shares)
        internal
        override
    {
        super._deposit(caller, receiver, assets, shares);
        IERC20(asset()).safeIncreaseAllowance(address(pool), assets);
        pool.supply(asset(), assets, address(this), 0);
    }

    function _withdraw(
        address caller,
        address receiver,
        address owner,
        uint256 assets,
        uint256 shares
    ) internal override {
        if (caller != owner) {
            _spendAllowance(owner, caller, shares);
        }

        _burn(owner, shares);
        pool.withdraw(asset(), assets, receiver);

        emit Withdraw(caller, receiver, owner, assets, shares);
    }
}
