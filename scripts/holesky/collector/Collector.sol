// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "../../../src/interfaces/queues/IEigenLayerWithdrawalQueue.sol";
import "../../../src/interfaces/queues/ISymbioticWithdrawalQueue.sol";

import "../../../src/interfaces/tokens/IWSTETH.sol";
import "../../../src/vaults/MultiVault.sol";
import "./Oracle.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

import "@openzeppelin/contracts/utils/Strings.sol";

contract Collector {
    struct Withdrawal {
        uint256 subvaultIndex;
        uint256 assets;
        bool isTimestamp;
        uint256 claimingTime; // if 0 - assets == claimable assets, otherwise = pending assets
        uint256 withdrawalIndex;
        uint256 withdrawalRequestType; // 0 - withdrawals, 1 - transferedWithdrawals
    }

    struct Response {
        address vault;
        address asset;
        uint8 assetDecimals;
        uint256 assetPriceX96;
        uint256 totalLP;
        uint256 totalUSD;
        uint256 totalETH;
        uint256 totalUnderlying;
        uint256 limitLP;
        uint256 limitUSD;
        uint256 limitETH;
        uint256 limitUnderlying;
        uint256 userLP;
        uint256 userETH;
        uint256 userUSD;
        uint256 userUnderlying;
        uint256 lpPriceUSD;
        uint256 lpPriceETH;
        uint256 lpPriceUnderlying;
        Withdrawal[] withdrawals;
        uint256 blockNumber;
        uint256 timestamp;
    }

    struct FetchDepositAmountsResponse {
        bool isDepositPossible;
        bool isDepositorWhitelisted;
        uint256[] ratiosD18; // multiplied by 1e18 for weis of underlying tokens
        address[] tokens;
        uint256 expectedLpAmount; // in lp weis 1e18
        uint256 expectedLpAmountUSDC; // in USDC weis 1e8 (due to chainlink decimals)
        uint256[] expectedAmounts; // in underlying tokens weis
        uint256[] expectedAmountsUSDC; // in USDC weis 1e8 (due to chainlink decimals)
    }

    uint256 private constant Q96 = 2 ** 96;
    uint256 private constant D9 = 1e9;
    uint256 private constant D18 = 1e18;

    address public constant eth = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address public immutable usd = address(bytes20(keccak256("usd-token-address")));
    address public immutable wsteth;
    address public immutable weth;
    address public immutable steth;
    address public owner;
    Oracle public oracle;

    modifier onlyOwner() {
        require(msg.sender == owner, "Collector: not owner");
        _;
    }

    constructor(address wsteth_, address weth_, address owner_) {
        wsteth = wsteth_;
        steth = address(IWSTETH(wsteth_).stETH());
        weth = weth_;
        owner = owner_;
    }

    function setOwner(address owner_) external onlyOwner {
        owner = owner_;
    }

    function setOracle(address oracle_) external onlyOwner {
        oracle = Oracle(oracle_);
    }

    function collect(address user, IERC4626 vault_) public view returns (Response memory r) {
        MultiVault vault = MultiVault(address(vault_));

        r.vault = address(vault_);
        r.asset = vault_.asset();
        r.assetDecimals = IERC20Metadata(r.asset).decimals();
        r.assetPriceX96 = oracle.priceX96(r.asset);

        r.totalLP = vault_.totalSupply();
        r.totalUnderlying = vault_.totalAssets();
        r.totalETH = oracle.getValue(r.asset, r.totalUnderlying);
        r.totalUSD = oracle.getValue(r.asset, usd, r.totalUnderlying);

        r.limitLP = vault.limit();
        r.limitUnderlying = vault.convertToAssets(r.limitLP);
        r.limitETH = oracle.getValue(r.asset, r.limitUnderlying);
        r.limitUSD = oracle.getValue(r.asset, usd, r.limitUnderlying);

        r.userLP = vault.balanceOf(user);
        r.userUnderlying = vault.convertToAssets(r.userLP);
        r.userETH = oracle.getValue(r.asset, r.userUnderlying);
        r.userUSD = oracle.getValue(r.asset, usd, r.userUnderlying);

        r.lpPriceUSD = Math.mulDiv(1 ether, r.totalUSD, r.totalLP);
        r.lpPriceETH = Math.mulDiv(1 ether, r.totalETH, r.totalLP);
        r.lpPriceUnderlying = Math.mulDiv(1 ether, r.totalUnderlying, r.totalLP);

        Withdrawal[] memory withdrawals = new Withdrawal[](vault.subvaultsCount() * 50);
        uint256 iterator = 0;
        uint256 subvaultsCount = vault.subvaultsCount();
        IMultiVaultStorage.Subvault memory subvault;
        for (uint256 subvaultIndex = 0; subvaultIndex < subvaultsCount; subvaultIndex++) {
            subvault = vault.subvaultAt(subvaultIndex);
            if (subvault.withdrawalQueue == address(0)) {
                continue;
            }

            IWithdrawalQueue queue = IWithdrawalQueue(subvault.withdrawalQueue);

            {
                uint256 claimable = queue.claimableAssetsOf(user);
                if (claimable != 0) {
                    withdrawals[iterator++] = Withdrawal({
                        subvaultIndex: subvaultIndex,
                        assets: claimable,
                        isTimestamp: true,
                        claimingTime: 0,
                        withdrawalIndex: 0,
                        withdrawalRequestType: 0
                    });
                }
            }

            if (queue.pendingAssetsOf(user) == 0) {
                continue;
            }

            if (subvault.protocol == IMultiVaultStorage.Protocol.SYMBIOTIC) {
                Withdrawal[] memory w = collectSymbioticWithdrawals(
                    user, subvaultIndex, ISymbioticWithdrawalQueue(subvault.withdrawalQueue)
                );
                for (uint256 i = 0; i < w.length; i++) {
                    withdrawals[iterator++] = w[i];
                }
            } else if (subvault.protocol == IMultiVaultStorage.Protocol.EIGEN_LAYER) {
                Withdrawal[] memory w = collectEigenLayerWithdrawals(
                    user, subvaultIndex, IEigenLayerWithdrawalQueue(subvault.withdrawalQueue)
                );
                for (uint256 i = 0; i < w.length; i++) {
                    withdrawals[iterator++] = w[i];
                }
            } else {
                revert("Invalid state");
            }
        }

        assembly {
            mstore(withdrawals, iterator)
        }
        r.withdrawals = withdrawals;
        r.blockNumber = block.number;
        r.timestamp = block.timestamp;
    }

    struct CollectEigenLayerWithdrawalsStack {
        uint256[] withdrawals;
        uint256[] transferredWithdrawals;
        uint256 block_;
        IStrategy strategy;
    }

    function collectSymbioticWithdrawals(
        address user,
        uint256 subvaultIndex,
        ISymbioticWithdrawalQueue q
    ) public view returns (Withdrawal[] memory withdrawals_) {
        withdrawals_ = new Withdrawal[](2);
        uint256 iterator = 0;
        (uint256 sharesToClaimPrev, uint256 sharesToClaim,, uint256 claimEpoch) =
            q.getAccountData(user);
        ISymbioticVault symbioticVault = q.symbioticVault();
        uint256 currentEpoch = q.getCurrentEpoch();
        if (claimEpoch == currentEpoch + 1) {
            if (sharesToClaimPrev != 0) {
                ISymbioticWithdrawalQueue.EpochData memory epochData = q.getEpochData(currentEpoch);
                uint256 assets = Math.mulDiv(
                    symbioticVault.withdrawalsOf(currentEpoch, address(q)),
                    sharesToClaimPrev,
                    epochData.sharesToClaim
                );
                if (assets != 0) {
                    withdrawals_[iterator++] = Withdrawal({
                        subvaultIndex: subvaultIndex,
                        assets: assets,
                        isTimestamp: true,
                        claimingTime: symbioticVault.currentEpochStart()
                            + symbioticVault.epochDuration(),
                        withdrawalIndex: 0,
                        withdrawalRequestType: 0
                    });
                }
            }
            if (sharesToClaim != 0) {
                ISymbioticWithdrawalQueue.EpochData memory epochData =
                    q.getEpochData(currentEpoch + 1);
                uint256 assets = Math.mulDiv(
                    symbioticVault.withdrawalsOf(currentEpoch + 1, address(q)),
                    sharesToClaim,
                    epochData.sharesToClaim
                );
                if (assets != 0) {
                    withdrawals_[iterator++] = Withdrawal({
                        subvaultIndex: subvaultIndex,
                        assets: assets,
                        isTimestamp: true,
                        claimingTime: symbioticVault.currentEpochStart()
                            + 2 * symbioticVault.epochDuration(),
                        withdrawalIndex: 0,
                        withdrawalRequestType: 0
                    });
                }
            }
        } else if (claimEpoch == currentEpoch) {
            if (sharesToClaim != 0) {
                ISymbioticWithdrawalQueue.EpochData memory epochData = q.getEpochData(currentEpoch);
                uint256 assets = Math.mulDiv(
                    symbioticVault.withdrawalsOf(currentEpoch, address(q)),
                    sharesToClaim,
                    epochData.sharesToClaim
                );
                if (assets != 0) {
                    withdrawals_[iterator++] = Withdrawal({
                        subvaultIndex: subvaultIndex,
                        assets: assets,
                        isTimestamp: true,
                        claimingTime: symbioticVault.currentEpochStart()
                            + 2 * symbioticVault.epochDuration(),
                        withdrawalIndex: 0,
                        withdrawalRequestType: 0
                    });
                }
            }
        }
        assembly {
            mstore(withdrawals_, iterator)
        }
    }

    function collectEigenLayerWithdrawals(
        address user,
        uint256 subvaultIndex,
        IEigenLayerWithdrawalQueue queue
    ) public view returns (Withdrawal[] memory withdrawals_) {
        CollectEigenLayerWithdrawalsStack memory s;
        s.strategy = IStrategy(queue.strategy());
        (, s.withdrawals, s.transferredWithdrawals) =
            queue.getAccountData(user, type(uint256).max, 0, type(uint256).max, 0);
        s.block_ = queue.latestWithdrawableBlock();
        uint256 counter = 0;
        withdrawals_ = new Withdrawal[](s.withdrawals.length + s.transferredWithdrawals.length);
        uint256 n = 0;
        for (uint256 i = 0; i < s.withdrawals.length; i++) {
            (IDelegationManager.Withdrawal memory data, bool isClaimed,,, uint256 accountShares) =
                queue.getWithdrawalRequest(s.withdrawals[i], user);
            if (isClaimed) {
                continue;
            } else if (s.block_ >= data.startBlock && counter < queue.MAX_CLAIMING_WITHDRAWALS()) {
                counter++;
            } else {
                withdrawals_[n++] = Withdrawal({
                    subvaultIndex: subvaultIndex,
                    assets: s.strategy.sharesToUnderlyingView(accountShares),
                    isTimestamp: false,
                    claimingTime: data.startBlock + block.number - s.block_,
                    withdrawalIndex: s.withdrawals[i],
                    withdrawalRequestType: 0
                });
            }
        }

        for (uint256 i = 0; i < s.transferredWithdrawals.length; i++) {
            (
                IDelegationManager.Withdrawal memory data,
                bool isClaimed,
                uint256 assets,
                uint256 shares,
                uint256 accountShares
            ) = queue.getWithdrawalRequest(s.transferredWithdrawals[i], user);
            if (isClaimed) {
                withdrawals_[n++] = Withdrawal({
                    subvaultIndex: subvaultIndex,
                    assets: Math.mulDiv(assets, accountShares, shares),
                    isTimestamp: false,
                    claimingTime: 0,
                    withdrawalIndex: s.transferredWithdrawals[i],
                    withdrawalRequestType: 1
                });
            } else {
                withdrawals_[n++] = Withdrawal({
                    subvaultIndex: subvaultIndex,
                    assets: s.strategy.sharesToUnderlyingView(accountShares),
                    isTimestamp: false,
                    claimingTime: data.startBlock + block.number - s.block_,
                    withdrawalIndex: s.transferredWithdrawals[i],
                    withdrawalRequestType: 1
                });
            }
        }

        assembly {
            mstore(withdrawals_, n)
        }
    }

    function collect(address user, address[] memory vaults)
        public
        view
        returns (Response[] memory responses)
    {
        responses = new Response[](vaults.length);
        for (uint256 i = 0; i < vaults.length; i++) {
            responses[i] = collect(user, IERC4626(vaults[i]));
        }
    }

    function multiCollect(address[] calldata users, address[] calldata vaults)
        external
        view
        returns (Response[][] memory responses)
    {
        responses = new Response[][](users.length);
        for (uint256 i = 0; i < users.length; i++) {
            responses[i] = collect(users[i], vaults);
        }
    }

    function fetchWithdrawalAmounts(uint256 lpAmount, address vault)
        external
        view
        returns (uint256[] memory expectedAmounts, uint256[] memory expectedAmountsUSDC)
    {
        expectedAmounts = new uint256[](1);
        expectedAmountsUSDC = new uint256[](1);
        expectedAmounts[0] = IERC4626(vault).previewRedeem(lpAmount);
        expectedAmountsUSDC[0] = oracle.getValue(IERC4626(vault).asset(), usd, expectedAmounts[0]);
    }

    function fetchDepositWrapperParams(address vault, address user, address token, uint256 amount)
        external
        view
        returns (
            bool isDepositPossible,
            bool isDepositorWhitelisted,
            bool isWhitelistedToken,
            uint256 lpAmount,
            uint256 depositValueUSDC
        )
    {
        if (MultiVault(vault).depositPause()) {
            return (false, false, false, 0, 0);
        }
        isDepositPossible = true;
        if (MultiVault(vault).depositWhitelist() && !MultiVault(vault).isDepositorWhitelisted(user))
        {
            return (isDepositPossible, false, false, 0, 0);
        }
        isDepositorWhitelisted = true;

        if (MultiVault(vault).asset() != wsteth) {
            return (isDepositPossible, isDepositorWhitelisted, false, 0, 0);
        }
        if (token == weth || token == steth || token == wsteth || token == eth) {
            isWhitelistedToken = true;
        } else {
            return (isDepositPossible, isDepositorWhitelisted, false, 0, 0);
        }
        if (token != wsteth) {
            amount = IWSTETH(wsteth).getWstETHByStETH(amount);
        }
        lpAmount = MultiVault(vault).previewDeposit(amount);
        depositValueUSDC = oracle.getValue(wsteth, usd, amount);
    }

    function fetchDepositAmounts(uint256[] memory amounts, address vault, address user)
        external
        view
        returns (FetchDepositAmountsResponse memory r)
    {
        if (MultiVault(vault).depositPause()) {
            return r;
        }
        r.isDepositPossible = true;
        if (MultiVault(vault).depositWhitelist() && !MultiVault(vault).isDepositorWhitelisted(user))
        {
            return r;
        }
        r.isDepositorWhitelisted = true;
        r.ratiosD18 = new uint256[](1);
        r.ratiosD18[0] = D18;
        r.tokens = new address[](1);
        r.tokens[0] = MultiVault(vault).asset();
        r.expectedLpAmount = MultiVault(vault).previewDeposit(amounts[0]);
        r.expectedLpAmountUSDC = oracle.getValue(MultiVault(vault).asset(), usd, amounts[0]);
        r.expectedAmounts = new uint256[](1);
        r.expectedAmounts[0] = amounts[0];
        r.expectedAmountsUSDC = new uint256[](1);
        r.expectedAmountsUSDC[0] = r.expectedLpAmountUSDC;
    }

    struct EigenStack {
        uint256 block_;
        uint256 counter;
        uint256[] withdrawals;
        IStrategy strategy;
        uint256 length;
        IDelegationManager.Withdrawal data;
        bool isClaimed;
        uint256 assets;
        uint256 requestShares;
        uint256 accountShares;
    }

    function getVaultAssets(MultiVault v, address user, uint256 shares)
        public
        view
        returns (
            uint256 accountAssets,
            uint256 accountInstantAssets,
            Withdrawal[] memory withdrawals
        )
    {
        IWithdrawalStrategy.WithdrawalData[] memory data = v.withdrawalStrategy()
            .calculateWithdrawalAmounts(
            address(v), v.previewRedeem(shares == 0 ? v.balanceOf(user) : shares)
        );
        withdrawals = new Withdrawal[](data.length * 50 + 1);
        uint256 n = 0;
        for (uint256 i = 0; i < data.length; i++) {
            accountInstantAssets += data[i].claimable;
            accountAssets += data[i].pending + data[i].staked;
            IMultiVaultStorage.Subvault memory subvault = v.subvaultAt(data[i].subvaultIndex);
            if (subvault.withdrawalQueue == address(0)) {
                continue;
            }

            if (data[i].pending != 0) {
                if (subvault.protocol == IMultiVaultStorage.Protocol.SYMBIOTIC) {
                    ISymbioticWithdrawalQueue queue =
                        ISymbioticWithdrawalQueue(subvault.withdrawalQueue);
                    (, uint256 sharesToClaim,, uint256 claimEpoch) =
                        queue.getAccountData(address(v));
                    ISymbioticVault symbioticVault = queue.symbioticVault();
                    uint256 currentEpoch = symbioticVault.currentEpoch();
                    if (claimEpoch == currentEpoch + 1) {
                        if (sharesToClaim != 0) {
                            ISymbioticWithdrawalQueue.EpochData memory epochData =
                                queue.getEpochData(currentEpoch + 1);
                            uint256 assets = Math.mulDiv(
                                symbioticVault.withdrawalsOf(currentEpoch + 1, address(queue)),
                                sharesToClaim,
                                epochData.sharesToClaim
                            );
                            if (assets != 0) {
                                assets = Math.min(assets, data[i].pending);
                                data[i].pending -= assets;
                                withdrawals[n++] = Withdrawal({
                                    subvaultIndex: data[i].subvaultIndex,
                                    assets: assets,
                                    isTimestamp: true,
                                    claimingTime: symbioticVault.currentEpochStart()
                                        + 2 * symbioticVault.epochDuration(),
                                    withdrawalIndex: 0,
                                    withdrawalRequestType: 0
                                });
                            }
                        }
                        if (data[i].pending != 0) {
                            withdrawals[n++] = Withdrawal({
                                subvaultIndex: data[i].subvaultIndex,
                                assets: data[i].pending,
                                isTimestamp: true,
                                claimingTime: symbioticVault.currentEpochStart()
                                    + symbioticVault.epochDuration(),
                                withdrawalIndex: 0,
                                withdrawalRequestType: 0
                            });
                        }
                    } else if (claimEpoch == currentEpoch) {
                        withdrawals[n++] = Withdrawal({
                            subvaultIndex: data[i].subvaultIndex,
                            assets: data[i].pending,
                            isTimestamp: true,
                            claimingTime: symbioticVault.currentEpochStart()
                                + symbioticVault.epochDuration(),
                            withdrawalIndex: 0,
                            withdrawalRequestType: 0
                        });
                    } else {
                        revert("Invalid state!");
                    }
                } else if (subvault.protocol == IMultiVaultStorage.Protocol.EIGEN_LAYER) {
                    EigenStack memory s;
                    IEigenLayerWithdrawalQueue queue =
                        IEigenLayerWithdrawalQueue(subvault.withdrawalQueue);
                    (, s.withdrawals,) =
                        queue.getAccountData(address(v), type(uint256).max, 0, 0, 0);
                    s.length = s.withdrawals.length;
                    s.counter = 0;
                    s.block_ = queue.latestWithdrawableBlock();
                    s.strategy = IStrategy(queue.strategy());

                    for (uint256 index = 0; index < s.length;) {
                        (s.data, s.isClaimed,,,) =
                            queue.getWithdrawalRequest(s.withdrawals[index], address(v));
                        if (s.isClaimed) {
                            s.withdrawals[index] = s.withdrawals[--s.length];
                        } else if (
                            s.data.startBlock <= s.block_
                                && s.counter < queue.MAX_CLAIMING_WITHDRAWALS()
                        ) {
                            s.counter++;
                            s.withdrawals[index] = s.withdrawals[--s.length];
                        } else {
                            index++;
                        }
                    }

                    for (uint256 index = 0; index < s.length;) {
                        (s.data, s.isClaimed, s.assets, s.requestShares, s.accountShares) =
                            queue.getWithdrawalRequest(s.withdrawals[index], address(v));
                        uint256 transferrableAssets = s.isClaimed
                            ? Math.mulDiv(s.assets, s.accountShares, s.requestShares)
                            : s.strategy.sharesToUnderlyingView(s.accountShares);
                        if (transferrableAssets == 0) {
                            index++;
                            continue;
                        }
                        if (transferrableAssets >= data[i].pending) {
                            withdrawals[n++] = Withdrawal({
                                subvaultIndex: data[i].subvaultIndex,
                                assets: data[i].pending,
                                isTimestamp: false,
                                claimingTime: s.data.startBlock + block.number - s.block_,
                                withdrawalIndex: s.withdrawals[index],
                                withdrawalRequestType: 1
                            });
                            data[i].pending = 0;
                            break;
                        } else {
                            withdrawals[n++] = Withdrawal({
                                subvaultIndex: data[i].subvaultIndex,
                                assets: transferrableAssets,
                                isTimestamp: false,
                                claimingTime: s.data.startBlock + block.number - s.block_,
                                withdrawalIndex: s.withdrawals[index],
                                withdrawalRequestType: 1
                            });
                            data[i].pending -= transferrableAssets;
                            s.withdrawals[index] = s.withdrawals[--s.length];
                        }
                    }
                    if (data[i].pending != 0) {
                        withdrawals[n++] = Withdrawal({
                            subvaultIndex: data[i].subvaultIndex,
                            assets: data[i].pending,
                            isTimestamp: false,
                            claimingTime: 0,
                            withdrawalIndex: 0,
                            withdrawalRequestType: 0
                        });
                    }
                } else {
                    revert("Unsupported protocol");
                }
            }

            if (data[i].staked != 0) {
                // regular unstaking
                if (subvault.protocol == IMultiVaultStorage.Protocol.SYMBIOTIC) {
                    ISymbioticVault symbioticVault = ISymbioticVault(subvault.vault);
                    withdrawals[n++] = Withdrawal({
                        subvaultIndex: data[i].subvaultIndex,
                        assets: data[i].staked,
                        isTimestamp: true,
                        claimingTime: symbioticVault.currentEpochStart()
                            + 2 * symbioticVault.epochDuration(),
                        withdrawalIndex: 0,
                        withdrawalRequestType: 0
                    });
                } else if (subvault.protocol == IMultiVaultStorage.Protocol.EIGEN_LAYER) {
                    IEigenLayerWithdrawalQueue queue =
                        IEigenLayerWithdrawalQueue(subvault.withdrawalQueue);
                    withdrawals[n++] = Withdrawal({
                        subvaultIndex: data[i].subvaultIndex,
                        assets: data[i].staked,
                        isTimestamp: false,
                        claimingTime: block.number + block.number - queue.latestWithdrawableBlock(),
                        withdrawalIndex: queue.withdrawalRequests(),
                        withdrawalRequestType: 0
                    });
                } else {
                    revert("Unsupported protocol");
                }
            }
        }

        assembly {
            mstore(withdrawals, n)
        }

        accountAssets += accountInstantAssets;
    }
}
