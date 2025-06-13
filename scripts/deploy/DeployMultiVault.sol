// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "forge-std/Script.sol";

import "../../src/utils/EthWrapper.sol";
import "./DeployScript.sol";
import "./libraries/SymbioticDeployLibrary.sol";
import "test/deploy-acceptance/AcceptanceTestRunner.sol";

contract Deploy is Script, AcceptanceTestRunner {
    /// @dev list of Vaults
    enum VAULT {
        rtBTC
    }

    VAULT DEPLOY_VAULT_NAME = VAULT.rtBTC;

    /// @dev deployed default hooks https://docs.symbiotic.fi/deployments/mainnet/#hooks
    enum HOOK {
        None,
        FullRestakeDecreaseHook, //	0x0786ef079A0Fc3A2D9e62bf2E8c7aeF86B62d70A
        NetworkRestakeDecreaseHook, //	0xe46d876BA2F3C991F3AC3321B8C0A1c323ef8bCf
        NetworkRestakeRedistributeHook, //	0x8A76a3b791D9cfCD17304D31e04304A54Bf07845
        OperatorSpecificDecreaseHook //	0xCc7Fd9B9A37ba1e2b30243Ce5A52BDB1f56B006a

    }

    /// @dev list of ETH based assets
    address immutable wstETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address immutable rETH = address(0);
    address immutable mETH = address(0);
    address immutable swETH = address(0);
    address immutable frxETH = address(0);
    address immutable ETHx = address(0);
    /// @dev list of other assets
    address immutable tBTC = 0x18084fbA666a33d37592fA2633fD49a74DD93a88;

    address immutable DEFAULT_DEAD_BURNER = address(0xdead);
    /// @dev https://docs.symbiotic.fi/deployments/mainnet/#hooks
    mapping(HOOK => address) hook;
    /// @dev deployed burners https://docs.symbiotic.fi/deployments/mainnet/#burners
    mapping(address => address) burner;
    /// @dev https://docs.symbiotic.fi/deployments/mainnet/#vaults
    mapping(address => address) defaultCollateral;

    uint256 deployerPk = uint256(bytes32(vm.envBytes("MAINNET_DEPLOYER")));
    address deployer = vm.addr(deployerPk);

    DeployScript script;
    address ethDepositWrapper;

    function setUp() public {
        script = DeployScript(address(0xC70F0A380D5Bc02d237C46CEF92C6174Db496969));
        ethDepositWrapper = 0xfD4a4922d1AFe70000Ce0Ec6806454e78256504e;

        /// @dev https://docs.symbiotic.fi/deployments/mainnet/#hooks
        hook[HOOK.None] = address(0);
        hook[HOOK.FullRestakeDecreaseHook] = 0x0786ef079A0Fc3A2D9e62bf2E8c7aeF86B62d70A;
        hook[HOOK.NetworkRestakeDecreaseHook] = 0xe46d876BA2F3C991F3AC3321B8C0A1c323ef8bCf;
        hook[HOOK.NetworkRestakeRedistributeHook] = 0x8A76a3b791D9cfCD17304D31e04304A54Bf07845;
        hook[HOOK.OperatorSpecificDecreaseHook] = 0xCc7Fd9B9A37ba1e2b30243Ce5A52BDB1f56B006a;

        /// @dev deployed burners https://docs.symbiotic.fi/deployments/mainnet/#burners
        burner[wstETH] = 0xdCaC890b14121FD5D925E2589017Be68C2B5B324;
        burner[rETH] = 0x89e3915C9Eb07D1bfF5d78e24B28d409dba9B272;
        burner[mETH] = 0x919C4329Ed4D4A72c72c126ff8AE351C1E7Ce231;
        burner[swETH] = 0x1Aca33aE8f57E2cdADd0375875AE12fb08c54529;
        burner[frxETH] = 0xBe5821dB563311750f6295E3CDB40aBbDBfF0c4b;
        burner[ETHx] = 0xCd669361D629380A70338d613D29c6F3a28A2B50;
        burner[tBTC] = DEFAULT_DEAD_BURNER;

        /// @dev https://docs.symbiotic.fi/deployments/mainnet/#vaults
        defaultCollateral[wstETH] = 0xC329400492c6ff2438472D4651Ad17389fCb843a;
        defaultCollateral[tBTC] = 0x0C969ceC0729487d264716e55F232B404299032c;
    }

    function getDeployParams(VAULT vaultIndex)
        internal
        returns (DeployScript.Config memory config, DeployScript.SubvaultParams[] memory subvaults)
    {
        if (vaultIndex == VAULT.rtBTC) {
            DeployScript.SubvaultParams[] memory subvaults = new DeployScript.SubvaultParams[](1);
            (address[] memory networks, address[] memory receivers) = getNetworksReceivers();

            address asset = tBTC;

            subvaults[0] = DeployScript.SubvaultParams({
                libraryIndex: 0,
                data: SymbioticDeployLibrary(script.deployLibraries(0)).combineOptions(
                    burner[asset], // burner
                    10 days, // epoch duration
                    3 days, // veto duration
                    15 days, // burner delay
                    hook[HOOK.NetworkRestakeDecreaseHook],
                    networks,
                    receivers
                ),
                minRatioD18: 0.9 ether,
                maxRatioD18: 0.95 ether
            });

            config = DeployScript.Config({
                vaultAdmin: 0x53980f83eCB2516168812A10cb8aCeC79B55718b,
                vaultProxyAdmin: 0x994e2478Df26E9F076D6F50b6cA18c39aa6bD6Ca,
                curator: 0xA1E38210B06A05882a7e7Bfe167Cd67F07FA234A,
                asset: asset,
                defaultCollateral: defaultCollateral[asset], // see here https://docs.symbiotic.fi/deployments/mainnet/#legacy
                depositWrapper: address(0),
                limit: 1000 ether,
                depositPause: false,
                withdrawalPause: false,
                name: "Restaked tBTC",
                symbol: "rtBTC"
            });

            return (config, subvaults);
        }

        revert("unknown vault");
    }

    function getNetworksReceivers()
        internal
        returns (address[] memory networks, address[] memory receivers)
    {
        networks = new address[](1);
        receivers = new address[](1);
        networks[0] = 0x9101eda106A443A0fA82375936D0D1680D5a64F5;
        receivers[0] = 0xD5881f91270550B8850127f05BD6C8C203B3D33f;
    }

    function run() external {
        vm.startBroadcast(deployerPk);

        (DeployScript.Config memory config, DeployScript.SubvaultParams[] memory subvaults) =
            getDeployParams(DEPLOY_VAULT_NAME);

        (uint256 index, MultiVault vault) = script.deploy(
            DeployScript.DeployParams({config: config, subvaults: subvaults, salt: bytes32(0)})
        );

        if (config.depositWrapper != address(0)) {
            EthWrapper w = EthWrapper(payable(config.depositWrapper));
            w.deposit{value: 1 gwei}(w.ETH(), 1 gwei, address(vault), deployer, deployer);
        } else {
            IERC20(config.asset).approve(address(vault), 1 gwei);
            vault.deposit(1 gwei, deployer, deployer);
        }

        // roundings
        require(
            vault.totalAssets() == vault.totalSupply(), "Total assets should equal total supply"
        );

        console2.log("MultiVault (%s): %s", vault.name(), address(vault));
        vm.stopBroadcast();

        /// @dev validate deployment
        validateState(script, index);
        revert("ok");
    }
}
