// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import {IERC4626Vault} from "./IERC4626Vault.sol";
import {IMellowSymbioticVaultStorage} from "./IMellowSymbioticVaultStorage.sol";

import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {AccessManagerUpgradeable} from
    "@openzeppelin/contracts-upgradeable/access/manager/AccessManagerUpgradeable.sol";
import {
    ERC4626Upgradeable,
    IERC4626
} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import {ReentrancyGuardUpgradeable} from
    "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import {IVault as ISymbioticVault} from "@symbiotic/core/interfaces/vault/IVault.sol";
import {IStakerRewards} from "@symbiotic/rewards/interfaces/stakerRewards/IStakerRewards.sol";

interface IMellowSymbioticVault is IMellowSymbioticVaultStorage, IERC4626Vault {
    struct InitParams {
        uint256 limit;
        address symbioticVault;
        address withdrawalQueue;
        address admin;
        bool depositPause;
        bool withdrawalPause;
        bool depositWhitelist;
        string name;
        string symbol;
    }

    function initialize(InitParams memory initParams) external;

    function setFarm(uint256 farmId, FarmData memory farmData) external;

    function claimableAssetsOf(address account) external view returns (uint256 claimableAssets);

    function pendingAssetsOf(address account) external view returns (uint256 pendingAssets);

    function claim(address account, address recipient, uint256 maxAmount)
        external
        returns (uint256);

    function pushIntoSymbiotic() external returns (uint256 symbioticVaultStaked);

    function pushRewards(uint256 farmId, bytes calldata symbioticRewardsData) external;

    function getBalances(address account)
        external
        view
        returns (
            uint256 accountAssets,
            uint256 accountInstantAssets,
            uint256 accountShares,
            uint256 accountInstantShares
        );

    event RewardsPushed(
        uint256 indexed farmId, uint256 rewardAmount, uint256 curatorFee, uint256 timestamp
    );

    event SymbioticPushed(address sender, uint256 vaultAmount);
}
