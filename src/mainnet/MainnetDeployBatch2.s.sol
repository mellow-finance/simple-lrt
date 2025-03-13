// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../src/utils/Claimer.sol";
import "../../src/utils/WhitelistedEthWrapper.sol";
import "./MultiVaultDeployScript.sol";

import {IVault} from "@symbiotic/core/interfaces/vault/IVault.sol";
import "forge-std/Script.sol";

contract Deploy is Script {
    address public constant VAULT_ADMIN_MULTISIG = 0x9437B2a8cF3b69D782a61f9814baAbc172f72003;
    address public constant VAULT_PROXY_ADMIN_MULTISIG = 0x81698f87C6482bF1ce9bFcfC0F103C4A0Adf0Af0;

    address public constant WSTETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;

    address public constant WSTETH_DEFAULT_COLLATERAL = 0xC329400492c6ff2438472D4651Ad17389fCb843a;
    address public constant SYMBIOTIC_VAULT_FACTORY = 0xAEb6bdd95c502390db8f52c8909F703E9Af6a346;

    WhitelistedEthWrapper public depositWrapper =
        WhitelistedEthWrapper(payable(0xfD4a4922d1AFe70000Ce0Ec6806454e78256504e));
    RatiosStrategy public strategy = RatiosStrategy(0x3aA61E6196fb3eb1170E578ad924898624f54ad6);
    MultiVault public multiVaultImplementation =
        MultiVault(0x0C5BC4C8406Fe03214D18bbf2962Ae2fa378c6f7);
    Claimer public claimer = Claimer(0x25024a3017B8da7161d8c5DCcF768F8678fB5802);
    SymbioticWithdrawalQueue public symbioticWithdrawalQueueImplementation =
        SymbioticWithdrawalQueue(0xaB253B304B0BfBe38Ef7EA1f086D01A6cE1c5028);
    MultiVaultDeployScript public deployScript =
        MultiVaultDeployScript(0xffAC02252657ED228e155eE06E60f8b62dC59845);

    uint256 public constant N = 7;
    address public constant DEPLOYER = 0x188858AC61a74350116d1CB6958fBc509FD6afA1;

    address public constant STEAKHOUSE_MULTISIG = 0x2E93913A796a6C6b2bB76F41690E78a2E206Be54;
    address public constant RE7_MULTISIG = 0xE86399fE6d7007FdEcb08A2ee1434Ee677a04433;
    address public constant STAKIN_MULTISIG = 0x059Ae3F8a1EaDDAAb34D0A74E8Eb752c848062d1;
    address public constant REPUBLIC_MULTISIG = 0x5aD82Bd975eB82af09E12D7D85dc3b5f6AC9B151;

    function _deployVaults() internal {
        address[N] memory curators = [
            STAKIN_MULTISIG,
            STEAKHOUSE_MULTISIG,
            REPUBLIC_MULTISIG,
            STEAKHOUSE_MULTISIG,
            RE7_MULTISIG,
            RE7_MULTISIG,
            STEAKHOUSE_MULTISIG
        ];

        string[N] memory names = [
            "Stakin Boosted ETH Vault",
            "Pier Two All Networks",
            "Republic Enhanced Yield Vault",
            "Luganodes Lido v3 Pre-Deposit Vault",
            "Re7 LidoV3 x Blockscape",
            "Re7 LidoV3 x P-OPS Team",
            "Simply Staking Lido v3 Pre-Deposit Vault x Steakhouse"
        ];

        string[N] memory symbols =
            ["bstkETH", "ptstETH", "repETH", "lnstETHsteak", "re7blETH", "re7popseth", "ssSTETH"];

        uint256[N] memory limits = [
            uint256(88888 ether),
            3500 ether,
            1000 ether,
            800 ether,
            400 ether,
            2000 ether,
            2000 ether
        ];

        address[N] memory symbioticVaults = [
            address(0xCa9c60Dc4A445A6e1B7E4FAD351603b1cEDb1B75),
            address(0x87D9c00B21bAC2fD9e5A81e8B96A1268E74F9BE2),
            address(0),
            address(0x4DCd1Da51C10D97c0FEaC12b47f4D19E3d56cd2B),
            address(0x7FD837Fc6E6b1405E3D3Aca89EEf5D8438A2ad44),
            address(0x92c8aEE46534fBb88b70A54298763f22b458bA9d),
            address(0x1a33f761ae602BFa3D2891972F25f2E677cfCEcd)
        ];

        MultiVaultDeployScript.DeployParams memory deployParams = MultiVaultDeployScript
            .DeployParams({
            admin: VAULT_ADMIN_MULTISIG,
            proxyAdmin: VAULT_PROXY_ADMIN_MULTISIG,
            curator: address(0),
            symbioticVault: address(0),
            depositWrapper: address(depositWrapper),
            asset: WSTETH,
            defaultCollateral: WSTETH_DEFAULT_COLLATERAL,
            limit: 0,
            depositPause: false,
            withdrawalPause: false,
            name: "",
            symbol: "",
            minRatioD18: 0.9 ether,
            maxRatioD18: 0.95 ether,
            salt: bytes32(0)
        });

        for (uint256 i = 0; i < curators.length; i++) {
            deployParams.curator = curators[i];
            deployParams.symbioticVault = symbioticVaults[i];
            deployParams.limit = limits[i];
            deployParams.name = names[i];
            deployParams.symbol = symbols[i];

            (MultiVault multiVault, address symbioticAdapter,) = deployScript.deploy(deployParams);
            if (symbioticVaults[i] != address(0) && i != 0) {
                IVault(symbioticVaults[i]).setDepositorWhitelistStatus(address(multiVault), true);
                IAccessControl(symbioticVaults[i]).renounceRole(
                    IVault(symbioticVaults[i]).DEPOSIT_WHITELIST_SET_ROLE(), DEPLOYER
                );
            }

            string memory pattern = string.concat(
                multiVault.name(),
                "; Symbiotic Adapter: %s; Symbiotic Vault: %s; Curator multisig %s."
            );

            console2.log(
                pattern,
                address(symbioticAdapter),
                address(deployParams.symbioticVault),
                address(deployParams.curator)
            );
        }
    }

    function run() external {
        uint256 deployerPk = uint256(bytes32(vm.envBytes("MAINNET_DEPLOYER")));
        address deployer = vm.addr(deployerPk);
        require(deployer == DEPLOYER, "not authorized");
        vm.startBroadcast(deployerPk);

        _deployVaults();

        vm.stopBroadcast();
        // revert("success");
    }
}
