// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import "./SymbioticWithdrawalQueue.sol";
import "./interfaces/utils/IMigrator.sol";

contract Migrator is IMigrator {
    /// @inheritdoc IMigrator
    address public immutable singleton;
    /// @inheritdoc IMigrator
    address public immutable symbioticVaultConfigurator;
    /// @inheritdoc IMigrator
    address public immutable admin;
    /// @inheritdoc IMigrator
    uint256 public immutable migrationDelay;
    /// @inheritdoc IMigrator

    /// @inheritdoc IMigrator
    uint256 public migrations = 0;
    mapping(uint256 migrationIndex => Parameters) private _migration;
    mapping(uint256 migrationIndex => uint256 timestamp) private timestamps;

    constructor(
        address singleton_,
        address symbioticVaultConfigurator_,
        address admin_,
        uint256 migrationDelay_
    ) {
        singleton = singleton_;
        symbioticVaultConfigurator = symbioticVaultConfigurator_;
        admin = admin_;
        migrationDelay = migrationDelay_;
    }

    /// @inheritdoc IMigrator
    function stagedMigrations(uint256 index) external view returns (Parameters memory) {
        return _migration[index];
    }

    /// @inheritdoc IMigrator
    function stageMigration(
        address defaultBondStrategy,
        address proxyAdmin,
        address proxyAdminOwner,
        IMellowSymbioticVault.InitParams memory initParams,
        IVaultConfigurator.InitParams memory symbioticVaultParams
    ) external returns (uint256 migrationIndex) {
        require(msg.sender == admin, "Migrator: not admin");
        address vault = IDefaultBondStrategy(defaultBondStrategy).vault();
        address token = IMellowLRT(vault).underlyingTokens()[0];
        bytes memory bonds = IDefaultBondStrategy(defaultBondStrategy).tokenToData(token);
        IDefaultBondStrategy.Data[] memory data = abi.decode(bonds, (IDefaultBondStrategy.Data[]));
        require(data.length == 1, "Invalid bonds length");
        address bond = data[0].bond;
        require(bond != address(0), "Invalid bond address");
        Parameters memory params = Parameters({
            vault: vault,
            token: token,
            bond: bond,
            defaultBondStrategy: defaultBondStrategy,
            proxyAdmin: proxyAdmin,
            proxyAdminOwner: proxyAdminOwner,
            initParams: initParams,
            symbioticVaultParams: symbioticVaultParams
        });
        _checkParams(params);
        migrationIndex = migrations++;
        _migration[migrationIndex] = params;
        timestamps[migrationIndex] = block.timestamp;
    }

    /// @inheritdoc IMigrator
    function cancelMigration(uint256 migrationIndex) external {
        require(msg.sender == admin, "Migrator: not admin");
        delete _migration[migrationIndex];
        delete timestamps[migrationIndex];
    }

    /// @inheritdoc IMigrator
    function migrate(uint256 migrationIndex) external {
        require(msg.sender == admin, "Migrator: not admin"); // should it be removed?
        require(
            timestamps[migrationIndex] != 0
                && timestamps[migrationIndex] + migrationDelay <= block.timestamp,
            "Migrator: migration delay not passed"
        );

        Parameters memory params = _migration[migrationIndex];
        _checkParams(params);
        _checkPermissions(params);
        _migrate(params);

        delete _migration[migrationIndex];
        delete timestamps[migrationIndex];
    }

    /**
     * @notice Checks correctness of parameters `params`.
     * @param params Checking parameters.
     */
    function _checkParams(Parameters memory params) internal view {
        require(params.initParams.withdrawalQueue == address(0), "non-zero withdrawalQueue");
        require(
            IDefaultBondStrategy(params.defaultBondStrategy).vault() == params.vault,
            "Invalid strategy contract"
        );
        require(IDefaultBond(params.bond).asset() == params.token, "Invalid bond asset");

        address[] memory underlyingTokens = IMellowLRT(params.vault).underlyingTokens();
        require(
            underlyingTokens.length == 1 && underlyingTokens[0] == params.token,
            "Invalid vault token"
        );
        if (params.initParams.symbioticVault == address(0)) {
            require(
                params.symbioticVaultParams.vaultParams.collateral == params.token,
                "Invalid symbioticVault collateral"
            );
        }
    }

    /**
     * @notice Checks necessary permissions for migration process.
     * @param params Checking parameters.
     */
    function _checkPermissions(Parameters memory params) internal view {
        address this_ = address(this);
        require(
            ProxyAdmin(params.proxyAdmin).owner() == this_, "Migrator: ProxyAdmin owner mismatch"
        );
        bytes32 ADMIN_ROLE = keccak256("admin");
        require(
            IAccessControlEnumerable(params.vault).hasRole(ADMIN_ROLE, this_),
            "Migrator: Vault admin mismatch"
        );

        require(
            IAccessControlEnumerable(params.defaultBondStrategy).hasRole(ADMIN_ROLE, this_),
            "Migrator: Strategy admin mismatch"
        );

        require(
            IMellowLRT(params.vault).configurator().validator().hasPermission(
                this_, params.vault, IMellowLRT.delegateCall.selector
            ),
            "Migrator: Vault delegateCall permission missing"
        );
    }

    /**
     * @notice Migrates staged migration with `migrationIndex`
     * @param migrationIndex Index of staged migration.
     */
    function _migrate(Parameters memory params) internal {
        IDefaultBondStrategy strategy = IDefaultBondStrategy(params.defaultBondStrategy);
        strategy.processAll();
        address bondModule = strategy.bondModule();
        (bool success,) = IMellowLRT(params.vault).delegateCall(
            bondModule,
            abi.encodeWithSelector(
                IDefaultBondModule.withdraw.selector, params.bond, type(uint256).max
            )
        );
        require(success, "Migrator: DefaultCollateral withdraw failed");

        if (params.initParams.symbioticVault == address(0)) {
            (params.initParams.symbioticVault,,) =
                IVaultConfigurator(symbioticVaultConfigurator).create(params.symbioticVaultParams);
        }

        params.initParams.withdrawalQueue =
            address(new SymbioticWithdrawalQueue(params.vault, params.initParams.symbioticVault));

        ProxyAdmin(params.proxyAdmin).upgradeAndCall(
            ITransparentUpgradeableProxy(params.vault),
            singleton,
            abi.encodeWithSelector(IMellowSymbioticVault.initialize.selector, params.initParams)
        );
        ProxyAdmin(params.proxyAdmin).transferOwnership(params.proxyAdminOwner);
    }
}
