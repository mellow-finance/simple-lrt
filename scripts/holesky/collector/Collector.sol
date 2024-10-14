// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

import "../../../src/interfaces/tokens/IWSTETH.sol";

import "../../../src/MellowSymbioticVault.sol";
import "./Oracle.sol";

contract Collector {
    struct WithdrawalData {
        uint256 pendingAssets;
        uint256 claimableAssets;
    }

    struct Response {
        address vault;
        uint256 balance; // Vault.balanceOf(user)
        address[] underlyingTokens; // deposit/withdrawal tokens
        uint256[] underlyingAmounts; // their amounts
        uint8[] underlyingTokenDecimals; // their decimals
        uint128[] depositRatiosX96; // ratiosX96 for deposits
        uint128[] withdrawalRatiosX96; // ratiosX96 for withdrawals
        uint256[] pricesX96; // pricesX96 for underlying tokens
        uint256 totalSupply; // total supply of the vault
        uint256 maximalTotalSupply; // limit of total supply of the vault
        uint256 userBalanceETH; // user vault balance in ETH
        uint256 userBalanceUSDC; // user vault balance in USDC
        uint256 totalValueETH; // total value of the vault in ETH
        uint256 totalValueUSDC; // total value of the vault in USDC
        uint256 totalValueWSTETH; // total value of the vault in WSTETH
        uint256 totalValueBaseToken; // total value of the vault in base token
        uint256 maximalTotalSupplyETH; // eth value for max limit total supply
        uint256 maximalTotalSupplyUSDC; // usdc value for max limit total supply
        uint256 maximalTotalSupplyWSTETH; // wsteth value for max limit total supply
        uint256 maximalTotalSupplyBaseToken; // base token value for max limit total supply
        uint256 lpPriceD18; // LP price in USDC weis 1e8 (due to chainlink decimals)
        uint256 lpPriceETHD18; // LP price in ETH weis 1e8 (due to chainlink decimals)
        uint256 lpPriceAssetD18; // LP price in asset weis 1e18 (due to chainlink decimals)
        uint256 lpPriceWSTETHD18; // LP price in WSTETH weis 1e8 (due to chainlink decimals)
        WithdrawalData withdrawalData; // withdrawal queue data
    }

    uint256 private constant Q96 = 2 ** 96;
    uint256 private constant D9 = 1e9;
    uint256 private constant D18 = 1e18;

    address public immutable wsteth;
    address public immutable weth;
    address public immutable steth;
    address public constant eth = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    Oracle public immutable oracle;

    constructor(address wsteth_, address weth_, address steth_, address oracle_) {
        wsteth = wsteth_;
        weth = weth_;
        steth = steth_;
        oracle = Oracle(oracle_);
    }

    function collect(address user, address vault_) public view returns (Response memory response) {
        MellowSymbioticVault vault = MellowSymbioticVault(vault_);
        response.vault = vault_;
        response.balance = vault.balanceOf(user);

        response.underlyingTokens = new address[](1);
        response.underlyingTokens[0] = vault.asset();

        response.underlyingAmounts = new uint256[](1);
        response.underlyingAmounts[0] = vault.totalAssets();

        response.underlyingTokenDecimals = new uint8[](1);
        response.underlyingTokenDecimals[0] =
            IERC20Metadata(response.underlyingTokens[0]).decimals();

        response.depositRatiosX96 = new uint128[](1);
        response.depositRatiosX96[0] = uint128(Q96);

        response.withdrawalRatiosX96 = new uint128[](1);
        response.withdrawalRatiosX96[0] = uint128(Q96);

        response.pricesX96 = new uint256[](1);
        response.pricesX96[0] = oracle.getEthPrice(vault.asset());

        response.totalSupply = vault.totalSupply();
        response.maximalTotalSupply = vault.convertToShares(vault.limit());
        response.maximalTotalSupplyETH =
            oracle.getEthValue(response.underlyingTokens[0], vault.limit());
        response.maximalTotalSupplyUSDC = oracle.getUsdValue(weth, response.maximalTotalSupplyETH);
        response.maximalTotalSupplyBaseToken = vault.limit();
        response.maximalTotalSupplyWSTETH =
            IWSTETH(wsteth).getWstETHByStETH(response.maximalTotalSupplyETH);

        response.userBalanceETH = oracle.getEthValue(
            response.underlyingTokens[0], vault.convertToAssets(vault.balanceOf(user))
        );
        response.userBalanceUSDC = oracle.getUsdValue(weth, response.userBalanceETH);
        response.totalValueETH =
            oracle.getEthValue(response.underlyingTokens[0], response.underlyingAmounts[0]);
        response.totalValueWSTETH = IWSTETH(wsteth).getWstETHByStETH(response.totalValueETH);
        response.totalValueUSDC = oracle.getUsdValue(weth, response.totalValueETH);
        response.totalValueBaseToken = vault.totalAssets();
        response.lpPriceD18 = Math.mulDiv(response.totalValueUSDC, D18, response.totalSupply);
        response.lpPriceETHD18 = Math.mulDiv(response.totalValueETH, D18, response.totalSupply);
        response.lpPriceAssetD18 =
            Math.mulDiv(response.totalValueBaseToken, D18, response.totalSupply);
        response.lpPriceWSTETHD18 =
            Math.mulDiv(response.totalValueWSTETH, D18, response.totalSupply);
        response.withdrawalData = WithdrawalData({
            pendingAssets: vault.pendingAssetsOf(user),
            claimableAssets: vault.claimableAssetsOf(user)
        });
    }

    function collect(address user, address[] memory vaults)
        public
        view
        returns (Response[] memory responses)
    {
        responses = new Response[](vaults.length);
        for (uint256 i = 0; i < vaults.length; i++) {
            responses[i] = collect(user, vaults[i]);
        }
    }

    function multiCollect(address[] memory users, address[] memory vaults)
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
        expectedAmounts[0] = MellowSymbioticVault(vault).previewRedeem(lpAmount);
        expectedAmountsUSDC[0] =
            oracle.getUsdValue(MellowSymbioticVault(vault).asset(), expectedAmounts[0]);
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
        if (MellowSymbioticVault(vault).depositPause()) {
            return (false, false, false, 0, 0);
        }
        isDepositPossible = true;
        if (
            MellowSymbioticVault(vault).depositWhitelist()
                && !MellowSymbioticVault(vault).isDepositorWhitelisted(user)
        ) {
            return (isDepositPossible, false, false, 0, 0);
        }
        isDepositorWhitelisted = true;

        if (MellowSymbioticVault(vault).asset() != wsteth) {
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
        lpAmount = MellowSymbioticVault(vault).previewDeposit(amount);
        depositValueUSDC = oracle.getUsdValue(wsteth, amount);
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

    function fetchDepositAmounts(uint256[] memory amounts, address vault, address user)
        external
        view
        returns (FetchDepositAmountsResponse memory r)
    {
        if (MellowSymbioticVault(vault).depositPause()) {
            return r;
        }
        r.isDepositPossible = true;
        if (
            MellowSymbioticVault(vault).depositWhitelist()
                && !MellowSymbioticVault(vault).isDepositorWhitelisted(user)
        ) {
            return r;
        }
        r.isDepositorWhitelisted = true;
        r.ratiosD18 = new uint256[](1);
        r.ratiosD18[0] = D18;
        r.tokens = new address[](1);
        r.tokens[0] = MellowSymbioticVault(vault).asset();
        r.expectedLpAmount = MellowSymbioticVault(vault).previewDeposit(amounts[0]);
        r.expectedLpAmountUSDC = oracle.getUsdValue(MellowSymbioticVault(vault).asset(), amounts[0]);
        r.expectedAmounts = new uint256[](1);
        r.expectedAmounts[0] = amounts[0];
        r.expectedAmountsUSDC = new uint256[](1);
        r.expectedAmountsUSDC[0] = r.expectedLpAmountUSDC;
    }
}
