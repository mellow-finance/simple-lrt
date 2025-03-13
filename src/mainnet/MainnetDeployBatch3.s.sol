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
        MultiVaultDeployScript(0x0159AEA190C7bEa09873B9b42Fe8fD836DB8a254);

    uint256 public constant N = 6;
    address public constant DEPLOYER = 0x188858AC61a74350116d1CB6958fBc509FD6afA1;

    address public constant PROVIROLL_MULTISIG = 0x52aeb526dA48d09F993d3504Ba860048069562Aa;
    address public constant LUGANODES_MULTISIG = 0xE86399fE6d7007FdEcb08A2ee1434Ee677a04433;
    address public constant STAKIN_MULTISIG = 0xE86399fE6d7007FdEcb08A2ee1434Ee677a04433;
    address public constant HASHKEY_CLOUD_MULTISIG = 0x323B1370eC7D17D0c70b2CbebE052b9ed0d8A289;
    address public constant NANSEN_MULTISIG = 0x059Ae3F8a1EaDDAAb34D0A74E8Eb752c848062d1;
    address public constant DSRV_MULTISIG = 0xd4634A87EE960C208656175C27A4206e4ec43D17;

    function _deployVaults() internal {
        address[N] memory curators = [
            PROVIROLL_MULTISIG,
            LUGANODES_MULTISIG,
            STAKIN_MULTISIG,
            HASHKEY_CLOUD_MULTISIG,
            NANSEN_MULTISIG,
            DSRV_MULTISIG
        ];

        string[N] memory names = [
            "ProviVault",
            "Re7 LidoV3 x Luganodes",
            "Re7 LidoV3 x Stakin",
            "HashKey Cloud Lido v3 Pre-Deposit Vault",
            "Nansen x Gauntlet Lido v3 stVault",
            "DSRV Vault"
        ];

        string[N] memory symbols =
            ["prvETH", "re7lugeth", "re7stkETH", "hcstETH", "nanETH", "vstETH"];

        uint256[N] memory limits =
            [uint256(1000 ether), 800 ether, 40000 ether, 500 ether, 200 ether, 1000 ether];

        address[N] memory symbioticVaults = [
            address(0xac7817e893EfB8401C5Cf6c625125725e139c326),
            address(0x6d17D5e17e2e471fb8209b9101a4091717239d66),
            address(0x693F99dCEd615087eab28D95B1d471CC60843A67),
            address(0xb225dC68Ab754DD5F84C9941766da1613B14A0C6),
            address(0),
            address(0x287bed263ec8973994719efB8d17E653Ac4a3E1b)
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
            if (symbioticVaults[i] != address(0)) {
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

        MultiVaultDeployScript prev =
            MultiVaultDeployScript(0xffAC02252657ED228e155eE06E60f8b62dC59845);
        deployScript = new MultiVaultDeployScript(
            prev.symbioticVaultFactory(),
            address(prev.strategy()),
            prev.multiVaultImplementation(),
            prev.symbioticWithdrawalQueueImplementation()
        );
        console2.log("Deploy script:", address(deployScript));

        // _deployVaults();

        vm.stopBroadcast();
        // revert("success");
    }
}
