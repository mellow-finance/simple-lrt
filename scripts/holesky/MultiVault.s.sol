// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../test/Imports.sol";

import "./collector/Collector.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "./collector/ConstantOracle.sol";
import "./collector/Oracle.sol";
import "forge-std/Script.sol";

contract Deploy is Script {
    function logVaultData(Collector collector, address vault, address user) public view {
        {
            (
                uint256 accountAssets,
                uint256 accountInstantAssets,
                Collector.Withdrawal[] memory withdrawals
            ) = collector.getVaultAssets(MultiVault(vault), user, MultiVault(vault).balanceOf(user));
            console2.log(
                string(
                    abi.encodePacked(
                        "logVaultData for vault=",
                        Strings.toHexString(vault),
                        ": accountAssets=",
                        Strings.toString(accountAssets),
                        ", accountInstantAssets=",
                        Strings.toString(accountInstantAssets),
                        ", withdrawals.length=",
                        Strings.toString(withdrawals.length),
                        ", user=",
                        Strings.toHexString(user)
                    )
                )
            );
            for (uint256 i = 0; i < withdrawals.length; i++) {
                string memory log__ = "withdrawal [";
                log__ = string(
                    abi.encodePacked(
                        log__,
                        Strings.toString(i),
                        "]: subvaultIndex=",
                        Strings.toString(withdrawals[i].subvaultIndex),
                        ", assets=",
                        Strings.toString(withdrawals[i].assets),
                        ", isTimestamp=",
                        withdrawals[i].isTimestamp ? "true" : "false",
                        ", claimingTime=",
                        Strings.toString(withdrawals[i].claimingTime),
                        ", withdrawalIndex=",
                        Strings.toString(withdrawals[i].withdrawalIndex),
                        ", withdrawalRequestType=",
                        Strings.toString(withdrawals[i].withdrawalRequestType)
                    )
                );

                console2.log(log__);
            }
        }
        console2.log();

        {
            Collector.Response memory response = collector.collect(user, IERC4626(vault));
            string memory log__ = string(
                abi.encodePacked(
                    "collect for vault=",
                    Strings.toHexString(vault),
                    ", user=",
                    Strings.toHexString(user),
                    ", asset=",
                    Strings.toHexString(response.asset),
                    ", assetDecimals=",
                    Strings.toString(response.assetDecimals),
                    ", assetPriceX96=",
                    Strings.toString(response.assetPriceX96),
                    ", totalLP=",
                    Strings.toString(response.totalLP)
                )
            );

            log__ = string(
                abi.encodePacked(
                    log__,
                    ", totalUSD=",
                    Strings.toString(response.totalUSD),
                    ", totalETH=",
                    Strings.toString(response.totalETH),
                    ", totalUnderlying=",
                    Strings.toString(response.totalUnderlying),
                    ", limitLP=",
                    Strings.toString(response.limitLP),
                    ", limitUSD=",
                    Strings.toString(response.limitUSD)
                )
            );

            log__ = string(
                abi.encodePacked(
                    log__,
                    ", limitETH=",
                    Strings.toString(response.limitETH),
                    ", limitUnderlying=",
                    Strings.toString(response.limitUnderlying),
                    ", userLP=",
                    Strings.toString(response.userLP),
                    ", userETH=",
                    Strings.toString(response.userETH),
                    ", userUSD=",
                    Strings.toString(response.userUSD),
                    ", userUnderlying=",
                    Strings.toString(response.userUnderlying)
                )
            );

            log__ = string(
                abi.encodePacked(
                    log__,
                    ", lpPriceUSD=",
                    Strings.toString(response.lpPriceUSD),
                    ", lpPriceETH=",
                    Strings.toString(response.lpPriceETH),
                    ", lpPriceUnderlying=",
                    Strings.toString(response.lpPriceUnderlying),
                    ", blockNumber=",
                    Strings.toString(response.blockNumber),
                    ", timestamp=",
                    Strings.toString(response.timestamp)
                )
            );

            console2.log(log__);

            for (uint256 i = 0; i < response.withdrawals.length; i++) {
                console2.log(
                    string(
                        abi.encodePacked(
                            "withdrawal [",
                            Strings.toString(i),
                            "]: subvaultIndex=",
                            Strings.toString(response.withdrawals[i].subvaultIndex),
                            ", assets=",
                            Strings.toString(response.withdrawals[i].assets),
                            ", isTimestamp=",
                            response.withdrawals[i].isTimestamp ? "true" : "false",
                            ", claimingTime=",
                            Strings.toString(response.withdrawals[i].claimingTime),
                            ", withdrawalIndex=",
                            Strings.toString(response.withdrawals[i].withdrawalIndex),
                            ", withdrawalRequestType=",
                            Strings.toString(response.withdrawals[i].withdrawalRequestType)
                        )
                    )
                );
            }
        }

        // uint256[] memory amounts = new uint256[](1);
        // amounts[0] = 1 ether;
        // collector.fetchDepositAmounts(amounts, vault, user);
        // collector.fetchDepositWrapperParams(vault, user, collector.wsteth(), 1 ether);
        // collector.fetchDepositWrapperParams(vault, user, collector.steth(), 1 ether);
        // collector.fetchDepositWrapperParams(vault, user, collector.weth(), 1 ether);
        // collector.fetchDepositWrapperParams(vault, user, collector.eth(), 1 ether);
        // collector.fetchWithdrawalAmounts(IERC4626(vault).balanceOf(user), vault);

        console2.log("--------------------");
    }

    function run() external {
        uint256 pk = uint256(bytes32(vm.envBytes("HOLESKY_DEPLOYER")));
        vm.startBroadcast(pk);

        Collector prevCollector = Collector(0xB23a6fac33d5198b90db6d2D8344A7B9a5B56890);
        Collector collector =
            new Collector(prevCollector.wsteth(), prevCollector.weth(), prevCollector.owner());
        // Oracle oracle = new Oracle(collector.owner());
        // address[] memory tokens = new address[](5);
        // tokens[0] = Constants.HOLESKY_WSTETH;
        // tokens[1] = Constants.HOLESKY_WETH;
        // tokens[2] = Constants.HOLESKY_STETH;
        // tokens[3] = collector.usd();
        // tokens[4] = collector.eth();
        // uint256 Q96 = 2 ** 96;
        // Oracle.TokenOracle[] memory oracles = new Oracle.TokenOracle[](5);
        // oracles[0] =
        //     Oracle.TokenOracle({constValue: (1.181476 ether) * Q96 / 1 ether, oracle: address(0)});
        // oracles[1] = Oracle.TokenOracle({constValue: Q96, oracle: address(0)});
        // oracles[2] = Oracle.TokenOracle({constValue: Q96, oracle: address(0)});
        // oracles[3] = Oracle.TokenOracle({constValue: Q96 * 1e10 / 3354, oracle: address(0)});
        // oracles[4] = Oracle.TokenOracle({constValue: Q96, oracle: address(0)});
        // oracle.setOracles(tokens, oracles);
        collector.setOracle(address(prevCollector.oracle()));

        // address user = 0x7777775b9E6cE9fbe39568E485f5E20D1b0e04EE;

        // logVaultData(collector, 0xD1d9c7cd66721e43579Be95BC6D13b56817Dd54D, user);
        // logVaultData(collector, 0xc119d25470f6C4AA842772521704e7049f540477, user);
        // logVaultData(collector, 0xc3dA07f12344BE2E9212B2B40D3eB9e9aC2dBe27, user);
        // // logVaultData(collector, 0x7F31eb85aBE328EBe6DD07f9cA651a6FE623E69B, user);

        // user = 0xceDC35457010Be27048C943d556c964f63867D64;

        // logVaultData(collector, 0xD1d9c7cd66721e43579Be95BC6D13b56817Dd54D, user);
        // logVaultData(collector, 0xc119d25470f6C4AA842772521704e7049f540477, user);
        // logVaultData(collector, 0xc3dA07f12344BE2E9212B2B40D3eB9e9aC2dBe27, user);
        // logVaultData(collector, 0x7F31eb85aBE328EBe6DD07f9cA651a6FE623E69B, user);

        vm.stopBroadcast();
        // revert("ok");

        // RatiosStrategy strategy = RatiosStrategy(0xba94DF565fA7760003ABD6C295ef514597b4650b);
        // MultiVault vault = MultiVault(0xc3dA07f12344BE2E9212B2B40D3eB9e9aC2dBe27);
        // IsolatedEigenLayerVaultFactory factory =
        //     IsolatedEigenLayerVaultFactory(0x905D71F192eB6F20663E312D0263c412A2654430);

        // address eigenLayerStrategy = 0x7D704507b76571a51d9caE8AdDAbBFd0ba0e63d3;
        // address operator = address(deployer);

        // IDelegationManagerTestnet(Constants.HOLESKY_EL_DELEGATION_MANAGER).registerAsOperator(
        //     address(0), 0, "test-mellow-operator"
        // );

        // ISignatureUtils.SignatureWithExpiry memory signature;
        // (address isolatedVault, address withdrawalQueue) = factory.getOrCreate(
        //     address(vault), operator, eigenLayerStrategy, abi.encode(signature, bytes32(0))
        // );
        // vault.addSubvault(isolatedVault, IMultiVaultStorage.Protocol.EIGEN_LAYER);

        // address[] memory subvaults = new address[](2);
        // subvaults[0] = 0x7F9dEaA3A26AEA587f8A41C6063D4f93F5a5ee7A;
        // subvaults[1] = isolatedVault;

        // IRatiosStrategy.Ratio[] memory ratios_ = new IRatiosStrategy.Ratio[](2);
        // ratios_[0] = IRatiosStrategy.Ratio({
        //     minRatioD18: 0.2 ether,
        //     maxRatioD18: 0.3 ether
        // });
        // ratios_[1] = IRatiosStrategy.Ratio({
        //     minRatioD18: 0.3 ether,
        //     maxRatioD18: 0.4 ether
        // });

        // strategy.setRatios(address(vault), subvaults, ratios_);

        // vault.rebalance();

        // revert("ok");
        // console2.log(
        //     ISymbioticAdapter(0x7B223E26E57c23A3E6b8Cfd84bE5175409E8CA56).maxDeposit(0x7F9dEaA3A26AEA587f8A41C6063D4f93F5a5ee7A)
        // );
        // vault.grantRole(strategy.RATIOS_STRATEGY_SET_RATIOS_ROLE(), deployer);
        // vault.grantRole(vault.REBALANCE_ROLE(), deployer);

        // address[] memory subvaults = new address[](1);
        // subvaults[0] = 0x7F9dEaA3A26AEA587f8A41C6063D4f93F5a5ee7A;
        // IRatiosStrategy.Ratio[] memory ratios_ = new IRatiosStrategy.Ratio[](1);
        // ratios_[0] = IRatiosStrategy.Ratio({
        //     minRatioD18: 0.5 ether,
        //     maxRatioD18: 0.8 ether
        // });
        // strategy.setRatios(address(vault), subvaults, ratios_);

        // EthWrapper wrapper = new EthWrapper(
        //     Constants.HOLESKY_WETH,
        //     Constants.HOLESKY_WSTETH,
        //     Constants.HOLESKY_STETH
        // );

        // IERC20(Constants.HOLESKY_WSTETH).approve(address(vault), type(uint256).max);
        // wrapper.deposit{value: 0.1 ether}(
        //     wrapper.ETH(),
        //     0.1 ether,
        //     address(vault),
        //     deployer,
        //     deployer
        // );
        // vault.rebalance();

        // address[] memory holders = new address[](1);
        // holders[0] = deployer;

        // (address symbioticVault, , ) = IVaultConfigurator(0xD2191FE92987171691d552C219b8caEf186eb9cA).create(
        //     IVaultConfigurator.InitParams({
        //         version: 1,
        //         owner: deployer,
        //         vaultParams: abi.encode(
        //             ISymbioticVault.InitParams({
        //                 collateral: Constants.HOLESKY_WSTETH,
        //                 burner: address(0),
        //                 epochDuration: 1 hours,
        //                 depositWhitelist: false,
        //                 isDepositLimit: false,
        //                 depositLimit: 0,
        //                 defaultAdminRoleHolder: deployer,
        //                 depositWhitelistSetRoleHolder: deployer,
        //                 depositorWhitelistRoleHolder: deployer,
        //                 isDepositLimitSetRoleHolder: deployer,
        //                 depositLimitSetRoleHolder: deployer
        //             })
        //         ),
        //         delegatorIndex: 0,
        //         delegatorParams: abi.encode(
        //             IFullRestakeDelegator.InitParams({
        //                 baseParams: IBaseDelegator.BaseParams({
        //                    defaultAdminRoleHolder: deployer,
        //                    hook: address(0),
        //                     hookSetRoleHolder: deployer
        //                 }),
        //                 networkLimitSetRoleHolders: holders,
        //                 operatorNetworkLimitSetRoleHolders: holders
        //             })
        //         ),
        //         withSlasher: false,
        //         slasherIndex: 0,
        //         slasherParams: new bytes(0)
        //     })
        // );

        // vault.addSubvault(symbioticVault, IMultiVaultStorage.Protocol.SYMBIOTIC);

        // vm.stopBroadcast();
    }
}
