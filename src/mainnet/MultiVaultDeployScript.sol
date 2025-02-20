// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../src/adapters/SymbioticAdapter.sol";
import "../../src/strategies/RatiosStrategy.sol";
import "../../src/vaults/MultiVault.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract MultiVaultDeployScript {
    address public immutable symbioticVaultFactory;
    RatiosStrategy public immutable strategy;
    address public immutable multiVaultImplementation;
    address public immutable symbioticWithdrawalQueueImplementation;

    constructor(
        address symbioticVaultFactory_,
        address strategy_,
        address multiVaultImplementation_,
        address symbioticWithdrawalQueueImplementation_
    ) {
        symbioticVaultFactory = symbioticVaultFactory_;
        strategy = RatiosStrategy(strategy_);
        multiVaultImplementation = multiVaultImplementation_;
        symbioticWithdrawalQueueImplementation = symbioticWithdrawalQueueImplementation_;
    }

    struct DeployParams {
        // actors
        address admin;
        address proxyAdmin;
        address curator;
        // external contracts
        address symbioticVault;
        address depositWrapper;
        address asset;
        address defaultCollateral;
        // vault setup
        uint256 limit;
        bool depositPause;
        bool withdrawalPause;
        string name;
        string symbol;
        // strategy setup
        uint64 minRatioD18;
        uint64 maxRatioD18;
        // salt
        bytes32 salt;
    }

    struct Deployment {
        address multiVault;
        address symbioticAdapter;
        DeployParams params;
    }

    mapping(bytes32 salt => Deployment) private _deployments;

    function calculateSalt(DeployParams calldata params) public pure returns (bytes32) {
        return keccak256(abi.encode(params));
    }

    function deployments(bytes32 salt) public view returns (Deployment memory) {
        return _deployments[salt];
    }

    function deploy(DeployParams calldata params)
        external
        returns (MultiVault multiVault, address symbioticAdapter, DeployParams memory)
    {
        bytes32 salt = calculateSalt(params);
        multiVault = MultiVault(
            address(
                new TransparentUpgradeableProxy{salt: salt}(
                    multiVaultImplementation, params.proxyAdmin, new bytes(0)
                )
            )
        );

        address symbioticAdapterImplementation = address(
            new SymbioticAdapter{salt: salt}(
                address(multiVault),
                symbioticVaultFactory,
                symbioticWithdrawalQueueImplementation,
                params.proxyAdmin
            )
        );

        symbioticAdapter = address(
            new TransparentUpgradeableProxy{salt: salt}(
                symbioticAdapterImplementation, params.proxyAdmin, new bytes(0)
            )
        );

        IMultiVault.InitParams memory initParams = IMultiVault.InitParams({
            admin: address(this),
            limit: params.limit,
            depositPause: params.depositPause,
            withdrawalPause: params.withdrawalPause,
            depositWhitelist: params.depositWrapper != address(0),
            asset: params.asset,
            name: params.name,
            symbol: params.symbol,
            depositStrategy: address(strategy),
            withdrawalStrategy: address(strategy),
            rebalanceStrategy: address(strategy),
            defaultCollateral: params.defaultCollateral,
            symbioticAdapter: symbioticAdapter,
            eigenLayerAdapter: address(0),
            erc4626Adapter: address(0)
        });

        multiVault.initialize(initParams);

        if (params.depositWrapper != address(0)) {
            bytes32 SET_DEPOSITOR_WHITELIST_STATUS_ROLE =
                keccak256("SET_DEPOSITOR_WHITELIST_STATUS_ROLE");
            multiVault.grantRole(SET_DEPOSITOR_WHITELIST_STATUS_ROLE, address(this));
            multiVault.setDepositorWhitelistStatus(params.depositWrapper, true);
            multiVault.renounceRole(SET_DEPOSITOR_WHITELIST_STATUS_ROLE, address(this));
        }

        // admin roles
        multiVault.grantRole(multiVault.DEFAULT_ADMIN_ROLE(), params.admin);
        multiVault.grantRole(multiVault.SET_FARM_ROLE(), params.admin);

        // curator roles
        multiVault.grantRole(multiVault.REBALANCE_ROLE(), params.curator);
        multiVault.grantRole(multiVault.ADD_SUBVAULT_ROLE(), params.curator);
        multiVault.grantRole(keccak256("SET_LIMIT_ROLE"), params.curator);
        multiVault.grantRole(strategy.RATIOS_STRATEGY_SET_RATIOS_ROLE(), params.curator);

        if (params.symbioticVault != address(0)) {
            multiVault.grantRole(strategy.RATIOS_STRATEGY_SET_RATIOS_ROLE(), address(this));
            multiVault.grantRole(multiVault.ADD_SUBVAULT_ROLE(), address(this));
            multiVault.addSubvault(params.symbioticVault, IMultiVaultStorage.Protocol.SYMBIOTIC);

            address[] memory subvaults = new address[](1);
            subvaults[0] = address(params.symbioticVault);

            IRatiosStrategy.Ratio[] memory ratios_ = new IRatiosStrategy.Ratio[](1);
            ratios_[0] = IRatiosStrategy.Ratio(params.minRatioD18, params.maxRatioD18);

            strategy.setRatios(address(multiVault), subvaults, ratios_);
            multiVault.renounceRole(strategy.RATIOS_STRATEGY_SET_RATIOS_ROLE(), address(this));
            multiVault.renounceRole(multiVault.ADD_SUBVAULT_ROLE(), address(this));
        }
        multiVault.renounceRole(multiVault.DEFAULT_ADMIN_ROLE(), address(this));

        emit Deployed(address(multiVault), symbioticAdapter, salt, params);
        _deployments[salt] = Deployment(address(multiVault), symbioticAdapter, params);
        return (multiVault, symbioticAdapter, params);
    }

    event Deployed(
        address indexed multiVault,
        address indexed symbioticAdapter,
        bytes32 indexed salt,
        DeployParams deployParams
    );
}
