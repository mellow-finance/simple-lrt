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
    uint256 public migrations = 0;

    /// @inheritdoc IMigrator
    mapping(address vault => uint256) public timestamps;

    mapping(address vault => Parameters) private _migration;
    mapping(address vault => IMellowSymbioticVault.InitParams) private _vaultInitParams;

    /**
     * @notice Constructor to initialize the Migrator contract with the required parameters.
     * @param singleton_ The address of the singleton MellowSymbioticVault contract.
     * @param symbioticVaultConfigurator_ The address of the Symbiotic Vault configurator.
     * @param admin_ The address of the admin managing the migration process.
     * @param migrationDelay_ The delay period before a migration can be processed.
     */
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
    function migration(address vault) external view returns (Parameters memory) {
        return _migration[vault];
    }

    /// @inheritdoc IMigrator
    function vaultInitParams(address vault)
        external
        view
        returns (IMellowSymbioticVault.InitParams memory)
    {
        return _vaultInitParams[vault];
    }

    /// @inheritdoc IMigrator
    function stageMigration(
        address defaultBondStrategy,
        address vaultAdmin,
        address proxyAdmin,
        address proxyAdminOwner,
        address symbioticVault
    ) external {
        require(msg.sender == admin, "Migrator: not admin");

        address vault = IDefaultBondStrategy(defaultBondStrategy).vault();
        require(timestamps[vault] == 0, "Migrator: migration already staged");

        address token = IMellowLRT(vault).underlyingTokens()[0];
        // Retrieve bond data and ensure valid bond address
        bytes memory bonds = IDefaultBondStrategy(defaultBondStrategy).tokenToData(token);
        IDefaultBondStrategy.Data[] memory data = abi.decode(bonds, (IDefaultBondStrategy.Data[]));
        require(data.length == 1, "Invalid bonds length");
        address bond = data[0].bond;
        require(bond != address(0), "Invalid bond address");

        // Store migration parameters
        Parameters memory params = Parameters({
            vault: vault,
            token: token,
            bond: bond,
            defaultBondStrategy: defaultBondStrategy,
            proxyAdmin: proxyAdmin,
            proxyAdminOwner: proxyAdminOwner
        });
        _checkParams(params);

        _migration[vault] = params;
        // Set vault initialization parameters
        _vaultInitParams[vault] = IMellowSymbioticVault.InitParams({
            limit: IMellowLRT(vault).configurator().maximalTotalSupply(),
            symbioticVault: symbioticVault,
            withdrawalQueue: address(new SymbioticWithdrawalQueue(vault, symbioticVault)),
            admin: vaultAdmin,
            depositPause: false,
            withdrawalPause: false,
            depositWhitelist: false,
            name: IERC20Metadata(vault).name(),
            symbol: IERC20Metadata(vault).symbol()
        });
        timestamps[vault] = block.timestamp;
    }

    /// @inheritdoc IMigrator
    function cancelMigration(address vault) external {
        require(msg.sender == admin, "Migrator: not admin");
        delete _migration[vault];
        delete timestamps[vault];
        delete _vaultInitParams[vault];
    }

    /// @inheritdoc IMigrator
    function migrate(address vault) external {
        require(msg.sender == admin, "Migrator: not admin");
        require(
            timestamps[vault] != 0 && timestamps[vault] + migrationDelay <= block.timestamp,
            "Migrator: migration delay not passed"
        );
        _migrate(vault);
        delete _migration[vault];
        delete timestamps[vault];
        delete _vaultInitParams[vault];
    }

    /**
     * @notice Validates the migration parameters to ensure that the strategy, bond, and vault token are consistent.
     * @param params The migration parameters containing details of the vault, bond, and strategy.
     *
     * @dev This function checks:
     * - That the vault specified in the bond strategy matches the vault in the parameters.
     * - That the bond's underlying asset matches the expected token.
     * - That the vault contains exactly one underlying token, which matches the expected token.
     */
    function _checkParams(Parameters memory params) internal view {
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
    }

    /**
     * @notice Verifies that the Migrator contract has the necessary permissions for the migration.
     * @param params The migration parameters containing addresses for the proxy admin, vault, and strategy.
     *
     * @dev This function checks:
     * - That the Migrator is the owner of the ProxyAdmin contract.
     * - That the Migrator has the `ADMIN_ROLE` for both the vault and the bond strategy.
     * - That the Migrator has permission to perform a delegate call on the vault.
     */
    function _checkPermissions(Parameters memory params) internal view {
        address this_ = address(this);

        // Ensure Migrator owns the ProxyAdmin contract
        require(
            ProxyAdmin(params.proxyAdmin).owner() == this_, "Migrator: ProxyAdmin owner mismatch"
        );

        // Check that Migrator has the admin role for the vault and strategy
        bytes32 ADMIN_ROLE = keccak256("admin");
        require(
            IAccessControlEnumerable(params.vault).hasRole(ADMIN_ROLE, this_),
            "Migrator: Vault admin mismatch"
        );
        require(
            IAccessControlEnumerable(params.defaultBondStrategy).hasRole(ADMIN_ROLE, this_),
            "Migrator: Strategy admin mismatch"
        );

        // Ensure the Migrator has delegate call permissions for the vault
        require(
            IMellowLRT(params.vault).configurator().validator().hasPermission(
                this_, params.vault, IMellowLRT.delegateCall.selector
            ),
            "Migrator: Vault delegateCall permission missing"
        );
    }

    /**
     * @notice Executes the migration process for the specified migration index.
     * @param vault Address of the vault to migrate.
     *
     * @dev This function:
     * - Validates the migration parameters and permissions.
     * - Processes all strategies in the bond strategy.
     * - Withdraws the full balance from the bond via a delegate call.
     * - Upgrades the vault to the new implementation and initializes it with the new parameters.
     * - Transfers ownership of the ProxyAdmin contract to the new owner.
     */
    function _migrate(address vault) internal {
        Parameters memory params = _migration[vault];

        // Check migration parameters and permissions
        _checkParams(params);
        _checkPermissions(params);

        // Retrieve initialization parameters for the new vault
        IMellowSymbioticVault.InitParams memory initParams = _vaultInitParams[vault];

        // Process all bond strategies and withdraw collateral from the bond
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

        // Upgrade the vault and initialize it with the new parameters
        ProxyAdmin(params.proxyAdmin).upgradeAndCall(
            ITransparentUpgradeableProxy(params.vault),
            singleton,
            abi.encodeWithSelector(IMellowSymbioticVault.initialize.selector, initParams)
        );

        // Transfer ownership of the ProxyAdmin to the new owner
        ProxyAdmin(params.proxyAdmin).transferOwnership(params.proxyAdminOwner);
    }

    function reassignProxyAdmin(address vault) external {
        require(msg.sender == admin, "Migrator: not admin");
        require(
            timestamps[vault] != 0 && timestamps[vault] + migrationDelay <= block.timestamp,
            "Migrator: migration delay not passed"
        );
        Parameters memory params = _migration[vault];
        ProxyAdmin(params.proxyAdmin).transferOwnership(params.proxyAdminOwner);
        delete _migration[vault];
        delete timestamps[vault];
        delete _vaultInitParams[vault];
    }
}
