// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../BaseTest.sol";
import "../mocks/MockEigenLayerFarm.sol";

import "../../src/utils/EigenLayerFactoryHelper.sol";

contract Unit is BaseTest {
    using RandomLib for RandomLib.Storage;

    function testGetOrCreate() external {
        MultiVault vault;
        {
            TransparentUpgradeableProxy c_ = new TransparentUpgradeableProxy(
                address(new MultiVault("test", 1)), vm.createWallet("proxyAdmin").addr, new bytes(0)
            );
            vault = MultiVault(address(c_));
        }
        address vaultAdmin = rnd.randAddress();
        RatiosStrategy strategy = new RatiosStrategy();
        Claimer claimer = new Claimer();
        IsolatedEigenLayerVaultFactory factory = new IsolatedEigenLayerVaultFactory(
            Constants.HOLESKY_EL_DELEGATION_MANAGER,
            address(new IsolatedEigenLayerWstETHVault(Constants.WSTETH())),
            address(
                new EigenLayerWstETHWithdrawalQueue(
                    address(claimer), Constants.HOLESKY_EL_DELEGATION_MANAGER
                )
            ),
            vm.createWallet("proxyAdmin").addr
        );
        EigenLayerAdapter eigenLayerAdapter = new EigenLayerAdapter(
            address(factory),
            address(vault),
            IStrategyManager(Constants.HOLESKY_EL_STRATEGY_MANAGER),
            IRewardsCoordinator(Constants.HOLESKY_EL_REWARDS_COORDINATOR)
        );

        vault.initialize(
            IMultiVault.InitParams({
                admin: vaultAdmin,
                limit: type(uint256).max,
                depositPause: false,
                withdrawalPause: false,
                depositWhitelist: false,
                asset: Constants.WSTETH(),
                name: "MultiVault test",
                symbol: "MVT",
                depositStrategy: address(strategy),
                withdrawalStrategy: address(strategy),
                rebalanceStrategy: address(strategy),
                defaultCollateral: Constants.WSTETH_SYMBIOTIC_COLLATERAL(),
                symbioticAdapter: address(0),
                eigenLayerAdapter: address(eigenLayerAdapter),
                erc4626Adapter: address(0)
            })
        );

        ISignatureUtilsMixinTypes.SignatureWithExpiry memory signature;
        (address isolatedVault0,) = factory.getOrCreate(
            address(vault),
            Constants.HOLESKY_EL_STRATEGY,
            0xbF8a8B0d0450c8812ADDf04E1BcB7BfBA0E82937,
            abi.encode(signature, bytes32(0))
        );

        (address isolatedVault1,) = factory.getOrCreate(
            address(vault),
            Constants.HOLESKY_EL_STRATEGY,
            0xbF8a8B0d0450c8812ADDf04E1BcB7BfBA0E82937,
            abi.encode(signature, bytes32(0))
        );
        assertEq(isolatedVault0, isolatedVault1, "isolatedVault created");

        bytes32 key = factory.key(
            address(vault),
            Constants.HOLESKY_EL_STRATEGY,
            0xbF8a8B0d0450c8812ADDf04E1BcB7BfBA0E82937
        );

        assertEq(isolatedVault0, factory.isolatedVaults(key), "isolatedVault key error");
    }

    function testCalculateAddress() external {
        MultiVault vault;
        {
            TransparentUpgradeableProxy c_ = new TransparentUpgradeableProxy(
                address(new MultiVault("test", 1)), vm.createWallet("proxyAdmin").addr, new bytes(0)
            );
            vault = MultiVault(address(c_));
        }
        address vaultAdmin = rnd.randAddress();
        RatiosStrategy strategy = new RatiosStrategy();
        Claimer claimer = new Claimer();
        IsolatedEigenLayerVaultFactory factory = new IsolatedEigenLayerVaultFactory(
            Constants.HOLESKY_EL_DELEGATION_MANAGER,
            address(new IsolatedEigenLayerWstETHVault(Constants.WSTETH())),
            address(
                new EigenLayerWstETHWithdrawalQueue(
                    address(claimer), Constants.HOLESKY_EL_DELEGATION_MANAGER
                )
            ),
            vm.createWallet("proxyAdmin").addr
        );
        EigenLayerAdapter eigenLayerAdapter = new EigenLayerAdapter(
            address(factory),
            address(vault),
            IStrategyManager(Constants.HOLESKY_EL_STRATEGY_MANAGER),
            IRewardsCoordinator(Constants.HOLESKY_EL_REWARDS_COORDINATOR)
        );

        vault.initialize(
            IMultiVault.InitParams({
                admin: vaultAdmin,
                limit: type(uint256).max,
                depositPause: false,
                withdrawalPause: false,
                depositWhitelist: false,
                asset: Constants.WSTETH(),
                name: "MultiVault test",
                symbol: "MVT",
                depositStrategy: address(strategy),
                withdrawalStrategy: address(strategy),
                rebalanceStrategy: address(strategy),
                defaultCollateral: Constants.WSTETH_SYMBIOTIC_COLLATERAL(),
                symbioticAdapter: address(0),
                eigenLayerAdapter: address(eigenLayerAdapter),
                erc4626Adapter: address(0)
            })
        );

        EigenLayerFactoryHelper helper = new EigenLayerFactoryHelper(address(factory));

        address expectedAddress = helper.calculateAddress(
            address(vault),
            Constants.HOLESKY_EL_STRATEGY,
            0xbF8a8B0d0450c8812ADDf04E1BcB7BfBA0E82937
        );
        ISignatureUtilsMixinTypes.SignatureWithExpiry memory signature;
        (address isolatedVault0,) = factory.getOrCreate(
            address(vault),
            Constants.HOLESKY_EL_STRATEGY,
            0xbF8a8B0d0450c8812ADDf04E1BcB7BfBA0E82937,
            abi.encode(signature, bytes32(0))
        );

        assertEq(expectedAddress, isolatedVault0, "Invalid response");
    }

    function testProxyAdminFetch() external {}
}
