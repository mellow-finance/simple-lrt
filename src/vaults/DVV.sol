// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/tokens/IWETH.sol";
import "../interfaces/tokens/IWSTETH.sol";
import "./ERC4626Vault.sol";
import "./VaultControlStorage.sol";
import {ERC20Upgradeable} from
    "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts/access/IAccessControl.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";

interface IStakingModule {
    function stake(bytes calldata data, address caller) external;

    function forceStake(uint256 amount) external;
}

contract DefaultStakingModule is IStakingModule {
    bytes32 public constant STAKER_ROLE = keccak256("STAKER_ROLE");
    IWSTETH public constant WSTETH = IWSTETH(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0);
    IERC20 public constant WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    function stake(bytes calldata, /* data */ address caller) external {
        address this_ = address(this);
        require(IAccessControl(this_).hasRole(STAKER_ROLE, caller), "StakingModule: forbidden");
        forceStake(WETH.balanceOf(this_));
    }

    function forceStake(uint256 amount) public {
        IWETH(address(WETH)).withdraw(amount);
        Address.sendValue(payable(address(WSTETH)), amount);
    }
}

/*
    TODO:
    setter, getter, separate storage contract, tests, fix storage slot
*/
contract DVV is ERC4626Vault {
    using SafeERC20 for IERC20;

    struct DVVStorage {
        address yieldVault;
        address stakingModule;
    }

    IWSTETH public constant WSTETH = IWSTETH(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0);
    IERC20 public constant WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    bytes32 private constant storageSlot =
        0x52c63247e1f47db19d5ce0460040c497f067ca4cebf71ba98eeadabe20bace00;

    function yieldVault() public view returns (IERC4626) {
        return IERC4626(_dvvStorage().yieldVault);
    }

    function stakingModule() public view returns (IStakingModule) {
        return IStakingModule(_dvvStorage().stakingModule);
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
        return WSTETH.balanceOf(this_) + yieldVault_.previewRedeem(yieldVault_.balanceOf(this_))
            + WSTETH.getWstETHByStETH(WETH.balanceOf(this_));
        // for aave V3 we can add something like `+stakingModule().assetsOf(this)`;
    }

    function previewEthDeposit(uint256 ethAssets) public view returns (uint256 shares) {
        return previewDeposit(WSTETH.getWstETHByStETH(ethAssets));
    }

    receive() external payable {
        require(msg.sender == address(WETH), "DVV: forbidden");
    }

    function ethDeposit(uint256 ethAssets, address receiver, address referral)
        external
        payable
        returns (uint256 shares)
    {
        uint256 assets = WSTETH.getWstETHByStETH(ethAssets);
        uint256 maxAssets = maxDeposit(receiver);
        if (assets > maxAssets) {
            revert ERC4626ExceededMaxDeposit(receiver, assets, maxAssets);
        }
        shares = previewDeposit(assets);
        address caller = _msgSender();

        if (msg.value == ethAssets) {
            IWETH(address(WETH)).deposit{value: ethAssets}();
        } else {
            require(msg.value == 0, "DVV: msg.value must be zero for WETH deposit");
            IERC20(address(WETH)).safeTransferFrom(caller, address(this), ethAssets);
        }

        _mint(receiver, shares);

        emit Deposit(caller, receiver, assets, shares);
        emit ReferralDeposit(ethAssets, receiver, referral);
    }

    function stake(bytes calldata data) external {
        Address.functionDelegateCall(
            address(stakingModule()), abi.encodeCall(IStakingModule.stake, (data, _msgSender()))
        );
        _pushIntoYieldVault();
    }

    function _deposit(address, address, uint256, uint256) internal pure override {
        revert("DVV: forbidden");
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
        uint256 wstethBalance = WSTETH.balanceOf(this_);
        if (wstethBalance == 0) {
            return;
        }
        IERC4626 yieldVault_ = yieldVault();
        IERC20(address(WSTETH)).safeIncreaseAllowance(address(yieldVault_), wstethBalance);
        yieldVault_.deposit(wstethBalance, this_);
    }

    function _dvvStorage() private pure returns (DVVStorage storage $) {
        assembly {
            $.slot := storageSlot
        }
    }

    /// ---------------------------------------------------------------------------
    /// ------------- NOTE: MellowVaultCompat copy-and-paste below ----------------
    /// ---------------------------------------------------------------------------
    bytes32 private constant ERC20CompatStorageSlot = 0;
    // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.ERC20")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant ERC20UpgradeableStorageSlot =
        0x52c63247e1f47db19d5ce0460030c497f067ca4cebf71ba98eeadabe20bace00;

    function _getERC20CompatStorage() private pure returns (ERC20Storage storage $) {
        assembly {
            $.slot := ERC20CompatStorageSlot
        }
    }

    function _getERC20UpgradeableStorage() private pure returns (ERC20Storage storage $) {
        assembly {
            $.slot := ERC20UpgradeableStorageSlot
        }
    }

    constructor(bytes32 name_, uint256 version_) VaultControlStorage(name_, version_) {}

    function compatTotalSupply() external view returns (uint256) {
        return _getERC20CompatStorage()._totalSupply;
    }

    function migrateMultiple(address[] calldata users) external {
        for (uint256 i = 0; i < users.length; ++i) {
            migrate(users[i]);
        }
    }

    function migrate(address user) public {
        ERC20Storage storage compatStorage = _getERC20CompatStorage();
        uint256 balance = compatStorage._balances[user];
        if (balance == 0) {
            return;
        }
        ERC20Storage storage upgradeableStorage = _getERC20UpgradeableStorage();
        delete compatStorage._balances[user];
        unchecked {
            upgradeableStorage._balances[user] += balance;
            compatStorage._totalSupply -= balance;
            upgradeableStorage._totalSupply += balance;
        }
    }

    function migrateApproval(address from, address to) public {
        ERC20Storage storage compatStorage = _getERC20CompatStorage();
        uint256 allowance_ = compatStorage._allowances[from][to];
        if (allowance_ == 0) {
            return;
        }
        delete compatStorage._allowances[from][to];
        super._approve(from, to, allowance_, false);
    }

    /**
     * @inheritdoc ERC20Upgradeable
     * @notice Updates balances for token transfers, ensuring any pre-existing balances in the old storage are migrated before performing the update.
     * @param from The address sending the tokens.
     * @param to The address receiving the tokens.
     * @param value The amount of tokens being transferred.
     */
    function _update(address from, address to, uint256 value) internal virtual override {
        migrate(from);
        migrate(to);
        super._update(from, to, value);
    }

    /**
     * @inheritdoc ERC20Upgradeable
     * @notice Updates the allowance for the spender, ensuring any pre-existing allowances in the old storage are migrated before performing the update.
     * @param owner The address allowing the spender to spend tokens.
     * @param spender The address allowed to spend tokens.
     * @param value The amount of tokens the spender is allowed to spend.
     * @param emitEvent A flag to signal if the approval event should be emitted.
     */
    function _approve(address owner, address spender, uint256 value, bool emitEvent)
        internal
        virtual
        override(ERC20Upgradeable)
    {
        migrateApproval(owner, spender);
        super._approve(owner, spender, value, emitEvent);
    }

    /**
     * @inheritdoc IERC20
     * @notice Returns the allowance for the given owner and spender, combining both pre-migration and post-migration allowances.
     * @param owner The address allowing the spender to spend tokens.
     * @param spender The address allowed to spend tokens.
     * @return The combined allowance for the owner and spender.
     */
    function allowance(address owner, address spender)
        public
        view
        virtual
        override(ERC20Upgradeable, IERC20)
        returns (uint256)
    {
        return
            _getERC20CompatStorage()._allowances[owner][spender] + super.allowance(owner, spender);
    }

    /**
     * @inheritdoc IERC20
     * @notice Returns the balance of the given account, combining both pre-migration and post-migration balances.
     * @param account The address of the account to query.
     * @return The combined balance of the account.
     */
    function balanceOf(address account)
        public
        view
        override(IERC20, ERC20Upgradeable)
        returns (uint256)
    {
        return _getERC20CompatStorage()._balances[account] + super.balanceOf(account);
    }

    /**
     * @inheritdoc IERC20
     * @notice Returns the total supply of tokens, combining both pre-migration and post-migration supplies.
     * @return The combined total supply of tokens.
     */
    function totalSupply() public view override(IERC20, ERC20Upgradeable) returns (uint256) {
        return _getERC20CompatStorage()._totalSupply + super.totalSupply();
    }
}
