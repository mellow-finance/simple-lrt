// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "forge-std/Base.sol";

import "../../scripts/mainnet/FactoryDeploy.sol";

contract AcceptanceFactoryRunner is CommonBase {
    function runAcceptance(
        MellowSymbioticVault vault,
        FactoryDeploy.FactoryDeployParams memory deployParams
    ) public view {
        runPermissionsTest(vault, deployParams);
        runValuesTest(vault, deployParams);
    }

    function runPermissionsTest(
        MellowSymbioticVault vault,
        FactoryDeploy.FactoryDeployParams memory deployParams
    ) public view {
        bytes32[9] memory roles = [
            Permissions.SET_FARM_ROLE,
            Permissions.SET_LIMIT_ROLE,
            Permissions.PAUSE_WITHDRAWALS_ROLE,
            Permissions.UNPAUSE_WITHDRAWALS_ROLE,
            Permissions.PAUSE_DEPOSITS_ROLE,
            Permissions.UNPAUSE_DEPOSITS_ROLE,
            Permissions.SET_DEPOSIT_WHITELIST_ROLE,
            Permissions.SET_DEPOSITOR_WHITELIST_STATUS_ROLE,
            Permissions.DEFAULT_ADMIN_ROLE
        ];

        address[9] memory expectedHolders = [
            deployParams.setFarmRoleHoler,
            deployParams.setLimitRoleHolder,
            deployParams.pauseWithdrawalsRoleHolder,
            deployParams.unpauseWithdrawalsRoleHolder,
            deployParams.pauseDepositsRoleHolder,
            deployParams.unpauseDepositsRoleHolder,
            deployParams.setDepositWhitelistRoleHolder,
            deployParams.setDepositorWhitelistStatusRoleHolder,
            deployParams.initParams.admin
        ];

        require(
            vault.getRoleMemberCount(Permissions.DEFAULT_ADMIN_ROLE) == 1,
            "Default admin should be set"
        );

        for (uint256 i = 0; i < roles.length; i++) {
            if (expectedHolders[i] == address(0)) {
                require(vault.getRoleMemberCount(roles[i]) == 0, "Role should not have any members");
            } else {
                require(
                    vault.getRoleMemberCount(roles[i]) == 1, "Role should have exactly one member"
                );
                require(
                    vault.getRoleMember(roles[i], 0) == expectedHolders[i],
                    "Role member should be the expected address"
                );
            }
        }
    }

    function runValuesTest(
        MellowSymbioticVault vault,
        FactoryDeploy.FactoryDeployParams memory deployParams
    ) public view {
        require(
            MellowSymbioticVaultFactory(deployParams.factory).isEntity(address(vault)),
            "Vault should be registered in the factory"
        );

        address immutableProxyAdmin =
            address(uint160(uint256(vm.load(address(vault), ERC1967Utils.ADMIN_SLOT))));
        require(
            ProxyAdmin(immutableProxyAdmin).owner() == deployParams.initParams.proxyAdmin,
            "Proxy admin should be set correctly"
        );
        require(deployParams.initParams.proxyAdmin != address(0), "Proxy admin should be set");

        require(vault.limit() == deployParams.initParams.limit, "Limit should be set correctly");

        require(
            address(vault.symbioticCollateral()) == deployParams.initParams.symbioticCollateral,
            "Symbiotic collateral should be set correctly"
        );

        require(
            address(vault.symbioticVault()) == deployParams.initParams.symbioticVault,
            "Symbiotic vault should be set correctly"
        );

        require(
            vault.depositPause() == deployParams.initParams.depositPause,
            "Deposit pause should be set correctly"
        );

        require(
            vault.withdrawalPause() == deployParams.initParams.withdrawalPause,
            "Withdrawal pause should be set correctly"
        );

        require(
            vault.depositWhitelist() == deployParams.initParams.depositWhitelist,
            "Deposit whitelist should be set correctly"
        );

        require(
            keccak256(abi.encodePacked(vault.name()))
                == keccak256(abi.encodePacked(deployParams.initParams.name)),
            "Name should be set correctly"
        );

        require(
            keccak256(abi.encodePacked(vault.symbol()))
                == keccak256(abi.encodePacked(deployParams.initParams.symbol)),
            "Symbol should be set correctly"
        );

        SymbioticWithdrawalQueue withdrawalQueue =
            SymbioticWithdrawalQueue(address(vault.withdrawalQueue()));

        require(
            address(withdrawalQueue.vault()) == address(vault),
            "Withdrawal queue should be set correctly (mellowVault)"
        );

        require(
            address(withdrawalQueue.symbioticVault()) == address(vault.symbioticVault()),
            "Withdrawal queue should be set correctly (symbioticVault)"
        );

        require(
            address(withdrawalQueue.collateral()) == address(vault.asset()),
            "Withdrawal queue should be set correctly (asset)"
        );

        require(
            withdrawalQueue.getCurrentEpoch() == vault.symbioticVault().currentEpoch(),
            "Withdrawal queue should be set correctly (currentEpoch)"
        );

        // we can assume that if the total supply is 0, then the deployment is in progress
        bool isDeployment = vault.totalSupply() == 0;

        if (isDeployment) {
            runDeploymentValuesTest(vault, deployParams);
        } else {
            runOnchainValuesTest(vault, deployParams);
        }
    }

    function runDeploymentValuesTest(
        MellowSymbioticVault vault,
        FactoryDeploy.FactoryDeployParams memory deployParams
    ) public view {
        // MellowSymbioticVault view functions:
        require(vault.totalSupply() == 0, "Total supply should be 0 during deployment");
        require(vault.totalAssets() == 0, "Total assets should be 0 during deployment");

        // no revert expected
        require(
            vault.claimableAssetsOf(address(vault)) == 0,
            "Claimable assets should be 0 during deployment"
        );
        require(
            vault.pendingAssetsOf(address(vault)) == 0,
            "Claimable assets should be 0 during deployment"
        );

        (
            uint256 accountAssets,
            uint256 accountInstantAssets,
            uint256 accountShares,
            uint256 accountInstantShares
        ) = vault.getBalances(address(vault));
        require(accountAssets == 0, "Account assets should be 0 during deployment");
        require(accountInstantAssets == 0, "Account instant assets should be 0 during deployment");
        require(accountShares == 0, "Account shares should be 0 during deployment");
        require(accountInstantShares == 0, "Account instant shares should be 0 during deployment");

        // MellowSymbioticVaultStorage view functions:
        require(
            address(vault.symbioticVault()) != address(0)
                && address(vault.symbioticVault()) == deployParams.initParams.symbioticVault,
            "Symbiotic vault should be set correctly"
        );

        require(
            address(vault.symbioticCollateral()) != address(0)
                && address(vault.symbioticCollateral()) == deployParams.initParams.symbioticCollateral,
            "Symbiotic collateral should be set correctly"
        );

        require(
            vault.asset() == vault.symbioticCollateral().asset()
                && vault.asset() == vault.symbioticVault().collateral(),
            "Asset should be set correctly"
        );

        require(
            address(vault.withdrawalQueue()) != address(0),
            "Withdrawal queue should be set correctly"
        );

        require(
            vault.symbioticFarmIds().length == 0,
            "Symbiotic farm IDs should be empty during deployment"
        );

        require(
            vault.symbioticFarmCount() == 0, "Symbiotic farm count should be 0 during deployment"
        );

        try vault.symbioticFarmIdAt(0) {
            revert("Should revert");
        } catch {}

        require(
            vault.symbioticFarmsContains(0) == false,
            "Symbiotic farms should not contain farm ID 0 during deployment"
        );

        require(
            vault.symbioticFarm(0).rewardToken == address(0),
            "Symbiotic farm reward token should be 0 during deployment"
        );

        // ERC4626Vault view functions:
        require(
            vault.maxDeposit(address(vault)) == deployParams.initParams.limit,
            "Max deposit should be set to the limit during deployment"
        );
        require(
            vault.maxMint(address(vault)) == deployParams.initParams.limit,
            "Max deposit should be set to the limit during deployment"
        );

        require(
            vault.maxWithdraw(address(vault)) == 0, "Max withdraw should be 0 during deployment"
        );
        require(vault.maxRedeem(address(vault)) == 0, "Max withdraw should be 0 during deployment");

        // VaultControlStorage view functions:
        require(
            vault.depositPause() == deployParams.initParams.depositPause,
            "Deposit pause should be set correctly"
        );
        require(
            vault.withdrawalPause() == deployParams.initParams.withdrawalPause,
            "Withdrawal pause should be set correctly"
        );
        require(vault.limit() == deployParams.initParams.limit, "Limit should be set correctly");
        require(
            vault.depositWhitelist() == deployParams.initParams.depositWhitelist,
            "Deposit whitelist should be set correctly"
        );
        require(
            vault.isDepositorWhitelisted(address(vault)) == false,
            "Vault should not be whitelisted as a depositor"
        );

        // ERC4626 view functions:
        require(vault.decimals() == 18, "Decimals should be set to 18 during deployment");

        require(vault.asset() != address(0), "Asset should be set during deployment");

        require(
            vault.asset() == vault.symbioticCollateral().asset(),
            "Asset should be set to the symbiotic collateral asset"
        );

        require(
            vault.asset() == vault.symbioticVault().collateral(),
            "Asset should be set to the symbiotic vault collateral"
        );

        uint256 D18 = 10 ** 18;

        require(
            vault.convertToAssets(D18) == D18,
            "Convert to assets should be identity during deployment"
        );

        require(
            vault.convertToShares(D18) == D18,
            "Convert to shares should be identity during deployment"
        );

        require(
            vault.previewDeposit(D18) == D18, "Preview deposit should be identity during deployment"
        );

        require(vault.previewMint(D18) == D18, "Preview mint should be identity during deployment");

        require(
            vault.previewWithdraw(D18) == D18,
            "Preview withdraw should be identity during deployment"
        );

        require(
            vault.previewRedeem(D18) == D18, "Preview redeem should be identity during deployment"
        );

        SymbioticWithdrawalQueue withdrawalQueue =
            SymbioticWithdrawalQueue(address(vault.withdrawalQueue()));
        for (uint256 i = 0; i < 2; i++) {
            ISymbioticWithdrawalQueue.EpochData memory epochData =
                withdrawalQueue.getEpochData(withdrawalQueue.getCurrentEpoch() + i);
            require(
                epochData.isClaimed == false, "Epoch data should not be claimed during deployment"
            );
            require(
                epochData.sharesToClaim == 0 && epochData.claimableAssets == 0,
                "Epoch data should be empty during deployment"
            );
        }

        require(
            withdrawalQueue.pendingAssets() == 0,
            "Withdrawal queue pending assets should be 0 during deployment"
        );
        require(
            withdrawalQueue.pendingAssetsOf(address(vault)) == 0,
            "Withdrawal queue pending assets should be 0 for vault address"
        );
        require(
            withdrawalQueue.claimableAssetsOf(address(vault)) == 0,
            "Withdrawal queue claimable assets should be 0 for vault address"
        );
    }

    function runOnchainValuesTest(
        MellowSymbioticVault vault,
        FactoryDeploy.FactoryDeployParams memory deployParams
    ) public view {
        // MellowSymbioticVault view functions:
        require(vault.totalSupply() != 0, "Total supply should be non-zero after deployment");
        require(vault.totalAssets() != 0, "Total assets should be non-zero after deployment");

        // no revert expected
        require(
            vault.claimableAssetsOf(address(vault)) == 0,
            "Claimable assets should be 0 after deployment for vault address"
        );
        require(
            vault.pendingAssetsOf(address(vault)) == 0,
            "Claimable assets should be 0 after deployment for vault address"
        );

        (
            uint256 accountAssets,
            uint256 accountInstantAssets,
            uint256 accountShares,
            uint256 accountInstantShares
        ) = vault.getBalances(address(vault));
        require(accountAssets == 0, "Account assets should be 0 after deployment for vault address");
        require(
            accountInstantAssets == 0,
            "Account instant assets should be 0 after deployment for vault address"
        );
        require(accountShares == 0, "Account shares should be 0 after deployment for vault address");
        require(
            accountInstantShares == 0,
            "Account instant shares should be 0 after deployment for vault address"
        );

        // MellowSymbioticVaultStorage view functions:
        require(
            address(vault.symbioticVault()) != address(0)
                && address(vault.symbioticVault()) == deployParams.initParams.symbioticVault,
            "Symbiotic vault should be set correctly"
        );

        require(
            address(vault.symbioticCollateral()) != address(0)
                && address(vault.symbioticCollateral()) == deployParams.initParams.symbioticCollateral,
            "Symbiotic collateral should be set correctly"
        );

        require(
            vault.asset() == vault.symbioticCollateral().asset()
                && vault.asset() == vault.symbioticVault().collateral(),
            "Asset should be set correctly"
        );

        require(
            address(vault.withdrawalQueue()) != address(0),
            "Withdrawal queue should be set correctly"
        );

        uint256 farmCount = vault.symbioticFarmCount();
        if (farmCount == 0) {
            require(
                vault.symbioticFarmIds().length == 0,
                "Symbiotic farm IDs should be empty after deployment"
            );

            try vault.symbioticFarmIdAt(0) {
                revert("Should revert");
            } catch {}

            require(
                vault.symbioticFarmsContains(0) == false,
                "Symbiotic farms should not contain farm ID 0 after deployment"
            );

            require(
                vault.symbioticFarm(0).rewardToken == address(0),
                "Symbiotic farm reward token should be 0 after deployment"
            );
        } else {
            uint256[] memory farmIds = vault.symbioticFarmIds();
            require(
                farmIds.length == farmCount,
                "Farm IDs length should match farm count after deployment"
            );

            for (uint256 i = 0; i < farmCount; i++) {
                require(
                    vault.symbioticFarmIdAt(i) == farmIds[i],
                    "Farm ID at index should match farm ID"
                );

                require(
                    vault.symbioticFarmsContains(farmIds[i]) == true,
                    "Symbiotic farms should contain farm ID"
                );

                require(
                    vault.symbioticFarm(farmIds[i]).rewardToken != address(0),
                    "Symbiotic farm reward token should be set after deployment"
                );
            }
        }

        // ERC4626Vault view functions:

        uint256 assets_ = vault.totalAssets();
        uint256 shares_ = vault.totalSupply();

        require(
            vault.maxDeposit(address(vault)) == deployParams.initParams.limit - assets_,
            "Max deposit should be equal to the limit minus the total assets after deployment"
        );

        uint256 expectedMaxMint = Math.mulDiv(
            deployParams.initParams.limit - assets_, shares_ + 1, assets_ + 1, Math.Rounding.Floor
        );
        require(
            vault.maxMint(address(vault)) == expectedMaxMint,
            string.concat(
                "Max mint should be proportional to the max deposit after deployment ",
                Strings.toString(expectedMaxMint)
            )
        );

        require(
            vault.maxWithdraw(address(vault)) == 0, "Max withdraw should be 0 during deployment"
        );
        require(vault.maxRedeem(address(vault)) == 0, "Max withdraw should be 0 during deployment");

        // ERC4626 view functions:
        require(vault.decimals() == 18, "Decimals should be set to 18 during deployment");
        require(vault.asset() != address(0), "Asset should be set during deployment");

        require(
            vault.asset() == vault.symbioticCollateral().asset(),
            "Asset should be set to the symbiotic collateral asset"
        );

        require(
            vault.asset() == vault.symbioticVault().collateral(),
            "Asset should be set to the symbiotic vault collateral"
        );

        uint256 D18 = 10 ** 18;

        require(
            vault.convertToAssets(D18) == Math.mulDiv(D18, assets_ + 1, shares_ + 1),
            "Convert to assets should be identity during deployment"
        );

        require(
            vault.convertToShares(D18) == Math.mulDiv(D18, shares_ + 1, assets_ + 1),
            "Convert to shares should be identity during deployment"
        );

        require(
            vault.previewDeposit(D18) == Math.mulDiv(D18, shares_ + 1, assets_ + 1),
            "Preview deposit should be identity during deployment"
        );

        require(
            vault.previewMint(D18) == Math.mulDiv(D18, assets_ + 1, shares_ + 1, Math.Rounding.Ceil),
            "Preview mint should be identity during deployment"
        );

        require(
            vault.previewWithdraw(D18)
                == Math.mulDiv(D18, shares_ + 1, assets_ + 1, Math.Rounding.Ceil),
            "Preview withdraw should be identity during deployment"
        );

        require(
            vault.previewRedeem(D18) == Math.mulDiv(D18, assets_ + 1, shares_ + 1),
            "Preview redeem should be identity during deployment"
        );
    }
}
