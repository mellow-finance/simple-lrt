// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "forge-std/Base.sol";

import "../../scripts/mainnet/MigrationDeploy.sol";

contract AcceptanceMigrationRunner is CommonBase {
    uint256 private constant Q96 = 2 ** 96;

    struct TestParams {
        bool isDuringDeployment;
    }

    function runAcceptance(
        MellowSymbioticVault vault,
        MigrationDeploy.MigrationDeployParams memory deployParams,
        TestParams memory testParams
    ) public view {
        runPermissionsTest(vault, deployParams, testParams);
        runValuesTest(vault, deployParams, testParams);
    }

    function runPermissionsTest(
        MellowSymbioticVault vault,
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
        MellowSymbioticVault vault,
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
        require(vault.limit() > 0, "Limit should be set correctly");

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

        if (testParams.isDuringDeployment) {
            runDeploymentValuesTest(vault, deployParams);
        } else {
            runOnchainValuesTest(vault, deployParams);
        }
    }

    function runDeploymentValuesTest(
        MellowSymbioticVault vault,
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

        // no revert expected
        require(
            vault.claimableAssetsOf(address(vault)) == 0,
            "runDeploymentValuesTest: Claimable assets should be 0 during deployment"
        );
        require(
            vault.pendingAssetsOf(address(vault)) == 0,
            "runDeploymentValuesTest: Claimable assets should be 0 during deployment"
        );

        (
            uint256 accountAssets,
            uint256 accountInstantAssets,
            uint256 accountShares,
            uint256 accountInstantShares
        ) = vault.getBalances(address(vault));
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

        // VaultControlStorage view functions:
        require(
            vault.depositPause() == true,
            "runDeploymentValuesTest: Deposit pause should be set correctly"
        );
        require(
            vault.withdrawalPause() == true,
            "runDeploymentValuesTest: Withdrawal pause should be set correctly"
        );

        require(vault.limit() != 0, "runDeploymentValuesTest: Limit should not be zero");

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

    function runOnchainValuesTest(
        MellowSymbioticVault vault,
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

        // no revert expected
        require(
            vault.claimableAssetsOf(address(vault)) == 0,
            "runDeploymentValuesTest: Claimable assets should be 0 during deployment"
        );
        require(
            vault.pendingAssetsOf(address(vault)) == 0,
            "runDeploymentValuesTest: Claimable assets should be 0 during deployment"
        );

        (
            uint256 accountAssets,
            uint256 accountInstantAssets,
            uint256 accountShares,
            uint256 accountInstantShares
        ) = vault.getBalances(address(vault));
        require(
            accountAssets != 0,
            "runDeploymentValuesTest: vault getBalances.accountAssets should not be 0 during deployment"
        );
        require(
            accountShares != 0,
            "runDeploymentValuesTest: vault shares should not be 0 during deployment"
        );

        // VaultControlStorage view functions:
        require(vault.limit() != 0, "runDeploymentValuesTest: Limit should not be zero");

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
    }
}
