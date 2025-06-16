// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "forge-std/Script.sol";

import "../../src/utils/EthWrapper.sol";
import "./DeployScript.sol";
import "./libraries/SymbioticDeployLibrary.sol";

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "test/deploy-acceptance/AcceptanceTestRunner.sol";

abstract contract DeployMultiVault is Script, AcceptanceTestRunner {
    /// @dev deployed default hooks https://docs.symbiotic.fi/deployments/mainnet/#hooks
    enum HOOK {
        None,
        FullRestakeDecreaseHook, //	0x0786ef079A0Fc3A2D9e62bf2E8c7aeF86B62d70A
        NetworkRestakeDecreaseHook, //	0xe46d876BA2F3C991F3AC3321B8C0A1c323ef8bCf
        NetworkRestakeRedistributeHook, //	0x8A76a3b791D9cfCD17304D31e04304A54Bf07845
        OperatorSpecificDecreaseHook //	0xCc7Fd9B9A37ba1e2b30243Ce5A52BDB1f56B006a

    }

    /// @dev Networks
    enum NETWORK {
        PRIMEV,
        CAPs
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

    /// @dev https://docs.symbiotic.fi/deployments/mainnet/#hooks
    mapping(HOOK => address) hook;

    DeployScript internal script;
    address ethDepositWrapper;

    function run() external {
        uint256 vaultIndex = deploy();

        /// @dev validate deployment
        validateState(script, vaultIndex);

        revert("ok");
    }

    function setUp() public {
        script = DeployScript(address(0xC70F0A380D5Bc02d237C46CEF92C6174Db496969));
        ethDepositWrapper = 0xfD4a4922d1AFe70000Ce0Ec6806454e78256504e;

        /// @dev https://docs.symbiotic.fi/deployments/mainnet/#hooks
        hook[HOOK.None] = address(0);
        hook[HOOK.FullRestakeDecreaseHook] = 0x0786ef079A0Fc3A2D9e62bf2E8c7aeF86B62d70A;
        hook[HOOK.NetworkRestakeDecreaseHook] = 0xe46d876BA2F3C991F3AC3321B8C0A1c323ef8bCf;
        hook[HOOK.NetworkRestakeRedistributeHook] = 0x8A76a3b791D9cfCD17304D31e04304A54Bf07845;
        hook[HOOK.OperatorSpecificDecreaseHook] = 0xCc7Fd9B9A37ba1e2b30243Ce5A52BDB1f56B006a;
    }

    /// @dev returns default vaultAdmin and vaultProxyAdmin
    function vaultAndProxyAdmin(address asset) internal view returns (address, address) {
        if (asset == wstETH) {
            return (
                0x9437B2a8cF3b69D782a61f9814baAbc172f72003, // vaultAdmin
                0x81698f87C6482bF1ce9bFcfC0F103C4A0Adf0Af0 // vaultProxyAdmin
            );
        } else if (asset == tBTC) {
            return (
                0x53980f83eCB2516168812A10cb8aCeC79B55718b,
                0x994e2478Df26E9F076D6F50b6cA18c39aa6bD6Ca
            );
        }
        revert("unknown vaultAdmin and vaultProxyAdmin");
    }

    /// @dev deployed burners https://docs.symbiotic.fi/deployments/mainnet/#burners
    function burner(address asset) public view returns (address) {
        if (asset == wstETH) {
            return 0xdCaC890b14121FD5D925E2589017Be68C2B5B324;
        } else if (asset == rETH) {
            return 0x89e3915C9Eb07D1bfF5d78e24B28d409dba9B272;
        } else if (asset == mETH) {
            return 0x919C4329Ed4D4A72c72c126ff8AE351C1E7Ce231;
        } else if (asset == swETH) {
            return 0x1Aca33aE8f57E2cdADd0375875AE12fb08c54529;
        } else if (asset == frxETH) {
            return 0xBe5821dB563311750f6295E3CDB40aBbDBfF0c4b;
        } else if (asset == ETHx) {
            return 0xCd669361D629380A70338d613D29c6F3a28A2B50;
        }
        return address(0xdead);
    }

    /// @dev https://docs.symbiotic.fi/deployments/mainnet/#vaults
    function defaultCollateral(address asset) public view returns (address) {
        if (asset == wstETH) {
            return 0xC329400492c6ff2438472D4651Ad17389fCb843a;
        } else if (asset == rETH) {
            return address(0);
        } else if (asset == mETH) {
            return address(0);
        } else if (asset == swETH) {
            return address(0);
        } else if (asset == frxETH) {
            return address(0);
        } else if (asset == ETHx) {
            return address(0);
        } else if (asset == tBTC) {
            return 0x0C969ceC0729487d264716e55F232B404299032c;
        }
        revert("unknown default collateral");
    }

    function getNetworksReceivers(NETWORK network)
        internal
        pure
        returns (address[] memory networks, address[] memory receivers)
    {
        if (network == NETWORK.PRIMEV) {
            networks = new address[](1);
            receivers = new address[](1);
            networks[0] = 0x9101eda106A443A0fA82375936D0D1680D5a64F5;
            receivers[0] = 0xD5881f91270550B8850127f05BD6C8C203B3D33f;
        } else if (network == NETWORK.CAPs) {
            networks = new address[](1);
            receivers = new address[](1);
            networks[0] = address(0);
            receivers[0] = address(0);
        }
    }

    function getDeployParams()
        internal
        virtual
        returns (DeployScript.Config memory config, DeployScript.SubvaultParams[] memory subvaults);

    function deploy() public returns (uint256) {
        uint256 deployerPk = uint256(bytes32(vm.envBytes("MAINNET_DEPLOYER")));
        address deployer = vm.addr(deployerPk);
        vm.startBroadcast(deployerPk);

        (DeployScript.Config memory config, DeployScript.SubvaultParams[] memory subvaults) =
            getDeployParams();

        (uint256 index, MultiVault vault) = script.deploy(
            DeployScript.DeployParams({config: config, subvaults: subvaults, salt: bytes32(0)})
        );

        if (config.depositWrapper != address(0)) {
            EthWrapper w = EthWrapper(payable(config.depositWrapper));
            w.deposit{value: 1 gwei}(w.ETH(), 1 gwei, address(vault), deployer, deployer);
        } else {
            uint256 amount = 10 ** (ERC20(config.asset).decimals() / 2);
            IERC20(config.asset).approve(address(vault), amount);
            vault.deposit(amount, deployer, deployer);
        }

        // roundings
        require(
            vault.totalAssets() == vault.totalSupply(), "Total assets should equal total supply"
        );

        console2.log("MultiVault (%s): %s", vault.name(), address(vault));
        vm.stopBroadcast();

        return index;
    }
}
