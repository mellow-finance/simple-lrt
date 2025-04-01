// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "./DVVStorage.sol";
import "./MellowVaultCompat.sol";
import "./VaultControlStorage.sol";

contract DVV is MellowVaultCompat, DVVStorage {
    using SafeERC20 for IERC20;

    bytes32 public constant SET_STAKING_MODULE_ROLE = keccak256("SET_STAKING_MODULE_ROLE");
    uint256 public constant AAVE_PAUSE_MASK = 0x1300000000000000;

    modifier onlyWhenNotPaused() {
        if ((AAVE_POOL.getReserveData(address(WETH)).configuration.data & AAVE_PAUSE_MASK) != 0) {
            revert("DVV: AAVE WETH is paused");
        }
        if ((AAVE_POOL.getReserveData(address(WSTETH)).configuration.data & AAVE_PAUSE_MASK) != 0) {
            revert("DVV: AAVE WSTETH is paused");
        }
        _;
    }

    constructor(address aaveWstETH_, address aaveWETH_) DVVStorage(aaveWstETH_, aaveWETH_) {}

    function initialize(address _admin, address _stakingModule) external initializer {
        uint256 balance =
            WETH.balanceOf(address(this)) + WSTETH.getStETHByWstETH(WSTETH.balanceOf(address(this)));
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
        __init_DVVStorage(_stakingModule);
        _pushIntoAave();
    }

    /// @inheritdoc IERC4626
    function totalAssets()
        public
        view
        virtual
        override(IERC4626, ERC4626Upgradeable)
        returns (uint256 assets_)
    {
        address this_ = address(this);
        assets_ = WETH.balanceOf(this_) + AAVE_WETH.balanceOf(this_);
        uint256 wstethBalance = WSTETH.balanceOf(this_) + AAVE_WSTETH.balanceOf(this_);
        if (wstethBalance != 0) {
            assets_ = WSTETH.getStETHByWstETH(wstethBalance);
        }
    }

    receive() external payable {
        require(_msgSender() == address(WETH), "DVV: forbidden");
    }

    function setStakingModule(address newStakingModule)
        external
        nonReentrant
        onlyRole(SET_STAKING_MODULE_ROLE)
    {
        _setStakingModule(newStakingModule);
    }

    function stake(bytes calldata data) external nonReentrant onlyWhenNotPaused {
        _pullFromAave(address(WETH), AAVE_WETH);
        Address.functionDelegateCall(
            address(stakingModule()), abi.encodeCall(IStakingModule.stake, (data, _msgSender()))
        );
        _pushIntoAave();
    }

    function _deposit(address caller, address receiver, uint256 assets, uint256 shares)
        internal
        virtual
        override
        onlyWhenNotPaused
    {
        super._deposit(caller, receiver, assets, shares);
        _pushIntoAave(address(WETH));
    }

    function _withdraw(
        address caller,
        address receiver,
        address owner,
        uint256 assets,
        uint256 shares
    ) internal virtual override onlyWhenNotPaused {
        if (caller != owner) {
            _spendAllowance(owner, caller, shares);
        }

        _burn(owner, shares);

        uint256 requiredValue = WSTETH.getWstETHByStETH(assets);
        if (requiredValue > 0) {
            address this_ = address(this);
            uint256 wstethBalance = WSTETH.balanceOf(this_);
            if (wstethBalance < requiredValue) {
                uint256 aaveWstethBalance = AAVE_WSTETH.balanceOf(this_);
                if (aaveWstethBalance + wstethBalance >= requiredValue) {
                    _pullFromAave(address(WSTETH), requiredValue - wstethBalance);
                } else {
                    _pullFromAave(address(WSTETH), aaveWstethBalance);
                    wstethBalance += aaveWstethBalance;
                    uint256 requiredWethValue =
                        WSTETH.getStETHByWstETH(requiredValue - wstethBalance);
                    uint256 wethBalance = WETH.balanceOf(this_);
                    if (wethBalance < requiredWethValue) {
                        uint256 aaveWethBalance =
                            Math.min(AAVE_WETH.balanceOf(this_), requiredWethValue - wethBalance);
                        _pullFromAave(address(WETH), aaveWethBalance);
                        requiredWethValue = wethBalance + aaveWethBalance;
                    }
                    if (requiredWethValue > 0) {
                        Address.functionDelegateCall(
                            address(stakingModule()),
                            abi.encodeCall(IStakingModule.forceStake, (requiredWethValue))
                        );
                    }
                }
            }

            requiredValue = Math.min(requiredValue, WSTETH.balanceOf(this_));
            if (requiredValue > 0) {
                IERC20(WSTETH).safeTransfer(receiver, requiredValue);
            }
        }

        emit Withdraw(caller, receiver, owner, assets, shares);
    }

    function _pushIntoAave() internal {
        _pushIntoAave(address(WETH));
        _pushIntoAave(address(WSTETH));
    }

    function _pushIntoAave(address asset_) internal {
        address this_ = address(this);
        uint256 balance = IERC20(asset_).balanceOf(this_);
        if (balance != 0) {
            IERC20(asset_).safeIncreaseAllowance(address(AAVE_POOL), balance);
            AAVE_POOL.supply(asset_, balance, this_, 0);
        }
        emit AaveDeposit(asset_, balance);
    }

    function _pullFromAave(address asset_, IAToken token) internal {
        _pullFromAave(asset_, token.balanceOf(address(this)));
    }

    function _pullFromAave(address asset_, uint256 assets) internal {
        if (assets != 0) {
            AAVE_POOL.withdraw(asset_, assets, address(this));
            emit AaveWithdraw(asset_, assets);
        }
    }

    event AaveDeposit(address indexed asset, uint256 amount);

    event AaveWithdraw(address indexed asset, uint256 amount);
}
