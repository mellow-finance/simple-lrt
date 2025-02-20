// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../src/utils/Claimer.sol";
import "../../src/utils/WhitelistedEthWrapper.sol";
import "./MultiVaultDeployScript.sol";
import "forge-std/Script.sol";

contract Deploy is Script {
    address public constant VAULT_ADMIN_MULTISIG = 0x9437B2a8cF3b69D782a61f9814baAbc172f72003;
    address public constant VAULT_PROXY_ADMIN_MULTISIG = 0x81698f87C6482bF1ce9bFcfC0F103C4A0Adf0Af0;

    address public constant WSTETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address public constant STETH = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    address public constant WSTETH_DEFAULT_COLLATERAL = 0xC329400492c6ff2438472D4651Ad17389fCb843a;
    address public constant SYMBIOTIC_VAULT_FACTORY = 0xAEb6bdd95c502390db8f52c8909F703E9Af6a346;

    WhitelistedEthWrapper public depositWrapper;
    RatiosStrategy public strategy;
    MultiVault public multiVaultImplementation;
    Claimer public claimer;
    SymbioticWithdrawalQueue public symbioticWithdrawalQueueImplementation;
    MultiVaultDeployScript public deployScript;

    function _deployCommonContracts() internal {
        if (address(deployScript) == address(0)) {
            depositWrapper = new WhitelistedEthWrapper(WETH, WSTETH, STETH);
            strategy = new RatiosStrategy();
            multiVaultImplementation = new MultiVault("MultiVault", 1);
            claimer = new Claimer();
            symbioticWithdrawalQueueImplementation = new SymbioticWithdrawalQueue(address(claimer));
            deployScript = new MultiVaultDeployScript(
                SYMBIOTIC_VAULT_FACTORY,
                address(strategy),
                address(multiVaultImplementation),
                address(symbioticWithdrawalQueueImplementation)
            );
        }
    }

    function _deployVaults() internal {
        address[6] memory curators = [
            0xa01Cf5321824e045f54F19CBaf9cd90750417cF2,
            0xA1E38210B06A05882a7e7Bfe167Cd67F07FA234A,
            0xA1E38210B06A05882a7e7Bfe167Cd67F07FA234A,
            0xA1E38210B06A05882a7e7Bfe167Cd67F07FA234A,
            0xA1E38210B06A05882a7e7Bfe167Cd67F07FA234A,
            0x0553ce52eFa359E18AD4d06401263ff80b1Fc689
        ];

        string[6] memory names = [
            "A41 Vault",
            "MEV Capital Lidov3 stVault x Nodeinfra",
            "Lido Alchemy stVault",
            "MEV Capital Lidov3 stVault x Kiln",
            "Lido Blockscape x MEV Capital stVault",
            "stakefish Lido v3 Restaked ETH"
        ];

        string[6] memory symbols =
            ["a41ETH", "mevnoETH", "ALstETH", "mevkstETH", "mevblETH", "sfETH"];
        uint256[6] memory limits =
            [5000 ether, uint256(100 ether), 50 ether, 1500 ether, 75 ether, 100 ether];
        address[6] memory symbioticVaults =
            [address(0), address(1), address(1), address(1), address(1), address(0)]; // TODO: replace with actual symbiotic vaults

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
            console2.log(
                "MultiVault: %s SymbioticAdapter: %s Name %s",
                address(multiVault),
                symbioticAdapter,
                multiVault.name()
            );
        }
    }

    function run() external {
        vm.startBroadcast(uint256(bytes32(vm.envBytes("MAINNET_DEPLOYER"))));
        uint256 gas = gasleft();

        _deployCommonContracts();
        console2.log("Common deploy:", gas - gasleft());
        gas = gasleft();
        _deployVaults();
        console2.log("4 vaults deploy:", gas - gasleft());

        vm.stopBroadcast();

        revert("success");
    }
}
