// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../src/strategies/RatiosStrategy.sol";
import "../../src/vaults/MultiVault.sol";
import "./libraries/AbstractDeployLibrary.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract AbstractDeployScript is Ownable {
    struct Config {
        // actors
        address vaultAdmin;
        address vaultProxyAdmin;
        address curator;
        // external contracts
        address asset;
        address defaultCollateral;
        address depositWrapper;
        // vault setup
        uint256 limit;
        bool depositPause;
        bool withdrawalPause;
        string name;
        string symbol;
    }

    struct SubvaultParams {
        uint256 libraryIndex;
        bytes data;
        uint64 minRatioD18;
        uint64 maxRatioD18;
    }

    struct DeployParams {
        Config config;
        SubvaultParams[] subvaults;
        // initial deposit params
        address initialDepositAsset;
        uint256 initialDepositAmount;
        // salt
        bytes32 salt;
    }

    address public immutable strategy;
    address public immutable multiVaultImplementation;

    mapping(uint256 => address) public deployLibraries;
    mapping(uint256 index => address multiVault) public deployments;
    mapping(uint256 index => DeployParams) public deployParams;
    uint256 public deploymentsCount = 0;

    constructor(
        address strategy_,
        address multiVaultImplementation_,
        address[] memory deployLibraries_,
        address owner
    ) Ownable(owner) {
        strategy = strategy_;
        multiVaultImplementation = multiVaultImplementation_;
        for (uint256 i = 0; i < deployLibraries_.length; i++) {
            deployLibraries[i] = deployLibraries_[i];
        }
    }

    // View functions

    function calculateSalt(DeployParams calldata params) public pure returns (bytes32) {
        return keccak256(abi.encode(params));
    }

    // Mutable functions

    function setDeployLibrary(uint256 index, address deployLibrary) external onlyOwner {
        deployLibraries[index] = deployLibrary;
    }

    function deploy(DeployParams calldata params) external returns (MultiVault multiVault) {
        bytes32 salt = calculateSalt(params);
        Config calldata config = params.config;
        multiVault = MultiVault(
            address(
                new TransparentUpgradeableProxy{salt: salt}(
                    multiVaultImplementation, config.vaultProxyAdmin, new bytes(0)
                )
            )
        );

        multiVault.initialize(
            IMultiVault.InitParams({
                admin: address(this),
                limit: config.limit,
                depositPause: config.depositPause,
                withdrawalPause: config.withdrawalPause,
                depositWhitelist: config.depositWrapper != address(0),
                asset: config.asset,
                name: config.name,
                symbol: config.symbol,
                depositStrategy: strategy,
                withdrawalStrategy: strategy,
                rebalanceStrategy: strategy,
                defaultCollateral: config.defaultCollateral,
                symbioticAdapter: address(0),
                eigenLayerAdapter: address(0),
                erc4626Adapter: address(0)
            })
        );

        if (config.depositWrapper != address(0)) {
            bytes32 SET_DEPOSITOR_WHITELIST_STATUS_ROLE =
                keccak256("SET_DEPOSITOR_WHITELIST_STATUS_ROLE");
            multiVault.grantRole(SET_DEPOSITOR_WHITELIST_STATUS_ROLE, address(this));
            multiVault.setDepositorWhitelistStatus(config.depositWrapper, true);
            multiVault.renounceRole(SET_DEPOSITOR_WHITELIST_STATUS_ROLE, address(this));
        }

        // admin roles
        multiVault.grantRole(multiVault.DEFAULT_ADMIN_ROLE(), config.vaultAdmin);
        multiVault.grantRole(multiVault.SET_FARM_ROLE(), config.vaultAdmin);

        // curator roles
        multiVault.grantRole(multiVault.REBALANCE_ROLE(), config.curator);
        multiVault.grantRole(multiVault.ADD_SUBVAULT_ROLE(), config.curator);
        multiVault.grantRole(keccak256("SET_LIMIT_ROLE"), config.curator);
        multiVault.grantRole(
            RatiosStrategy(strategy).RATIOS_STRATEGY_SET_RATIOS_ROLE(), config.curator
        );

        if (params.subvaults.length != 0) {
            multiVault.grantRole(
                RatiosStrategy(strategy).RATIOS_STRATEGY_SET_RATIOS_ROLE(), address(this)
            );
            multiVault.grantRole(multiVault.ADD_SUBVAULT_ROLE(), address(this));

            uint256 n = params.subvaults.length;
            IRatiosStrategy.Ratio[] memory ratios = new IRatiosStrategy.Ratio[](n);
            address[] memory subvaults = new address[](n);

            for (uint256 i = 0; i < params.subvaults.length; i++) {
                SubvaultParams calldata subvaultParams = params.subvaults[i];
                address deployLibrary = deployLibraries[uint256(subvaultParams.libraryIndex)];
                if (deployLibrary == address(0)) {
                    revert("AbstractDeployScript: unsupported protocol type");
                }
                Address.functionDelegateCall(
                    deployLibrary,
                    abi.encodeCall(
                        AbstractDeployLibrary.deployAndSetAdapter,
                        (address(multiVault), config, subvaultParams.data)
                    )
                );

                bytes memory subvaultResponse = Address.functionDelegateCall(
                    deployLibrary,
                    abi.encodeCall(
                        AbstractDeployLibrary.deploySubvault,
                        (address(multiVault), config, subvaultParams.data)
                    )
                );

                if (subvaultResponse.length != 0x20) {
                    revert("AbstractDeployScript: deploy failed");
                }

                address subvault = abi.decode(subvaultResponse, (address));
                multiVault.addSubvault(
                    subvault,
                    IMultiVaultStorage.Protocol(AbstractDeployLibrary(deployLibrary).subvaultType())
                );

                ratios[i] = IRatiosStrategy.Ratio(
                    params.subvaults[i].minRatioD18, params.subvaults[i].maxRatioD18
                );
            }

            RatiosStrategy(strategy).setRatios(address(multiVault), subvaults, ratios);
            multiVault.renounceRole(
                RatiosStrategy(strategy).RATIOS_STRATEGY_SET_RATIOS_ROLE(), address(this)
            );
            multiVault.renounceRole(multiVault.ADD_SUBVAULT_ROLE(), address(this));
        }
        multiVault.renounceRole(multiVault.DEFAULT_ADMIN_ROLE(), address(this));

        uint256 index = deploymentsCount++;
        deployments[index] = address(multiVault);
        deployParams[index] = params;
    }
}
