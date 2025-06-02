// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.12;

import {IPausable} from "@eigenlayer-interfaces/IPausable.sol";
import {IPauserRegistry} from "@eigenlayer-interfaces/IPauserRegistry.sol";
import {IStrategy} from "@eigenlayer-interfaces/IStrategy.sol";
import {IStrategyManager} from "@eigenlayer-interfaces/IStrategyManager.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ShortStrings.sol";

/// @title SemVerMixin
/// @notice A mixin contract that provides semantic versioning functionality.
/// @dev Follows SemVer 2.0.0 specification (https://semver.org/).
abstract contract SemVerMixin {
    using ShortStrings for *;

    /// @notice The semantic version string for this contract, stored as a ShortString for gas efficiency.
    /// @dev Follows SemVer 2.0.0 specification (https://semver.org/). Prefixed with 'v' (e.g., "v1.2.3").
    ShortString internal immutable _VERSION;

    /// @notice Initializes the contract with a semantic version string.
    /// @param _version The SemVer-formatted version string (e.g., "v1.2.3")
    /// @dev Version should follow SemVer 2.0.0 format with 'v' prefix: vMAJOR.MINOR.PATCH
    constructor(string memory _version) {
        _VERSION = _version.toShortString();
    }

    function version() public view virtual returns (string memory) {
        return _VERSION.toString();
    }

    /// @notice Returns the major version of the contract.
    /// @dev Supports single digit major versions (e.g., "v1" for version "v1.2.3")
    /// @return The major version string (e.g., "v1" for version "v1.2.3")
    function _majorVersion() internal view returns (string memory) {
        bytes memory v = bytes(_VERSION.toString());
        return string(bytes.concat(v[0], v[1]));
    }
}

