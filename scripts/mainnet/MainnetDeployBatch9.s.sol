// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../src/utils/Claimer.sol";
import "../../src/utils/WhitelistedEthWrapper.sol";
import "./MultiVaultDeployScript.sol";

import {IVault} from "@symbiotic/core/interfaces/vault/IVault.sol";
import "forge-std/Script.sol";

contract Deploy is Script {
    address public constant VAULT_ADMIN_MULTISIG = 0xa62243c7a36e74d8280781242a3B0e019ce74E64;
    address public constant VAULT_PROXY_ADMIN_MULTISIG = 0xC7e8b00a61adB658c49D2d8a377FC44572e9ECb5;

    address public constant LISK_WSTETH_OFT = 0x552f1C7E18Bc2013c7FEec7B8F2cB18c8461469e;
    address public constant LISK_MBTC_OFT = 0x57a013aC2A8790D3133f151F22a16fF2aC68627f;
    address public constant LISK_LSK_OFT = 0x1e6b0fF883378Bf8ECb6b8D3A292933f6859384f;
    uint256 public constant N = 3;
    address public constant DEPLOYER = 0x188858AC61a74350116d1CB6958fBc509FD6afA1;

    address public constant SYMBIOTIC_VAULT_FACTORY = 0xAEb6bdd95c502390db8f52c8909F703E9Af6a346;

    RatiosStrategy public strategy = RatiosStrategy(0x3aA61E6196fb3eb1170E578ad924898624f54ad6);
    MultiVault public multiVaultImplementation =
        MultiVault(0x0C5BC4C8406Fe03214D18bbf2962Ae2fa378c6f7);
    Claimer public claimer = Claimer(0x25024a3017B8da7161d8c5DCcF768F8678fB5802);
    SymbioticWithdrawalQueue public symbioticWithdrawalQueueImplementation =
        SymbioticWithdrawalQueue(0xaB253B304B0BfBe38Ef7EA1f086D01A6cE1c5028);
    MultiVaultDeployScript public deployScript =
        MultiVaultDeployScript(0x0159AEA190C7bEa09873B9b42Fe8fD836DB8a254);

    address public constant RE7_MULTISIG = 0xE86399fE6d7007FdEcb08A2ee1434Ee677a04433;

    function _deployVaults() internal {
        address[N] memory curators = [RE7_MULTISIG, RE7_MULTISIG, RE7_MULTISIG];
        string[N] memory names = ["Lisk wstETH Vault", "Lisk rsmBTC Vault", "Lisk LSK Vault"];
        string[N] memory symbols = ["lskETH", "rsM-BTC", "rsLSK"];
        uint256[N] memory limits = [type(uint256).max, type(uint256).max, type(uint256).max];
        address[N] memory symbioticVaults = [
            0xb65A578BF6b4B997B87C83c22F240b291A875ee3,
            0x72926D99c913dede6c7d92ddf125bA781b0E901C,
            0x230E1D993107d5902daC8A59a0BcB13f72477017
        ];

        MultiVaultDeployScript.DeployParams memory deployParams = MultiVaultDeployScript
            .DeployParams({
            admin: VAULT_ADMIN_MULTISIG,
            proxyAdmin: VAULT_PROXY_ADMIN_MULTISIG,
            curator: address(0),
            symbioticVault: address(0),
            depositWrapper: address(0),
            asset: address(0),
            defaultCollateral: address(0),
            limit: 0,
            depositPause: false,
            withdrawalPause: false,
            name: "",
            symbol: "",
            minRatioD18: 0.9 ether,
            maxRatioD18: 0.95 ether,
            salt: bytes32(0)
        });

        address[N] memory targetCores = [
            0x7E0E4B05898181a597673cD5a8FeF2B9E36bEC97,
            0xB2657a1EB016692509F321A4365551e2EC1173C2,
            0xcc1D3926E079c826Cd807FdF825a6777846bb5C1
        ];

        address[N] memory assets = [LISK_WSTETH_OFT, LISK_MBTC_OFT, LISK_LSK_OFT];

        for (uint256 i = 0; i < curators.length; i++) {
            deployParams.curator = curators[i];
            deployParams.symbioticVault = symbioticVaults[i];
            deployParams.limit = limits[i];
            deployParams.name = names[i];
            deployParams.symbol = symbols[i];
            deployParams.depositWrapper = targetCores[i];
            deployParams.asset = assets[i];
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
