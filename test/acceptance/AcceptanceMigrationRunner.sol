// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "forge-std/Base.sol";
import "forge-std/console2.sol";

import "../../scripts/mainnet/MigrationDeploy.sol";

contract AcceptanceMigrationRunner is CommonBase {
    uint256 private constant Q96 = 2 ** 96;

    struct TestParams {
        bool isDuringDeployment;
    }

    /*    
        MellowVaultCompat view functions:
        function allowance(address owner, address spender);
        function balanceOf(address account);
        function totalSupply();
        function compatTotalSupply() external view returns (uint256);

        MellowSymbioticVault view functions:
        function totalAssets(),
        function claimableAssetsOf(address account) external view returns (uint256 claimableAssets);
        function pendingAssetsOf(address account) external view returns (uint256 pendingAssets);
        function getBalances(address account);

        MellowSymbioticVaultStorage view functions:
        function symbioticVault() public view returns (ISymbioticVault);
        function symbioticCollateral() public view returns (IDefaultCollateral);
        function withdrawalQueue() public view returns (IWithdrawalQueue);
        function symbioticFarmIds() public view returns (uint256[] memory);
        function symbioticFarmCount() public view returns (uint256);
        function symbioticFarmIdAt(uint256 index) public view returns (uint256);
        function symbioticFarmsContains(uint256 farmId) public view returns (bool);
        function symbioticFarm(uint256 farmId) public view returns (FarmData memory);

        ERC4626Vault view functions:
        function maxMint(address account);
        function maxDeposit(address account);
        function maxWithdraw(address account);
        function maxRedeem(address account);

        VaultControlStorage view functions:
        function depositPause() public view returns (bool);
        function withdrawalPause() public view returns (bool);
        function limit() public view returns (uint256);
        function depositWhitelist() public view returns (bool);
        function isDepositorWhitelisted(address account) public view returns (bool);

        AccessControlEnumerableUpgradeable view functions:
        function getRoleMember(bytes32 role, uint256 index) public view virtual returns (address);
        function getRoleMemberCount(bytes32 role) public view virtual returns (uint256);
        function hasRole(bytes32 role, address account) public view virtual returns (bool);
        function getRoleAdmin(bytes32 role) public view virtual returns (bytes32);

        ERC4626Upgradeable view functions:
        function decimals() public view virtual override(IERC20Metadata, ERC20Upgradeable) returns (uint8);
        function asset() public view virtual returns (address);
        function convertToShares(uint256 assets) public view virtual returns (uint256);
        function convertToAssets(uint256 shares) public view virtual returns (uint256);
        function previewDeposit(uint256 assets) public view virtual returns (uint256);
        function previewMint(uint256 shares) public view virtual returns (uint256);
        function previewWithdraw(uint256 assets) public view virtual returns (uint256);
        function previewRedeem(uint256 shares) public view virtual returns (uint256);
    */

    function runAcceptance(
        MellowVaultCompat vault,
        MigrationDeploy.MigrationDeployParams memory deployParams,
        TestParams memory testParams
    ) public view {
        runMellowVaultCompatTest(vault, deployParams, testParams);
        runMellowSymbioticVaultTest(vault, deployParams, testParams);
        runMellowSymbioticVaultStorageTest(vault, deployParams, testParams);
        runERC4626VaultTest(vault, deployParams, testParams);
        runVaultControlStorageTest(vault, deployParams, testParams);
        runAccessControlEnumerableUpgradeableTest(vault, deployParams, testParams);
        runERC4626UpgradeableTest(vault, deployParams, testParams);

        runPermissionsTest(vault, deployParams, testParams);
        runValuesTest(vault, deployParams, testParams);
    }

    function runMellowVaultCompatTest(
        MellowVaultCompat vault,
        MigrationDeploy.MigrationDeployParams memory deployParams,
        TestParams memory testParams
    ) public view {
        // function allowance(address owner, address spender);
        // function balanceOf(address account);
        // function totalSupply();
        // function compatTotalSupply() external view returns (uint256);

        require(
            vault.allowance(address(vault), address(vault)) == 0,
            "runMellowVaultCompatTest: Allowance should be 0"
        );

        require(
            vault.balanceOf(address(vault)) != 0,
            "runMellowVaultCompatTest: Vault balance should not be 0"
        );

        require(
            vault.balanceOf(address(vault)) <= vault.totalSupply(),
            "runMellowVaultCompatTest: Vault balance should be less than or equal to totalSupply"
        );

        if (testParams.isDuringDeployment) {
            require(
                vault.compatTotalSupply() == vault.totalSupply(),
                "runMellowVaultCompatTest: compatTotalSupply should be equal to totalSupply"
            );
        } else {
            require(
                vault.compatTotalSupply() <= vault.totalSupply(),
                "runMellowVaultCompatTest: compatTotalSupply should be less than or equal to totalSupply"
            );
        }
    }

    function runMellowSymbioticVaultTest(
        MellowVaultCompat vault,
        MigrationDeploy.MigrationDeployParams memory deployParams,
        TestParams memory testParams
    ) public view {
        require(
            vault.totalAssets() != 0, "runMellowSymbioticVaultTest: Total assets should not be 0"
        );

        address asset = vault.asset();
        IDefaultCollateral collateral = vault.symbioticCollateral();
        ISymbioticVault symbioticVault = vault.symbioticVault();

        {
            uint256 instantValue = IERC20(asset).balanceOf(address(vault))
                + collateral.balanceOf(address(vault)) + symbioticVault.activeBalanceOf(address(vault));
            require(
                vault.totalAssets() == instantValue,
                "runMellowSymbioticVaultTest: Total assets should be equal to the sum of balances"
            );
        }

        require(
            vault.claimableAssetsOf(address(vault)) == 0,
            "runMellowSymbioticVaultTest: Claimable assets of vault should be 0"
        );

        require(
            vault.claimableAssetsOf(address(deployParams.symbioticVault)) == 0,
            "runMellowSymbioticVaultTest: Claimable assets of symbiotic vault should be 0"
        );

        require(
            vault.claimableAssetsOf(address(deployParams.migrator)) == 0,
            "runMellowSymbioticVaultTest: Claimable assets of migrator vault should be 0"
        );

        require(
            vault.pendingAssetsOf(address(vault)) == 0,
            "runMellowSymbioticVaultTest: Pending assets of vault should be 0"
        );

        require(
            vault.pendingAssetsOf(address(deployParams.symbioticVault)) == 0,
            "runMellowSymbioticVaultTest: Pending assets of symbiotic vault should be 0"
        );

        require(
            vault.pendingAssetsOf(address(deployParams.migrator)) == 0,
            "runMellowSymbioticVaultTest: Pending assets of migrator vault should be 0"
        );

        (
            uint256 accountAssets,
            uint256 accountInstantAssets,
            uint256 accountShares,
            uint256 accountInstantShares
        ) = vault.getBalances(address(vault));

        uint256 assetBalance = IERC20(asset).balanceOf(address(vault));
        uint256 collateralBalance = collateral.balanceOf(address(vault));
        uint256 symbioticBalance = symbioticVault.activeBalanceOf(address(vault));

        uint256 totalSupply = vault.totalSupply();

        require(
            accountShares == vault.balanceOf(address(vault)),
            "runMellowSymbioticVaultTest: Account shares should be equal to vault balance"
        );

        uint256 expectedAccountAssets = Math.mulDiv(
            accountShares, assetBalance + collateralBalance + symbioticBalance, totalSupply
        );

        require(
            accountAssets == expectedAccountAssets,
            "runMellowSymbioticVaultTest: Account assets should be calculated correctly"
        );

        require(
            accountInstantAssets
                == Math.min(expectedAccountAssets, assetBalance + collateralBalance),
            "runMellowSymbioticVaultTest: Account instant assets should be equal to asset balance"
        );

        require(
            accountInstantShares
                == Math.min(
                    accountShares,
                    Math.mulDiv(
                        totalSupply,
                        assetBalance + collateralBalance,
                        assetBalance + collateralBalance + symbioticBalance
                    )
                ),
            "runMellowSymbioticVaultTest: Account instant shares should be equal to vault balance"
        );
    }

    function runMellowSymbioticVaultStorageTest(
        MellowVaultCompat vault,
        MigrationDeploy.MigrationDeployParams memory deployParams,
        TestParams memory testParams
    ) public view {
        // function symbioticVault() public view returns (ISymbioticVault);
        // function symbioticCollateral() public view returns (IDefaultCollateral);
        // function withdrawalQueue() public view returns (IWithdrawalQueue);
        // function symbioticFarmIds() public view returns (uint256[] memory);
        // function symbioticFarmCount() public view returns (uint256);
        // function symbioticFarmIdAt(uint256 index) public view returns (uint256);
        // function symbioticFarmsContains(uint256 farmId) public view returns (bool);
        // function symbioticFarm(uint256 farmId) public view returns (FarmData memory);

        require(
            address(vault.symbioticVault()) == deployParams.symbioticVault
                && deployParams.symbioticVault != address(0),
            "runMellowSymbioticVaultStorageTest: Symbiotic vault address should be set correctly"
        );

        require(
            ISymbioticVault(deployParams.symbioticVault).collateral() == vault.asset(),
            "runMellowSymbioticVaultStorageTest: Symbiotic vault collateral should be set correctly"
        );

        require(
            address(vault.symbioticCollateral()) != address(0)
                && vault.symbioticCollateral().asset() == vault.asset(),
            "runMellowSymbioticVaultStorageTest: Symbiotic collateral asset should be set correctly"
        );

        SymbioticWithdrawalQueue queue = SymbioticWithdrawalQueue(address(vault.withdrawalQueue()));

        require(
            address(queue) != address(0) && queue.vault() == address(vault)
                && address(vault.symbioticVault()) == address(queue.symbioticVault())
                && queue.collateral() == vault.asset(),
            "runMellowSymbioticVaultStorageTest: Withdrawal queue should be set correctly"
        );

        uint256[] memory farmIds = vault.symbioticFarmIds();
        uint256 farmCount = vault.symbioticFarmCount();

        if (testParams.isDuringDeployment) {
            require(
                farmIds.length == 0,
                "runMellowSymbioticVaultStorageTest: Farm IDs length should be 0 during deployment"
            );
            require(
                farmCount == 0,
                "runMellowSymbioticVaultStorageTest: Farm count should be 0 during deployment"
            );
        }

        require(
            farmIds.length == farmCount,
            "runMellowSymbioticVaultStorageTest: Farm IDs length should be equal to farm count"
        );

        for (uint256 i = 0; i < farmCount; i++) {
            uint256 farmId = vault.symbioticFarmIdAt(i);
            require(
                vault.symbioticFarmsContains(farmId),
                "runMellowSymbioticVaultStorageTest: Farm IDs should be contained in farms"
            );
        }

        for (uint256 i = 0; i < farmIds.length; i++) {
            IMellowSymbioticVaultStorage.FarmData memory farm = vault.symbioticFarm(farmIds[i]);
            require(
                farm.rewardToken != address(vault)
                    && farm.rewardToken != address(vault.symbioticVault()),
                "runMellowSymbioticVaultStorageTest: Farm reward token should not be vault nor symbiotic vault"
            );
            require(
                farm.curatorFeeD6 <= 10 ** 6,
                "runMellowSymbioticVaultStorageTest: Curator fee should not exceed 100%"
            );
        }
    }

    function runERC4626VaultTest(
        MellowVaultCompat vault,
        MigrationDeploy.MigrationDeployParams memory deployParams,
        TestParams memory testParams
    ) public view {
        // function maxMint(address account);
        // function maxDeposit(address account);
        // function maxWithdraw(address account);
        // function maxRedeem(address account);

        if (testParams.isDuringDeployment) {
            require(
                vault.maxMint(address(vault)) == 0,
                "runERC4626VaultTest: maxMint should be 0 during deployment"
            );
            require(
                vault.maxDeposit(address(vault)) == 0,
                "runERC4626VaultTest: maxDeposit should be 0 during deployment"
            );
            require(
                vault.maxWithdraw(address(vault)) == 0,
                "runERC4626VaultTest: maxWithdraw should be 0 during deployment"
            );
            require(
                vault.maxRedeem(address(vault)) == 0,
                "runERC4626VaultTest: maxRedeem should be 0 during deployment"
            );
        } else {
            uint256 limit = vault.limit();
            uint256 totalAssets = vault.totalAssets();
            uint256 leftover = limit == type(uint256).max
                ? type(uint256).max
                : limit < totalAssets ? limit - totalAssets : 0;
            bool hasDepositWhitelist = vault.depositWhitelist();
            bool isDepositorWhitelisted = vault.isDepositorWhitelisted(address(vault));
            bool isDepositAllowed =
                !vault.depositPause() && (!hasDepositWhitelist || isDepositorWhitelisted);
            bool isWithdrawalAllowed = !vault.withdrawalPause();
            uint256 vaultBalance = vault.balanceOf(address(vault));

            if (isDepositAllowed) {
                require(
                    vault.maxMint(address(vault)) == vault.convertToShares(leftover),
                    "runERC4626VaultTest: maxMint should be calculated correctly"
                );
                require(
                    vault.maxDeposit(address(vault)) == leftover,
                    "runERC4626VaultTest: maxDeposit should be calculated correctly"
                );
            } else {
                require(
                    vault.maxMint(address(vault)) == 0,
                    "runERC4626VaultTest: maxMint should be 0 when not allowed"
                );
                require(
                    vault.maxDeposit(address(vault)) == 0,
                    "runERC4626VaultTest: maxDeposit should be 0 when not allowed"
                );
            }

            if (isWithdrawalAllowed) {
                require(
                    vault.maxRedeem(address(vault)) == vaultBalance && vaultBalance != 0,
                    "runERC4626VaultTest: maxRedeem should be calculated correctly"
                );

                require(
                    vault.maxWithdraw(address(vault)) == vault.convertToAssets(vaultBalance),
                    "runERC4626VaultTest: maxWithdraw should be calculated correctly"
                );
            } else {
                require(
                    vault.maxRedeem(address(vault)) == 0 && vaultBalance != 0,
                    "runERC4626VaultTest: maxRedeem should be calculated correctly"
                );

                require(
                    vault.maxWithdraw(address(vault)) == 0,
                    "runERC4626VaultTest: maxWithdraw should be calculated correctly"
                );
            }
        }
    }

    function runVaultControlStorageTest(
        MellowVaultCompat vault,
        MigrationDeploy.MigrationDeployParams memory deployParams,
        TestParams memory testParams
    ) public view {
        // function depositPause() public view returns (bool);
        // function withdrawalPause() public view returns (bool);
        // function limit() public view returns (uint256);
        // function depositWhitelist() public view returns (bool);
        // function isDepositorWhitelisted(address account) public view returns (bool);
    }

    function runAccessControlEnumerableUpgradeableTest(
        MellowVaultCompat vault,
        MigrationDeploy.MigrationDeployParams memory deployParams,
        TestParams memory testParams
    ) public view {
        // function getRoleMember(bytes32 role, uint256 index) public view virtual returns (address);
        // function getRoleMemberCount(bytes32 role) public view virtual returns (uint256);
        // function hasRole(bytes32 role, address account) public view virtual returns (bool);
        // function getRoleAdmin(bytes32 role) public view virtual returns (bytes32);
    }

    function runERC4626UpgradeableTest(
        MellowVaultCompat vault,
        MigrationDeploy.MigrationDeployParams memory deployParams,
        TestParams memory testParams
    ) public view {
        // function decimals() public view virtual override(IERC20Metadata, ERC20Upgradeable) returns (uint8);
        // function asset() public view virtual returns (address);
        // function convertToShares(uint256 assets) public view virtual returns (uint256);
        // function convertToAssets(uint256 shares) public view virtual returns (uint256);
        // function previewDeposit(uint256 assets) public view virtual returns (uint256);
        // function previewMint(uint256 shares) public view virtual returns (uint256);
        // function previewWithdraw(uint256 assets) public view virtual returns (uint256);
        // function previewRedeem(uint256 shares) public view virtual returns (uint256);
    }

    function runPermissionsTest(
        MellowVaultCompat vault,
        MigrationDeploy.MigrationDeployParams memory deployParams,
        TestParams memory testParams
    ) public view {
        bytes32[] memory roles = Permissions.roles();
        for (uint256 i = 0; i < roles.length; i++) {
            if (roles[i] == Permissions.DEFAULT_ADMIN_ROLE) {
                require(
                    vault.getRoleMemberCount(Permissions.DEFAULT_ADMIN_ROLE) == 1,
                    "runPermissionsTest: default admin should be set"
                );
                address admin = vault.getRoleMember(Permissions.DEFAULT_ADMIN_ROLE, 0);
                require(admin != address(0), "runPermissionsTest: default admin should not be 0");
            } else {
                if (testParams.isDuringDeployment) {
                    require(
                        vault.getRoleMemberCount(roles[i]) == 0,
                        "runPermissionsTest: role should not be set during deployment"
                    );
                } else {
                    require(
                        vault.getRoleMemberCount(roles[i]) <= 1,
                        "runPermissionsTest: role should not have more than 1 member"
                    );
                }
            }
        }
    }

    function runValuesTest(
        MellowVaultCompat vault,
        MigrationDeploy.MigrationDeployParams memory deployParams,
        TestParams memory testParams
    ) public view {
        address immutableProxyAdmin =
            address(uint160(uint256(vm.load(address(vault), ERC1967Utils.ADMIN_SLOT))));
        require(
            immutableProxyAdmin == deployParams.proxyAdmin && deployParams.proxyAdmin != address(0),
            "runValuesTest: proxy admin should be set correctly"
        );
        require(
            ProxyAdmin(immutableProxyAdmin).owner() == deployParams.proxyAdminOwner
                && deployParams.proxyAdminOwner != address(0),
            "runValuesTest: proxy admin owner should be set correctly"
        );
        require(vault.limit() > 0, "runValuesTest: Limit should be set correctly");

        address asset = vault.asset();
        require(asset != address(0), "runValuesTest: asset address should be set correctly");

        bytes memory bondData =
            IDefaultBondStrategy(deployParams.defaultBondStrategy).tokenToData(asset);
        require(bondData.length != 0, "runValuesTest: bondData should not be empty");

        IDefaultBondStrategy.Data[] memory data =
            abi.decode(bondData, (IDefaultBondStrategy.Data[]));

        require(
            data.length == 1 && data[0].bond != address(0) && data[0].ratioX96 == Q96,
            "runValuesTest: invalid bond data"
        );

        require(
            address(vault.symbioticCollateral()) == data[0].bond,
            "runValuesTest: symbioticCollateral mistmatch"
        );

        require(IDefaultBond(data[0].bond).asset() == asset, "runValuesTest: bond asset mismatch");

        require(
            address(vault.symbioticVault()) == deployParams.symbioticVault,
            "runValuesTest: symbioticVault mismatch"
        );

        require(
            ISymbioticVault(deployParams.symbioticVault).collateral() == asset,
            "runValuesTest: symbioticVault collateral mismatch"
        );

        SymbioticWithdrawalQueue withdrawalQueue =
            SymbioticWithdrawalQueue(address(vault.withdrawalQueue()));

        require(
            address(withdrawalQueue.vault()) == address(vault),
            "runValuesTest: withdrawal queue should be set correctly (mellowVault)"
        );

        require(
            address(withdrawalQueue.symbioticVault()) == address(vault.symbioticVault()),
            "runValuesTest: withdrawal queue should be set correctly (symbioticVault)"
        );

        require(
            address(withdrawalQueue.collateral()) == address(vault.asset()),
            "runValuesTest: withdrawal queue should be set correctly (asset)"
        );

        require(
            withdrawalQueue.getCurrentEpoch() == vault.symbioticVault().currentEpoch(),
            "runValuesTest: withdrawal queue should be set correctly (currentEpoch)"
        );

        require(
            vault.totalSupply() != 0,
            "runDeploymentValuesTest: Total supply should not be 0 during deployment"
        );
        require(
            vault.totalAssets() != 0,
            "runDeploymentValuesTest: Total assets should not be 0 during deployment"
        );
        require(
            vault.balanceOf(address(vault)) != 0,
            "runDeploymentValuesTest: Vault balance should not be 0 during deployment (initial deposit)"
        );

        // no revert expected
        require(
            vault.claimableAssetsOf(address(vault)) == 0,
            "runDeploymentValuesTest: Claimable assets should be 0 during deployment"
        );
        require(
            vault.pendingAssetsOf(address(vault)) == 0,
            "runDeploymentValuesTest: Claimable assets should be 0 during deployment"
        );

        (uint256 accountAssets,, uint256 accountShares,) = vault.getBalances(address(vault));
        require(
            accountAssets != 0,
            "runDeploymentValuesTest: vault getBalances.accountAssets should not be 0 during deployment"
        );
        require(
            accountShares != 0,
            "runDeploymentValuesTest: vault shares should not be 0 during deployment"
        );

        // VaultControlStorage view functions:
        require(
            vault.depositWhitelist() == false,
            "runDeploymentValuesTest: Deposit whitelist should be set correctly"
        );
        require(
            vault.isDepositorWhitelisted(address(vault)) == false,
            "runDeploymentValuesTest: Vault should not be whitelisted as a depositor"
        );

        // ERC4626 view functions:
        require(
            vault.decimals() == 18,
            "runDeploymentValuesTest: Decimals should be set to 18 during deployment"
        );

        require(
            vault.asset() != address(0),
            "runDeploymentValuesTest: Asset should be set during deployment"
        );

        require(
            vault.asset() == vault.symbioticCollateral().asset(),
            "runDeploymentValuesTest: Asset should be set to the symbiotic collateral asset"
        );

        require(
            vault.asset() == vault.symbioticVault().collateral(),
            "runDeploymentValuesTest: Asset should be set to the symbiotic vault collateral"
        );

        if (testParams.isDuringDeployment) {
            runDeploymentValuesTest(vault, deployParams);
        }
    }

    function runDeploymentValuesTest(
        MellowVaultCompat vault,
        MigrationDeploy.MigrationDeployParams memory deployParams
    ) public view {
        // MellowSymbioticVault view functions:
        require(
            vault.totalSupply() != 0,
            "runDeploymentValuesTest: Total supply should not be 0 during deployment"
        );
        require(
            vault.totalAssets() != 0,
            "runDeploymentValuesTest: Total assets should not be 0 during deployment"
        );
        require(
            vault.balanceOf(address(vault)) != 0,
            "runDeploymentValuesTest: Vault balance should not be 0 during deployment (initial deposit)"
        );

        require(
            vault.depositPause() == true, "runValuesTest: deposit pause should be set correctly"
        );

        require(
            vault.withdrawalPause() == true,
            "runValuesTest: withdrawal pause should be set correctly"
        );

        require(
            vault.depositWhitelist() == false,
            "runValuesTest: deposit whitelist should be set correctly"
        );

        // no revert expected
        require(
            vault.claimableAssetsOf(address(vault)) == 0,
            "runDeploymentValuesTest: Claimable assets should be 0 during deployment"
        );
        require(
            vault.pendingAssetsOf(address(vault)) == 0,
            "runDeploymentValuesTest: Claimable assets should be 0 during deployment"
        );

        (uint256 accountAssets,, uint256 accountShares,) = vault.getBalances(address(vault));
        require(
            accountAssets != 0,
            "runDeploymentValuesTest: vault getBalances.accountAssets should not be 0 during deployment"
        );
        require(
            accountShares != 0,
            "runDeploymentValuesTest: vault shares should not be 0 during deployment"
        );

        require(
            vault.symbioticFarmIds().length == 0,
            "runDeploymentValuesTest: Symbiotic farm IDs should be empty during deployment"
        );

        require(
            vault.symbioticFarmCount() == 0,
            "runDeploymentValuesTest: Symbiotic farm count should be 0 during deployment"
        );

        require(
            vault.symbioticFarmsContains(0) == false,
            "runDeploymentValuesTest: Symbiotic farms should not contain farm ID 0 during deployment"
        );

        require(
            vault.symbioticFarm(0).rewardToken == address(0),
            "runDeploymentValuesTest: Symbiotic farm reward token should be 0 during deployment"
        );

        // WithdrawalQueue view functions:
        SymbioticWithdrawalQueue withdrawalQueue =
            SymbioticWithdrawalQueue(address(vault.withdrawalQueue()));
        for (uint256 i = 0; i < 2; i++) {
            ISymbioticWithdrawalQueue.EpochData memory epochData =
                withdrawalQueue.getEpochData(withdrawalQueue.getCurrentEpoch() + i);
            require(
                epochData.isClaimed == false,
                "runDeploymentValuesTest: Epoch data should not be claimed during deployment"
            );
            require(
                epochData.sharesToClaim == 0 && epochData.claimableAssets == 0,
                "runDeploymentValuesTest: Epoch data should be empty during deployment"
            );
        }

        require(
            withdrawalQueue.pendingAssets() == 0,
            "runDeploymentValuesTest: Withdrawal queue pending assets should be 0 during deployment"
        );
        require(
            withdrawalQueue.pendingAssetsOf(address(vault)) == 0,
            "runDeploymentValuesTest: Withdrawal queue pending assets should be 0 for vault address"
        );
        require(
            withdrawalQueue.claimableAssetsOf(address(vault)) == 0,
            "runDeploymentValuesTest: Withdrawal queue claimable assets should be 0 for vault address"
        );
    }
}
