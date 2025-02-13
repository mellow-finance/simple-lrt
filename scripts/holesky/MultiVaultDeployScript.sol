// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../src/adapters/SymbioticAdapter.sol";
import "../../src/strategies/RatiosStrategy.sol";
import "../../src/vaults/MultiVault.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract MultiVaultDeployScript {
    address public immutable symbioticVaultFactory;

    constructor(address symbioticVaultFactory_) {
        symbioticVaultFactory = symbioticVaultFactory_;
    }

    struct DeployParams {
        address singleton;
        address symbioticWithdrawalQueueSingleton;
        address symbioticVault;
        address admin;
        address proxyAdmin;
        address curator;
        bool isWhitelistedWrapper;
        address ethWrapper;
        IRatiosStrategy.Ratio ratio;
        IMultiVault.InitParams initParams;
        bytes32 salt;
    }

    function calculateSalt(DeployParams memory params) public pure returns (bytes32 salt) {
        salt = keccak256(
            bytes.concat(
                abi.encodePacked(
                    params.initParams.admin,
                    params.initParams.limit,
                    params.initParams.depositPause,
                    params.initParams.withdrawalPause,
                    params.initParams.depositWhitelist,
                    params.initParams.asset,
                    params.initParams.name,
                    params.initParams.symbol
                ),
                abi.encodePacked(
                    params.initParams.depositStrategy,
                    params.initParams.withdrawalStrategy,
                    params.initParams.rebalanceStrategy,
                    params.initParams.defaultCollateral,
                    params.initParams.symbioticAdapter,
                    params.initParams.eigenLayerAdapter,
                    params.initParams.erc4626Adapter
                ),
                abi.encodePacked(
                    params.singleton,
                    params.symbioticWithdrawalQueueSingleton,
                    params.symbioticVault,
                    params.admin,
                    params.proxyAdmin,
                    params.curator,
                    params.isWhitelistedWrapper,
                    params.ethWrapper,
                    params.ratio.minRatioD18,
                    params.ratio.maxRatioD18,
                    params.salt
                )
            )
        );
    }

    function deploy(DeployParams memory params)
        external
        returns (MultiVault multiVault, address symbioticAdapter)
    {
        bytes32 salt = calculateSalt(params);
        multiVault = MultiVault(
            address(
                new TransparentUpgradeableProxy{salt: salt}(
                    address(params.singleton), params.proxyAdmin, new bytes(0)
                )
            )
        );

        symbioticAdapter = address(
            new SymbioticAdapter{salt: salt}(
                address(multiVault),
                symbioticVaultFactory,
                params.symbioticWithdrawalQueueSingleton,
                params.proxyAdmin
            )
        );

        params.initParams.admin = address(this);
        params.initParams.symbioticAdapter = symbioticAdapter;

        if (params.isWhitelistedWrapper) {
            params.initParams.depositWhitelist = true;
            multiVault.initialize(params.initParams);
            multiVault.grantRole(keccak256("SET_DEPOSITOR_WHITELIST_STATUS_ROLE"), address(this));
            multiVault.setDepositorWhitelistStatus(params.ethWrapper, true);
            multiVault.renounceRole(keccak256("SET_DEPOSITOR_WHITELIST_STATUS_ROLE"), address(this));
        } else {
            multiVault.initialize(params.initParams);
        }

        multiVault.grantRole(multiVault.DEFAULT_ADMIN_ROLE(), params.admin);
        multiVault.grantRole(multiVault.REBALANCE_ROLE(), params.curator);
        multiVault.grantRole(multiVault.SET_FARM_ROLE(), params.admin);
        multiVault.grantRole(
            RatiosStrategy(params.initParams.depositStrategy).RATIOS_STRATEGY_SET_RATIOS_ROLE(),
            params.curator
        );
        multiVault.grantRole(
            RatiosStrategy(params.initParams.depositStrategy).RATIOS_STRATEGY_SET_RATIOS_ROLE(),
            address(this)
        );

        multiVault.grantRole(multiVault.ADD_SUBVAULT_ROLE(), address(this));
        multiVault.addSubvault(params.symbioticVault, IMultiVaultStorage.Protocol.SYMBIOTIC);
        require(multiVault.subvaultAt(0).vault == params.symbioticVault, "subvault not added");

        address[] memory subvaults = new address[](1);
        subvaults[0] = address(params.symbioticVault);
        IRatiosStrategy.Ratio[] memory ratios_ = new IRatiosStrategy.Ratio[](1);
        ratios_[0] = params.ratio;
        RatiosStrategy(params.initParams.depositStrategy).setRatios(
            address(multiVault), subvaults, ratios_
        );

        multiVault.renounceRole(
            RatiosStrategy(params.initParams.depositStrategy).RATIOS_STRATEGY_SET_RATIOS_ROLE(),
            address(this)
        );
        multiVault.renounceRole(multiVault.ADD_SUBVAULT_ROLE(), address(this));
        multiVault.renounceRole(multiVault.DEFAULT_ADMIN_ROLE(), address(this));
    }
}
