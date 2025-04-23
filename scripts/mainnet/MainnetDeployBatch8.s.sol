// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../src/utils/Claimer.sol";
import "../../src/utils/WhitelistedEthWrapper.sol";
import "./MultiVaultDeployScript.sol";

import {IVault} from "@symbiotic/core/interfaces/vault/IVault.sol";
import "forge-std/Script.sol";

contract Deploy is Script {
    address public constant VAULT_ADMIN_MULTISIG = 0x372142a666e13784c6f7cf6795a8e5aF4ED2d3B7;
    address public constant VAULT_PROXY_ADMIN_MULTISIG = 0x843065A71d1D3045c980ee954248FeF23c199f09;

    address public constant SIS = 0xd38BB40815d2B0c2d2c866e0c72c5728ffC76dd9;
    address public constant SYMBIOTIC_VAULT_FACTORY = 0xAEb6bdd95c502390db8f52c8909F703E9Af6a346;

    RatiosStrategy public strategy = RatiosStrategy(0x3aA61E6196fb3eb1170E578ad924898624f54ad6);
    MultiVault public multiVaultImplementation =
        MultiVault(0x0C5BC4C8406Fe03214D18bbf2962Ae2fa378c6f7);
    Claimer public claimer = Claimer(0x25024a3017B8da7161d8c5DCcF768F8678fB5802);
    SymbioticWithdrawalQueue public symbioticWithdrawalQueueImplementation =
        SymbioticWithdrawalQueue(0xaB253B304B0BfBe38Ef7EA1f086D01A6cE1c5028);
    MultiVaultDeployScript public deployScript =
        MultiVaultDeployScript(0x0159AEA190C7bEa09873B9b42Fe8fD836DB8a254);

    uint256 public constant N = 1;
    address public constant DEPLOYER = 0x188858AC61a74350116d1CB6958fBc509FD6afA1;
    address public constant SYMIOSIS_MULTISIG = 0x5112EbA9bc2468Bb5134CBfbEAb9334EdaE7106a;

    function _deployVaults() internal {
        address[N] memory curators = [SYMIOSIS_MULTISIG];
        string[N] memory names = ["Symbiosis Vault"];
        string[N] memory symbols = ["rsSIS"];
        uint256[N] memory limits = [uint256(50e6 ether)];
        address[N] memory symbioticVaults = [address(0x8A6084a5C0738918dC9Fd0AA051a2381FAF540Ed)];

        MultiVaultDeployScript.DeployParams memory deployParams = MultiVaultDeployScript
            .DeployParams({
            admin: VAULT_ADMIN_MULTISIG,
            proxyAdmin: VAULT_PROXY_ADMIN_MULTISIG,
            curator: address(0),
            symbioticVault: address(0),
            depositWrapper: address(0),
            asset: SIS,
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

            IERC20(SIS).approve(address(multiVault), 0.1 gwei);
            multiVault.deposit(0.1 gwei, DEPLOYER);
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
