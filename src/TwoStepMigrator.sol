// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import "./SymbioticWithdrawalQueue.sol";
import "./interfaces/utils/IMigrator.sol";

contract TwoStepMigrator is IMigrator {
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

    mapping(uint256 migrationIndex => Parameters) public migration;
    mapping(uint256 migrationIndex => uint256 timestamp) public timestamps;
    mapping(uint256 migrationIndex => IMellowSymbioticVault.InitParams) public vaultInitParams;

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
    function stageMigration(
        address defaultBondStrategy,
        address vaultAdmin,
        address proxyAdmin,
        address proxyAdminOwner,
        address symbioticVault
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
            proxyAdminOwner: proxyAdminOwner
        });
        _checkParams(params);
        migrationIndex = migrations++;
        migration[migrationIndex] = params;

        vaultInitParams[migrationIndex] = IMellowSymbioticVault.InitParams({
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

        timestamps[migrationIndex] = block.timestamp;
    }

    /// @inheritdoc IMigrator
    function cancelMigration(uint256 migrationIndex) external {
        require(msg.sender == admin, "Migrator: not admin");
        delete migration[migrationIndex];
        delete vaultInitParams[migrationIndex];
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
        _migrate(migrationIndex);
        delete timestamps[migrationIndex];
    }

    /**
     * @notice Validates the migration parameters to ensure the strategy, bond, and vault token are consistent.
     * @param params The migration parameters containing details of the vault, bond, and strategy.
     *
     * @dev This function checks:
     * - The vault associated with the bond strategy matches the expected vault.
     * - The bond's underlying asset matches the expected token.
     * - The vault contains exactly one underlying token, and it matches the expected token.
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
     * @notice Ensures the Migrator contract has the necessary permissions to perform the migration.
     * @param params The migration parameters containing the vault and strategy details.
     *
     * @dev This function checks:
     * - The Migrator has the `ADMIN_ROLE` for the vault and the default bond strategy.
     * - The Migrator has permission to perform delegate calls on the vault.
     */
    function _checkPermissions(Parameters memory params) internal view {
        address this_ = address(this);
        bytes32 ADMIN_ROLE = keccak256("admin");

        // Check if Migrator has the admin role for the vault
        require(
            IAccessControlEnumerable(params.vault).hasRole(ADMIN_ROLE, this_),
            "Migrator: Vault admin mismatch"
        );

        // Check if Migrator has the admin role for the bond strategy
        require(
            IAccessControlEnumerable(params.defaultBondStrategy).hasRole(ADMIN_ROLE, this_),
            "Migrator: Strategy admin mismatch"
        );

        // Ensure Migrator has permission to perform delegate calls on the vault
        require(
            IMellowLRT(params.vault).configurator().validator().hasPermission(
                this_, params.vault, IMellowLRT.delegateCall.selector
            ),
            "Migrator: Vault delegateCall permission missing"
        );
    }

    /**
     * @notice Executes the migration process for a given migration index.
     * @param migrationIndex The index of the migration to be processed.
     *
     * @dev This function performs the following steps:
     * - Validates the migration parameters using `_checkParams`.
     * - Ensures the Migrator has the necessary permissions using `_checkPermissions`.
     * - Processes all bonds in the bond strategy using `processAll`.
     * - Performs a delegate call to the bond module to withdraw the maximum amount of collateral from the bond.
     * - Ensures the withdrawal is successful; if not, it reverts with an error message.
     */
    function _migrate(uint256 migrationIndex) internal {
        Parameters memory params = migration[migrationIndex];

        // Validate migration parameters and permissions
        _checkParams(params);
        _checkPermissions(params);

        // Process all bond strategies and withdraw collateral
        IDefaultBondStrategy strategy = IDefaultBondStrategy(params.defaultBondStrategy);
        strategy.processAll();
        address bondModule = strategy.bondModule();

        // Delegate call to withdraw collateral from the bond module
        (bool success,) = IMellowLRT(params.vault).delegateCall(
            bondModule,
            abi.encodeWithSelector(
                IDefaultBondModule.withdraw.selector, params.bond, type(uint256).max
            )
        );
        require(success, "Migrator: DefaultCollateral withdraw failed");
    }

    /**
     * @notice Initializes the vault with the stored initialization parameters for a given migration.
     * @param migrationIndex The index of the migration whose vault will be initialized.
     *
     * @dev This function:
     * - Ensures that only the admin can call it.
     * - Initializes the vault with the stored initialization parameters using `initialize`.
     * - Cleans up the stored vault initialization parameters and migration data after initialization.
     */
    function initializeVault(uint256 migrationIndex) external {
        require(msg.sender == admin, "Migrator: not admin");

        // Initialize the vault with the stored parameters
        IMellowSymbioticVault(migration[migrationIndex].vault).initialize(
            vaultInitParams[migrationIndex]
        );

        // Cleanup stored initialization parameters and migration data
        delete vaultInitParams[migrationIndex];
        delete migration[migrationIndex];
    }
}
