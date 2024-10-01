// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import "./SymbioticWithdrawalQueue.sol";
import "./interfaces/utils/IMigrator.sol";

contract Migrator is IMigrator {
    mapping(address vault => bool) private _isEntity;
    address[] private _entities;

    /// @inheritdoc IMigrator
    address public immutable singleton;
    /// @inheritdoc IMigrator
    address public immutable admin;
    /// @inheritdoc IMigrator
    uint256 public immutable migrationDelay;

    /// @inheritdoc IMigrator
    mapping(address vault => uint256) public timestamps;

    mapping(address vault => Parameters) private _migration;
    mapping(address vault => IMellowSymbioticVault.InitParams) private _vaultInitParams;

    /**
     * @notice Constructor to initialize the Migrator contract.
     * @param singleton_ The address of the singleton MellowSymbioticVault contract.
     * @param admin_ The address of the admin responsible for migration operations.
     * @param migrationDelay_ The delay in seconds before a migration can be finalized.
     */
    constructor(address singleton_, address admin_, uint256 migrationDelay_) {
        singleton = singleton_;
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

    /**
     * @notice Stages a migration for a vault.
     * @param defaultBondStrategy The default bond strategy to be used for the migration.
     * @param vaultAdmin The admin address responsible for the vault.
     * @param proxyAdmin The proxy admin address managing the upgradeable vault proxy.
     * @param symbioticVault The address of the new SymbioticVault to migrate to.
     */
    function stageMigration(
        address defaultBondStrategy,
        address vaultAdmin,
        address proxyAdmin,
        address symbioticVault
    ) external {
        require(msg.sender == admin, "Migrator: not admin");

        address vault = IDefaultBondStrategy(defaultBondStrategy).vault();
        require(timestamps[vault] == 0, "Migrator: migration already staged");
        require(!isEntity(vault), "Migrator: entity already exists");

        _checkTokens(vault, defaultBondStrategy, symbioticVault);

        address token = IMellowLRT(vault).underlyingTokens()[0];

        // Define and store migration parameters
        Parameters memory params = Parameters({
            token: token,
            bond: abi.decode(
                IDefaultBondStrategy(defaultBondStrategy).tokenToData(token),
                (IDefaultBondStrategy.Data[])
            )[0].bond,
            defaultBondStrategy: defaultBondStrategy,
            proxyAdmin: proxyAdmin,
            proxyAdminOwner: ProxyAdmin(proxyAdmin).owner()
        });
        _checkParams(vault, params);

        _migration[vault] = params;

        // Define and store vault initialization parameters
        _vaultInitParams[vault] = IMellowSymbioticVault.InitParams({
            limit: 0, // Will be set during the migration process
            symbioticCollateral: params.bond,
            symbioticVault: symbioticVault,
            withdrawalQueue: address(new SymbioticWithdrawalQueue(vault, symbioticVault)),
            admin: vaultAdmin,
            depositPause: true, // Pauses deposits initially
            withdrawalPause: true, // Pauses withdrawals initially
            depositWhitelist: false,
            name: IERC20Metadata(vault).name(),
            symbol: IERC20Metadata(vault).symbol()
        });

        timestamps[vault] = block.timestamp; // Record the staging time for the migration
    }

    /**
     * @notice Cancels a previously staged migration.
     * @param vault The address of the vault whose migration is being canceled.
     */
    function cancelMigration(address vault) external {
        require(msg.sender == admin, "Migrator: not admin");
        require(timestamps[vault] != 0, "Migrator: migration not staged");

        Parameters memory params = _migration[vault];
        if (ProxyAdmin(params.proxyAdmin).owner() == address(this)) {
            ProxyAdmin(params.proxyAdmin).transferOwnership(params.proxyAdminOwner);
        }

        delete _migration[vault];
        delete timestamps[vault];
        delete _vaultInitParams[vault];
    }

    /**
     * @notice Finalizes the migration process after the required delay has passed.
     * @param vault The address of the vault to be migrated.
     */
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
     * @notice Validates the migration parameters to ensure consistency between the vault, bond, and strategy.
     * @param params The migration parameters being validated.
     */
    function _checkParams(address vault, Parameters memory params) internal view {
        require(
            IDefaultBondStrategy(params.defaultBondStrategy).vault() == vault,
            "Migrator: Invalid strategy contract"
        );
        require(IDefaultBond(params.bond).asset() == params.token, "Migrator: Invalid bond asset");

        address[] memory underlyingTokens = IMellowLRT(vault).underlyingTokens();
        require(
            underlyingTokens.length == 1 && underlyingTokens[0] == params.token,
            "Migrator: Invalid vault token"
        );

        require(
            IMellowLRT(vault).tvlModules().length == 2,
            "Migrator: Invalid number of TVL modules in the vault"
        );
    }

    /**
     * @notice Ensures that the vault, strategy, and tokens are valid for migration.
     * @param vault The address of the vault being checked.
     * @param defaultBondStrategy The bond strategy for the vault.
     * @param symbioticVault The symbiotic vault to be used in the migration.
     */
    function _checkTokens(address vault, address defaultBondStrategy, address symbioticVault)
        internal
        view
    {
        require(
            IDefaultBondStrategy(defaultBondStrategy).vault() == vault,
            "Migrator: Invalid strategy contract"
        );

        address token = IMellowLRT(vault).underlyingTokens()[0];

        // Ensure valid bond data for migration
        bytes memory bonds = IDefaultBondStrategy(defaultBondStrategy).tokenToData(token);
        IDefaultBondStrategy.Data[] memory data = abi.decode(bonds, (IDefaultBondStrategy.Data[]));
        require(data.length == 1, "Migrator: Invalid bonds length");
        address bond = data[0].bond;
        require(bond != address(0), "Migrator: Invalid bond address");

        require(
            ISymbioticVault(symbioticVault).collateral() == token,
            "Migrator: Invalid symbiotic vault collateral"
        );
    }

    /**
     * @notice Validates that the permissions for migration are correct.
     * @param vault The address of the vault being migrated.
     * @param params The migration parameters for the vault.
     * @param vaultAdmin The admin responsible for the vault.
     */
    function _checkPermissions(address vault, Parameters memory params, address vaultAdmin)
        internal
        view
    {
        address this_ = address(this);

        // Ensure that Migrator owns the ProxyAdmin contract
        require(
            ProxyAdmin(params.proxyAdmin).owner() == this_, "Migrator: ProxyAdmin owner mismatch"
        );

        // Validate that Migrator has the appropriate operator role for the strategy and vault
        bytes32 OPERATOR = keccak256("operator");
        bytes32 ADMIN_ROLE = keccak256("admin");
        require(
            IAccessControlEnumerable(params.defaultBondStrategy).hasRole(OPERATOR, this_),
            "Migrator: Strategy operator mismatch"
        );
        require(
            IAccessControlEnumerable(vault).hasRole(OPERATOR, params.defaultBondStrategy),
            "Migrator: Vault strategy operator mismatch"
        );
        require(
            IAccessControlEnumerable(vault).hasRole(ADMIN_ROLE, vaultAdmin),
            "Migrator: Vault admin mismatch"
        );
    }

    /**
     * @notice Executes the actual migration process for the given vault.
     * @param vault The address of the vault to migrate.
     */
    function _migrate(address vault) internal {
        Parameters memory params = _migration[vault];
        IMellowSymbioticVault.InitParams memory initParams = _vaultInitParams[vault];

        // Validate the parameters and permissions before proceeding
        _checkParams(vault, params);
        _checkTokens(vault, params.defaultBondStrategy, initParams.symbioticVault);
        _checkPermissions(vault, params, initParams.admin);

        // Retrieve vault's total value and set limit for migration
        uint256 maximalTotalSupply = IMellowLRT(vault).configurator().maximalTotalSupply();
        uint256 totalSupply = IERC20(vault).totalSupply();
        uint256 totalValue = 0;
        (address[] memory tokens, uint256[] memory amounts) = IMellowLRT(vault).underlyingTvl();
        require(
            tokens.length == 1 && tokens[0] == params.token && amounts.length == 1
                && amounts[0] != 0,
            "Migrator: Invalid vault underlyingTvl"
        );
        totalValue = amounts[0];
        require(totalSupply != 0, "Migrator: Invalid total supply");
        require(maximalTotalSupply >= totalSupply, "Migrator: Invalid maximal total supply");
        uint256 limit = Math.mulDiv(totalValue, maximalTotalSupply, totalSupply); // Calculate limit in terms of underlying assets
        initParams.limit = limit;

        // Process any pending withdrawals before migration
        IDefaultBondStrategy(params.defaultBondStrategy).processAll();

        // Upgrade the vault and initialize it with the new parameters
        ProxyAdmin(params.proxyAdmin).upgradeAndCall(
            ITransparentUpgradeableProxy(vault),
            singleton,
            abi.encodeWithSelector(IMellowSymbioticVault.initialize.selector, initParams)
        );

        // Transfer ownership of the ProxyAdmin to the designated owner
        ProxyAdmin(params.proxyAdmin).transferOwnership(params.proxyAdminOwner);

        IMellowVaultCompat(vault).pushIntoSymbiotic();

        // Mark the vault as migrated and store it in the list of entities
        _isEntity[vault] = true;
        _entities.push(vault);

        emit EntityCreated(address(vault), block.timestamp);
    }

    /**
     * @notice Returns the list of all vault entities.
     */
    function entities() external view returns (address[] memory) {
        return _entities;
    }

    /**
     * @notice Returns the number of vault entities.
     */
    function entitiesLength() external view returns (uint256) {
        return _entities.length;
    }

    /**
     * @notice Checks if a given address is an entity (vault).
     * @param entity The address to check.
     * @return True if the address is a vault entity, false otherwise.
     */
    function isEntity(address entity) public view returns (bool) {
        return _isEntity[entity];
    }

    /**
     * @notice Returns the vault address at a specific index.
     * @param index The index of the entity.
     * @return The address of the vault at the specified index.
     */
    function entityAt(uint256 index) external view returns (address) {
        return _entities[index];
    }
}
