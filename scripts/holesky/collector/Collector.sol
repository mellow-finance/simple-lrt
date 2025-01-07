// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "../../../src/interfaces/queues/ISymbioticWithdrawalQueue.sol";
import "../../../src/interfaces/vaults/IMultiVault.sol";
import "./Oracle.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

contract Collector {
    struct Withdrawal {
        uint256 subvaultIndex;
        uint256 assets;
        uint256 claimingTime; // if 0 - assets == claimable assets, otherwise = pending assets
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
    address public constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    address public immutable WSTETH;
    address public immutable WETH;
    address public immutable STETH;
    address public owner;
    Oracle public oracle;

    modifier onlyOwner() {
        require(msg.sender == owner, "Collector: not owner");
        _;
    }

    constructor(address wsteth_, address weth_, address steth_, address owner_) {
        WSTETH = wsteth_;
        WETH = weth_;
        STETH = steth_;
        owner = owner_;
    }

    function setOwner(address owner_) external onlyOwner {
        owner = owner_;
    }

    function collect(address user, IERC4626 vault_) public view returns (Response memory r) {
        IMultiVault vault = IMultiVault(address(vault_));

        r.vault = address(vault_);
        r.asset = vault_.asset();
        r.assetDecimals = IERC20Metadata(r.asset).decimals();
        r.assetPriceX96 = oracle.priceX96(r.asset);

        r.totalLP = vault_.totalSupply();
        r.totalUnderlying = vault_.totalAssets();
        r.totalETH = oracle.getValue(r.asset, r.totalUnderlying);
        r.totalUSD = oracle.getUsdValue(r.asset, USD, r.totalUnderlying);

        r.limitLP = vault.isDepositLimit() ? vault.depositLimit() : type(uint256).max;
        r.limitUnderlying = vault.convertToAssets(r.limitLP);
        r.limitETH = oracle.getValue(r.asset, r.limitUnderlying);
        r.limitUSD = oracle.getUsdValue(r.asset, USD, r.limitUnderlying);

        r.userLP = vault.balanceOf(user);
        r.userUnderlying = vault.convertToAssets(r.userLP);
        r.userETH = oracle.getValue(r.asset, r.userUnderlying);
        r.userUSD = oracle.getUsdValue(r.asset, USD, r.userUnderlying);

        r.lpPriceUSD = Math.mulDiv(1 ether, r.totalUSD, r.totalLP);
        r.lpPriceETH = Math.mulDiv(1 ether, r.totalETH, r.totalLP);
        r.lpPriceUnderlying = Math.mulDiv(1 ether, r.totalUnderlying, r.totalLP);

        withdrawals = new Withdrawal[](vault.subvaultsCount() * 50);
        uint256 iterator = 0;
        uint256 counter = 0;
        uint256 subvaultsCount = vault.subvaultsCount();
        IMultiVaultStorage.Subvault memory subvault;
        for (uint256 subvaultIndex = 0; subvaultIndex < subvaultsCount; subvaultIndex++) {
            subvault = vault.subvaultAt(subvaultIndex);
            if (subvault.withdrawalQueue == address(0)) {
                continue;
            }

            IWithdrawalQueue queue = IWithdrawalQueue(subvault.withdrawalQueue);
            uint256 pending = queue.pendingAssetsOf(user);
            uint256 claimable = queue.claimableAssetsOf(user);

            if (claimable != 0) {
                withdrawals[iterator++] =
                    Withdrawal({subvaultIndex: subvaultIndex, assets: claimable, claimingTime: 0});
            }

            if (pending == 0) {
                continue;
            }

            Withdrawal memory withdrawal = Withdrawal({
                subvaultIndex: subvaultIndex,
                assets: pending + claimable,
                claimingTime: pending == 0 ? 0 : queue.claimingTimeOf(user)
            });

            if (subvault.protocol == IMultiVault.Protocol.SYMBIOTIC) {
                ISymbioticWithdrawalQueue q = ISymbioticWithdrawalQueue(subvault.withdrawalQueue);
                (
                    uint256 sharesToClaimPrev,
                    uint256 sharesToClaim,
                    uint256 claimableAssets,
                    uint256 claimEpoch
                ) = q.getAccountData(user);
                ISymbioticVault symbioticVault = q.symbioticVault();
                if (sharesToClaimPrev != 0) {
                    uint256 assets = q.getEpochData(epoch);
                }
            } else if (subvault.protocol == IMultiVault.Protocol.EIGEN_LAYER) {} else {
                revert("Invalid state");
            }
        }

        assembly {
            mstore(withdrawals, iterator)
        }
        r.withdrawals = withdrawals;
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

    // function fetchWithdrawalAmounts(uint256 lpAmount, address vault)
    //     external
    //     view
    //     returns (uint256[] memory expectedAmounts, uint256[] memory expectedAmountsUSDC)
    // {
    //     expectedAmounts = new uint256[](1);
    //     expectedAmountsUSDC = new uint256[](1);
    //     expectedAmounts[0] = MellowSymbioticVault(vault).previewRedeem(lpAmount);
    //     expectedAmountsUSDC[0] =
    //         oracle.getUsdValue(MellowSymbioticVault(vault).asset(), expectedAmounts[0]);
    // }

    // function fetchDepositWrapperParams(address vault, address user, address token, uint256 amount)
    //     external
    //     view
    //     returns (
    //         bool isDepositPossible,
    //         bool isDepositorWhitelisted,
    //         bool isWhitelistedToken,
    //         uint256 lpAmount,
    //         uint256 depositValueUSDC
    //     )
    // {
    //     if (MellowSymbioticVault(vault).depositPause()) {
    //         return (false, false, false, 0, 0);
    //     }
    //     isDepositPossible = true;
    //     if (
    //         MellowSymbioticVault(vault).depositWhitelist()
    //             && !MellowSymbioticVault(vault).isDepositorWhitelisted(user)
    //     ) {
    //         return (isDepositPossible, false, false, 0, 0);
    //     }
    //     isDepositorWhitelisted = true;

    //     if (MellowSymbioticVault(vault).asset() != wsteth) {
    //         return (isDepositPossible, isDepositorWhitelisted, false, 0, 0);
    //     }
    //     if (token == weth || token == steth || token == wsteth || token == eth) {
    //         isWhitelistedToken = true;
    //     } else {
    //         return (isDepositPossible, isDepositorWhitelisted, false, 0, 0);
    //     }
    //     if (token != wsteth) {
    //         amount = IWSTETH(wsteth).getWstETHByStETH(amount);
    //     }
    //     lpAmount = MellowSymbioticVault(vault).previewDeposit(amount);
    //     depositValueUSDC = oracle.getUsdValue(wsteth, amount);
    // }

    // function fetchDepositAmounts(uint256[] memory amounts, address vault, address user)
    //     external
    //     view
    //     returns (FetchDepositAmountsResponse memory r)
    // {
    //     if (MellowSymbioticVault(vault).depositPause()) {
    //         return r;
    //     }
    //     r.isDepositPossible = true;
    //     if (
    //         MellowSymbioticVault(vault).depositWhitelist()
    //             && !MellowSymbioticVault(vault).isDepositorWhitelisted(user)
    //     ) {
    //         return r;
    //     }
    //     r.isDepositorWhitelisted = true;
    //     r.ratiosD18 = new uint256[](1);
    //     r.ratiosD18[0] = D18;
    //     r.tokens = new address[](1);
    //     r.tokens[0] = MellowSymbioticVault(vault).asset();
    //     r.expectedLpAmount = MellowSymbioticVault(vault).previewDeposit(amounts[0]);
    //     r.expectedLpAmountUSDC = oracle.getUsdValue(MellowSymbioticVault(vault).asset(), amounts[0]);
    //     r.expectedAmounts = new uint256[](1);
    //     r.expectedAmounts[0] = amounts[0];
    //     r.expectedAmountsUSDC = new uint256[](1);
    //     r.expectedAmountsUSDC[0] = r.expectedLpAmountUSDC;
    // }
}
