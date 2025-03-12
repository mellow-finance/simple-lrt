// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../src/utils/Claimer.sol";
import "../../src/utils/WhitelistedEthWrapper.sol";
import "./MultiVaultDeployScript.sol";

import {IVault} from "@symbiotic/core/interfaces/vault/IVault.sol";
import "forge-std/Script.sol";

import "../../src/adapters/EigenLayerWstETHAdapter.sol";
import "../../src/adapters/IsolatedEigenLayerVaultFactory.sol";
import "../../src/adapters/IsolatedEigenLayerWstETHVault.sol";
import "../../src/queues/EigenLayerWithdrawalQueue.sol";

contract Deploy is Script {
    address public constant WSTETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address public constant WSTETH_DEFAULT_COLLATERAL = 0xC329400492c6ff2438472D4651Ad17389fCb843a;

    RatiosStrategy public strategy = RatiosStrategy(0x3aA61E6196fb3eb1170E578ad924898624f54ad6);
    MultiVault public multiVaultImplementation =
        MultiVault(0x0C5BC4C8406Fe03214D18bbf2962Ae2fa378c6f7);
    Claimer public claimer = Claimer(0x25024a3017B8da7161d8c5DCcF768F8678fB5802);
    MultiVaultDeployScript public deployScript =
        MultiVaultDeployScript(0xffAC02252657ED228e155eE06E60f8b62dC59845);

    address public constant DEPLOYER = 0x5C0F3DE4ba6AD53bb8E27f965170A52671e525Bf;

    address public constant STRATEGY_MANAGER = 0x858646372CC42E1A627fcE94aa7A7033e7CF075A;
    address public constant REWARDS_COORDINATOR = 0x7750d328b314EfFa365A0402CcfD489B80B0adda;
    address public constant DELEGATION_MANAGER = 0x39053D51B77DC0d36036Fc1fCc8Cb819df8Ef37A;

    WhitelistedEthWrapper public depositWrapper =
        WhitelistedEthWrapper(payable(0xfD4a4922d1AFe70000Ce0Ec6806454e78256504e));

    function _deployVaults() internal {
        (MultiVault multiVault,,) = deployScript.deploy(
            MultiVaultDeployScript.DeployParams({
                admin: DEPLOYER,
                proxyAdmin: DEPLOYER,
                curator: DEPLOYER,
                symbioticVault: address(0),
                depositWrapper: address(0),
                asset: WSTETH,
                defaultCollateral: WSTETH_DEFAULT_COLLATERAL,
                limit: 100 ether,
                depositPause: false,
                withdrawalPause: false,
                name: "Mellow EigenLayer Test Vault",
                symbol: "MELTV",
                minRatioD18: 0.9 ether,
                maxRatioD18: 0.95 ether,
                salt: bytes32(0)
            })
        );

        IsolatedEigenLayerVaultFactory factory = new IsolatedEigenLayerVaultFactory(
            DELEGATION_MANAGER,
            address(new IsolatedEigenLayerWstETHVault(WSTETH)),
            address(new EigenLayerWithdrawalQueue(address(claimer), DELEGATION_MANAGER)),
            DEPLOYER
        );

        EigenLayerWstETHAdapter eigenLayerAdapter = new EigenLayerWstETHAdapter(
            address(factory),
            address(multiVault),
            IStrategyManager(STRATEGY_MANAGER),
            IRewardsCoordinator(REWARDS_COORDINATOR),
            WSTETH
        );
        multiVault.grantRole(multiVault.SET_ADAPTER_ROLE(), DEPLOYER);
        multiVault.setEigenLayerAdapter(address(eigenLayerAdapter));

        ISignatureUtils.SignatureWithExpiry memory signature;
        bytes32 salt = bytes32(0);
        (address isolatedVault,) = factory.getOrCreate(
            address(multiVault),
            0x93c4b944D05dfe6df7645A86cd2206016c51564D,
            0xDbEd88D83176316fc46797B43aDeE927Dc2ff2F5, // P2P.org [all AVS], link: https://app.eigenlayer.xyz/operator/0xdbed88d83176316fc46797b43adee927dc2ff2f5
            abi.encode(signature, salt)
        );

        multiVault.addSubvault(isolatedVault, IMultiVaultStorage.Protocol.EIGEN_LAYER);
        depositWrapper.deposit{value: 1 gwei}(
            depositWrapper.ETH(), 1 gwei, address(multiVault), DEPLOYER, DEPLOYER
        );
    }

    function run() external {
        uint256 deployerPk = uint256(bytes32(vm.envBytes("MAINNET_TEST_DEPLOYER")));
        address deployer = vm.addr(deployerPk);
        require(deployer == DEPLOYER, "not authorized");
        vm.startBroadcast(deployerPk);

        // uint g = gasleft();
        _deployVaults();
        // console2.log(g - gasleft());

        vm.stopBroadcast();
        // revert("success");
    }
}
