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

    address public constant COSMOSTATION_MULTISIG = 0x375e3157f29810F7928Da82035C1eFe3C7DF77B8;
    address public constant KUKIS_MULTISIG = 0xD1f59ba974E828dF68cB2592C16b967B637cB4e4;
    address public constant INFTRASINGULARITY_MULTISIG = 0x903D4E20a3b70D6aE54E1Cb91Fec2E661E2af3A5;
    address public constant NODES_GURU_MULTISIG = 0x97Ab4CcFbA2b465F77925E7a58003B5fC0a275B7;
    address public constant NODE_MONSTER_MULTISIG = 0xE86399fE6d7007FdEcb08A2ee1434Ee677a04433;
    address public constant STAKE_CAPITAL_MULTISIG = 0xA1E38210B06A05882a7e7Bfe167Cd67F07FA234A;

    function _deployVaults() internal {
        address[N] memory curators = [
            COSMOSTATION_MULTISIG,
            KUKIS_MULTISIG,
            INFTRASINGULARITY_MULTISIG,
            NODES_GURU_MULTISIG,
            NODE_MONSTER_MULTISIG,
            STAKE_CAPITAL_MULTISIG
        ];

        string[N] memory names = [
            "Cosmostation Vault",
            "Kukis Global Vault",
            "InfraSingularity Restaked ETH",
            "Nodes.Guru Vault",
            "Re7 LidoV3 x Node.Monster",
            "MEV Capital Lidov3 stVault x Stake Capital"
        ];

        string[N] memory symbols =
            ["stationETH", "kgETH", "isETH", "ngETH", "re7ndmeth", "mevstETH"];

        uint256[N] memory limits =
            [uint256(400 ether), 400 ether, 2000 ether, 2000 ether, 800 ether, 1500 ether];

        address[N] memory symbioticVaults = [
            address(0),
            address(0x383038Bd10E40Ea3Aa4308f3CFb53420EB8ca7bf),
            address(0x24EC7ac12137E778731E1C1C54abf743CBF02881),
            address(0xc323BfDe0f85086B38a22ec9Fd20D2e79A30e6F9),
            address(0xE49C38f5fc5F2e9826c81809C114d87eC0438619),
            address(0xA86c8491Ce726d8C4B4dF21DcD07b52dE09f9179)
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

            (MultiVault multiVault,,) = deployScript.deploy(deployParams);
            if (symbioticVaults[i] != address(0)) {
                IVault(symbioticVaults[i]).setDepositorWhitelistStatus(address(multiVault), true);
                IAccessControl(symbioticVaults[i]).renounceRole(
                    IVault(symbioticVaults[i]).DEPOSIT_WHITELIST_SET_ROLE(), DEPLOYER
                );
            }

            string memory pattern =
                string.concat(multiVault.name(), ": %s; SymbioticVault: %s WithdrawalQueue %s.");

            console2.log(
                pattern,
                address(multiVault),
                address(deployParams.symbioticVault),
                deployParams.symbioticVault == address(0)
                    ? address(0)
                    : address(multiVault.subvaultAt(0).withdrawalQueue)
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