abstract contract Pausable is IPausable {
    /// Constants

    uint256 internal constant _UNPAUSE_ALL = 0;

    uint256 internal constant _PAUSE_ALL = type(uint256).max;

    /// @notice Address of the `PauserRegistry` contract that this contract defers to for determining access control (for pausing).
    IPauserRegistry public immutable pauserRegistry;

    /// Storage

    /// @dev Do not remove, deprecated storage.
    IPauserRegistry private __deprecated_pauserRegistry;

    /// @dev Returns a bitmap representing the paused status of the contract.
    uint256 private _paused;

    /// Modifiers

    /// @dev Thrown if the caller is not a valid pauser according to the pauser registry.
    modifier onlyPauser() {
        require(pauserRegistry.isPauser(msg.sender), "OnlyPauser()");
        _;
    }

    /// @dev Thrown if the caller is not a valid unpauser according to the pauser registry.
    modifier onlyUnpauser() {
        require(msg.sender == pauserRegistry.unpauser(), "OnlyUnpauser()");
        _;
    }

    /// @dev Thrown if the contract is paused, i.e. if any of the bits in `_paused` is flipped to 1.
    modifier whenNotPaused() {
        require(_paused == 0, "CurrentlyPaused()");
        _;
    }

    modifier onlyWhenNotPaused(uint8 index) {
        require(!paused(index), "CurrentlyPaused()");
        _;
    }

    constructor(IPauserRegistry _pauserRegistry) {
        require(address(_pauserRegistry) != address(0), "PauserRegistryZeroAddress()");
        pauserRegistry = _pauserRegistry;
    }

    function pause(uint256 newPausedStatus) external onlyPauser {
        uint256 currentPausedStatus = _paused;
        // verify that the `newPausedStatus` does not *unflip* any bits (i.e. doesn't unpause anything, all 1 bits remain)
        require(
            (currentPausedStatus & newPausedStatus) == currentPausedStatus,
            "InvalidNewPausedStatus()"
        );
        _setPausedStatus(newPausedStatus);
    }

    function pauseAll() external onlyPauser {
        _setPausedStatus(_PAUSE_ALL);
    }

    function unpause(uint256 newPausedStatus) external onlyUnpauser {
        uint256 currentPausedStatus = _paused;
        // verify that the `newPausedStatus` does not *flip* any bits (i.e. doesn't pause anything, all 0 bits remain)
        require(
            ((~currentPausedStatus) & (~newPausedStatus)) == (~currentPausedStatus),
            "InvalidNewPausedStatus()"
        );
        _paused = newPausedStatus;
        // emit Unpaused(msg.sender, newPausedStatus);
    }

    function paused() public view virtual returns (uint256) {
        return _paused;
    }

    function paused(uint8 index) public view virtual returns (bool) {
        uint256 mask = 1 << index;
        return ((_paused & mask) == mask);
    }

    /// @dev Internal helper for setting the paused status, and emitting the corresponding event.
    function _setPausedStatus(uint256 pausedStatus) internal {
        _paused = pausedStatus;
        // emit Paused(msg.sender, pausedStatus);
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[48] private __gap;
}

contract StrategyBase is Initializable, Pausable, IStrategy, SemVerMixin {
    using SafeERC20 for IERC20;

    uint8 internal constant PAUSED_DEPOSITS = 0;
    uint8 internal constant PAUSED_WITHDRAWALS = 1;

    /**
     * @notice virtual shares used as part of the mitigation of the common 'share inflation' attack vector.
     * Constant value chosen to reasonably reduce attempted share inflation by the first depositor, while still
     * incurring reasonably small losses to depositors
     */
    uint256 internal constant SHARES_OFFSET = 1e3;
    /**
     * @notice virtual balance used as part of the mitigation of the common 'share inflation' attack vector
     * Constant value chosen to reasonably reduce attempted share inflation by the first depositor, while still
     * incurring reasonably small losses to depositors
     */
    uint256 internal constant BALANCE_OFFSET = 1e3;

    /**
     * @notice The maximum total shares for a given strategy
     * @dev This constant prevents overflow in offchain services for rewards
     */
    uint256 internal constant MAX_TOTAL_SHARES = 1e38 - 1;

    /// @notice EigenLayer's StrategyManager contract
    IStrategyManager public immutable strategyManager;

    /// @notice The underlying token for shares in this Strategy
    IERC20 public underlyingToken;

    /// @notice The total number of extant shares in this Strategy
    uint256 public totalShares;

    /// @notice Simply checks that the `msg.sender` is the `strategyManager`, which is an address stored immutably at construction.
    modifier onlyStrategyManager() {
        require(msg.sender == address(strategyManager), "OnlyStrategyManager()");
        _;
    }

    /// @notice Since this contract is designed to be initializable, the constructor simply sets `strategyManager`, the only immutable variable.
    constructor(
        IStrategyManager _strategyManager,
        IPauserRegistry _pauserRegistry,
        string memory _version
    ) Pausable(_pauserRegistry) SemVerMixin(_version) {
        strategyManager = _strategyManager;
        _disableInitializers();
    }

    function initialize(IERC20 _underlyingToken) public virtual initializer {
        _initializeStrategyBase(_underlyingToken);
    }

    /// @notice Sets the `underlyingToken` and `pauserRegistry` for the strategy.
    function _initializeStrategyBase(IERC20 _underlyingToken) internal onlyInitializing {
        underlyingToken = _underlyingToken;
        _setPausedStatus(_UNPAUSE_ALL);
        // emit StrategyTokenSet(underlyingToken, IERC20Metadata(address(_underlyingToken)).decimals());
    }

    /**
     * @notice Used to deposit tokens into this Strategy
     * @param token is the ERC20 token being deposited
     * @param amount is the amount of token being deposited
     * @dev This function is only callable by the strategyManager contract. It is invoked inside of the strategyManager's
     * `depositIntoStrategy` function, and individual share balances are recorded in the strategyManager as well.
     * @dev Note that the assumption is made that `amount` of `token` has already been transferred directly to this contract
     * (as performed in the StrategyManager's deposit functions). In particular, setting the `underlyingToken` of this contract
     * to be a fee-on-transfer token will break the assumption that the amount this contract *received* of the token is equal to
     * the amount that was input when the transfer was performed (i.e. the amount transferred 'out' of the depositor's balance).
     * @dev Note that any validation of `token` is done inside `_beforeDeposit`. This can be overridden if needed.
     * @return newShares is the number of new shares issued at the current exchange ratio.
     */
    function deposit(IERC20 token, uint256 amount)
        external
        virtual
        override
        onlyWhenNotPaused(PAUSED_DEPOSITS)
        onlyStrategyManager
        returns (uint256 newShares)
    {
        // call hook to allow for any pre-deposit logic
        _beforeDeposit(token, amount);

        // copy `totalShares` value to memory, prior to any change
        uint256 priorTotalShares = totalShares;

        /**
         * @notice calculation of newShares *mirrors* `underlyingToShares(amount)`, but is different since the balance of `underlyingToken`
         * has already been increased due to the `strategyManager` transferring tokens to this strategy prior to calling this function
         */
        // account for virtual shares and balance
        uint256 virtualShareAmount = priorTotalShares + SHARES_OFFSET;
        uint256 virtualTokenBalance = _tokenBalance() + BALANCE_OFFSET;
        // calculate the prior virtual balance to account for the tokens that were already transferred to this contract
        uint256 virtualPriorTokenBalance = virtualTokenBalance - amount;
        newShares = (amount * virtualShareAmount) / virtualPriorTokenBalance;

        // extra check for correctness / against edge case where share rate can be massively inflated as a 'griefing' sort of attack
        require(newShares != 0, "ZeroShares()");

        // update total share amount to account for deposit
        totalShares = (priorTotalShares + newShares);
        require(totalShares <= MAX_TOTAL_SHARES, "TotalSharesExceedsMax()");

        // emit exchange rate
        _emitExchangeRate(virtualTokenBalance, totalShares + SHARES_OFFSET);

        return newShares;
    }

    /**
     * @notice Used to withdraw tokens from this Strategy, to the `recipient`'s address
     * @param recipient is the address to receive the withdrawn funds
     * @param token is the ERC20 token being transferred out
     * @param amountShares is the amount of shares being withdrawn
     * @dev This function is only callable by the strategyManager contract. It is invoked inside of the strategyManager's
     * other functions, and individual share balances are recorded in the strategyManager as well.
     * @dev Note that any validation of `token` is done inside `_beforeWithdrawal`. This can be overridden if needed.
     */
    function withdraw(address recipient, IERC20 token, uint256 amountShares)
        external
        virtual
        override
        onlyWhenNotPaused(PAUSED_WITHDRAWALS)
        onlyStrategyManager
    {
        // call hook to allow for any pre-withdrawal logic
        _beforeWithdrawal(recipient, token, amountShares);

        // copy `totalShares` value to memory, prior to any change
        uint256 priorTotalShares = totalShares;
        require(amountShares <= priorTotalShares, "WithdrawalAmountExceedsTotalDeposits()");

        /**
         * @notice calculation of amountToSend *mirrors* `sharesToUnderlying(amountShares)`, but is different since the `totalShares` has already
         * been decremented. Specifically, notice how we use `priorTotalShares` here instead of `totalShares`.
         */
        // account for virtual shares and balance
        uint256 virtualPriorTotalShares = priorTotalShares + SHARES_OFFSET;
        uint256 virtualTokenBalance = _tokenBalance() + BALANCE_OFFSET;
        // calculate ratio based on virtual shares and balance, being careful to multiply before dividing
        uint256 amountToSend = (virtualTokenBalance * amountShares) / virtualPriorTotalShares;

        // Decrease the `totalShares` value to reflect the withdrawal
        totalShares = priorTotalShares - amountShares;

        // emit exchange rate
        _emitExchangeRate(virtualTokenBalance - amountToSend, totalShares + SHARES_OFFSET);

        _afterWithdrawal(recipient, token, amountToSend);
    }

    /**
     * @notice Called in the external `deposit` function, before any logic is executed. Expected to be overridden if strategies want such logic.
     * @param token The token being deposited
     */
    function _beforeDeposit(
        IERC20 token,
        uint256 // amount
    ) internal virtual {
        require(token == underlyingToken, "OnlyUnderlyingToken()");
    }

    /**
     * @notice Called in the external `withdraw` function, before any logic is executed.  Expected to be overridden if strategies want such logic.
     * @param token The token being withdrawn
     */
    function _beforeWithdrawal(
        address, // recipient
        IERC20 token,
        uint256 // amountShares
    ) internal virtual {
        require(token == underlyingToken, "OnlyUnderlyingToken()");
    }

    /**
     * @notice Transfers tokens to the recipient after a withdrawal is processed
     * @dev Called in the external `withdraw` function after all logic is executed
     * @param recipient The destination of the tokens
     * @param token The ERC20 being transferred
     * @param amountToSend The amount of `token` to transfer
     */
    function _afterWithdrawal(address recipient, IERC20 token, uint256 amountToSend)
        internal
        virtual
    {
        token.safeTransfer(recipient, amountToSend);
    }

    /// @inheritdoc IStrategy
    function explanation() external pure virtual override returns (string memory) {
        return "Base Strategy implementation to inherit from for more complex implementations";
    }

    /// @inheritdoc IStrategy
    function sharesToUnderlyingView(uint256 amountShares)
        public
        view
        virtual
        override
        returns (uint256)
    {
        // account for virtual shares and balance
        uint256 virtualTotalShares = totalShares + SHARES_OFFSET;
        uint256 virtualTokenBalance = _tokenBalance() + BALANCE_OFFSET;
        // calculate ratio based on virtual shares and balance, being careful to multiply before dividing
        return (virtualTokenBalance * amountShares) / virtualTotalShares;
    }

    /// @inheritdoc IStrategy
    function sharesToUnderlying(uint256 amountShares)
        public
        view
        virtual
        override
        returns (uint256)
    {
        return sharesToUnderlyingView(amountShares);
    }

    /// @inheritdoc IStrategy
    function underlyingToSharesView(uint256 amountUnderlying)
        public
        view
        virtual
        returns (uint256)
    {
        // account for virtual shares and balance
        uint256 virtualTotalShares = totalShares + SHARES_OFFSET;
        uint256 virtualTokenBalance = _tokenBalance() + BALANCE_OFFSET;
        // calculate ratio based on virtual shares and balance, being careful to multiply before dividing
        return (amountUnderlying * virtualTotalShares) / virtualTokenBalance;
    }

    /// @inheritdoc IStrategy
    function underlyingToShares(uint256 amountUnderlying) external view virtual returns (uint256) {
        return underlyingToSharesView(amountUnderlying);
    }

    /// @inheritdoc IStrategy
    function userUnderlyingView(address user) external view virtual returns (uint256) {
        return sharesToUnderlyingView(shares(user));
    }

    /// @inheritdoc IStrategy
    function userUnderlying(address user) external virtual returns (uint256) {
        return sharesToUnderlying(shares(user));
    }

    /// @inheritdoc IStrategy
    function shares(address user) public view virtual returns (uint256) {
        return strategyManager.stakerDepositShares(user, IStrategy(address(this)));
    }

    /// @notice Internal function used to fetch this contract's current balance of `underlyingToken`.
    // slither-disable-next-line dead-code
    function _tokenBalance() internal view virtual returns (uint256) {
        return underlyingToken.balanceOf(address(this));
    }

    /// @notice Internal function used to emit the exchange rate of the strategy in wad (18 decimals)
    /// @dev Tokens that do not have 18 decimals must have offchain services scale the exchange rate down to proper magnitude
    function _emitExchangeRate(uint256 virtualTokenBalance, uint256 virtualTotalShares) internal {
        // Emit asset over shares ratio.
        // emit ExchangeRateEmitted((1e18 * virtualTokenBalance) / virtualTotalShares);
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[48] private __gap;
}

contract MockStrategyBaseTVLLimits is StrategyBase {
    bool public getTVLLimitsRevert;
    /// The maximum deposit (in underlyingToken) that this strategy will accept per deposit
    uint256 public maxPerDeposit;

    /// The maximum deposits (in underlyingToken) that this strategy will hold
    uint256 public maxTotalDeposits;

    /// @notice Emitted when `maxPerDeposit` value is updated from `previousValue` to `newValue`
    event MaxPerDepositUpdated(uint256 previousValue, uint256 newValue);

    /// @notice Emitted when `maxTotalDeposits` value is updated from `previousValue` to `newValue`
    event MaxTotalDepositsUpdated(uint256 previousValue, uint256 newValue);

    // solhint-disable-next-line no-empty-blocks
    constructor(
        IStrategyManager _strategyManager,
        IPauserRegistry _pauserRegistry,
        string memory _version
    ) StrategyBase(_strategyManager, _pauserRegistry, _version) {}

    function initialize(uint256 _maxPerDeposit, uint256 _maxTotalDeposits, IERC20 _underlyingToken)
        public
        virtual
        initializer
    {
        _setTVLLimits(_maxPerDeposit, _maxTotalDeposits);
        _initializeStrategyBase(_underlyingToken);
    }

    /**
     * @notice Sets the maximum deposits (in underlyingToken) that this strategy will hold and accept per deposit
     * @param newMaxTotalDeposits The new maximum deposits
     * @dev Callable only by the unpauser of this contract
     * @dev We note that there is a potential race condition between a call to this function that lowers either or both of these limits and call(s)
     * to `deposit`, that may result in some calls to `deposit` reverting.
     */
    function setTVLLimits(uint256 newMaxPerDeposit, uint256 newMaxTotalDeposits)
        external
        onlyUnpauser
    {
        _setTVLLimits(newMaxPerDeposit, newMaxTotalDeposits);
    }

    function setGetTVLLimitsRevert(bool newValue) public {
        getTVLLimitsRevert = newValue;
    }

    /// @notice Simple getter function that returns the current values of `maxPerDeposit` and `maxTotalDeposits`.
    function getTVLLimits() external view returns (uint256, uint256) {
        if (getTVLLimitsRevert) {
            revert();
        }
        return (maxPerDeposit, maxTotalDeposits);
    }

    /// @notice Internal setter for TVL limits
    function _setTVLLimits(uint256 newMaxPerDeposit, uint256 newMaxTotalDeposits) internal {
        emit MaxPerDepositUpdated(maxPerDeposit, newMaxPerDeposit);
        emit MaxTotalDepositsUpdated(maxTotalDeposits, newMaxTotalDeposits);
        require(
            newMaxPerDeposit <= newMaxTotalDeposits,
            "StrategyBaseTVLLimits._setTVLLimits: maxPerDeposit exceeds maxTotalDeposits"
        );
        maxPerDeposit = newMaxPerDeposit;
        maxTotalDeposits = newMaxTotalDeposits;
    }

    /**
     * @notice Called in the external `deposit` function, before any logic is executed. Makes sure that deposits don't exceed configured maximum.
     * @dev Unused token param is the token being deposited. This is already checked in the `deposit` function.
     * @dev Note that the `maxTotalDeposits` is purely checked against the current `_tokenBalance()`, since by this point in the deposit flow, the
     * tokens should have already been transferred to this Strategy by the StrategyManager
     * @dev We note as well that this makes it possible for various race conditions to occur:
     * a) multiple simultaneous calls to `deposit` may result in some of these calls reverting due to `maxTotalDeposits` being reached.
     * b) transferring funds directly to this Strategy (although not generally in someone's economic self interest) in order to reach `maxTotalDeposits`
     * is a route by which someone can cause calls to `deposit` to revert.
     * c) increases in the token balance of this contract through other effects – including token rebasing – may cause similar issues to (a) and (b).
     * @param amount The amount of `token` being deposited
     */
    function _beforeDeposit(IERC20 token, uint256 amount) internal virtual override {
        require(amount <= maxPerDeposit, "StrategyBaseTVLLimits: max per deposit exceeded");
        require(_tokenBalance() <= maxTotalDeposits, "StrategyBaseTVLLimits: max deposits exceeded");

        super._beforeDeposit(token, amount);
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[48] private __gap;

    function test() private pure {}
}
