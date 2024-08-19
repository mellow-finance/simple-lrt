// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import "./Imports.sol";

interface IDefaultCollateralFactory {
    function create(address asset, uint256 initialLimit, address limitIncreaser)
        external
        returns (address);
}

interface IVaultConfigurator {
    struct SymbioticVaultInitParams {
        address collateral;
        address delegator;
        address slasher;
        address burner;
        uint48 epochDuration;
        bool depositWhitelist;
        address defaultAdminRoleHolder;
        address depositWhitelistSetRoleHolder;
        address depositorWhitelistRoleHolder;
    }

    struct InitParams {
        uint64 version;
        address owner;
        SymbioticVaultInitParams vaultParams;
        uint64 delegatorIndex;
        bytes delegatorParams;
        bool withSlasher;
        uint64 slasherIndex;
        bytes slasherParams;
    }

    function create(InitParams memory params) external returns (address, address, address);
}

contract Integration is Test {
    /*
        forge test -vvvv  --match-path ./test/DWFlowTest.t.sol --fork-url $(grep HOLESKY_RPC .env | cut -d '=' -f2,3,4,5)  --fork-block-number 2160000
    */

    address admin = makeAddr("admin");
    address user = makeAddr("user");
    address limitIncreaser = makeAddr("limitIncreaser");

    uint64 vaultVersion = 1;
    address vaultOwner = makeAddr("vaultOwner");
    address vaultAdmin = makeAddr("vaultAdmin");
    uint48 epochDuration = 3600;

    function createNewSymbioticVault() public returns (ISymbioticVault symbioticVault) {
        address wsteth = 0x8d09a4502Cc8Cf1547aD300E066060D043f6982D;
        IDefaultCollateral collateral = IDefaultCollateral(
            IDefaultCollateralFactory(SymbioticConstants.COLLATERAL_FACTORY).create(
                wsteth, 1 ether, limitIncreaser
            )
        );

        (address vault_,,) = IVaultConfigurator(SymbioticConstants.VAULT_CONFIGURATOR).create(
            IVaultConfigurator.InitParams({
                version: 1,
                owner: vaultOwner,
                vaultParams: IVaultConfigurator.SymbioticVaultInitParams({
                    collateral: address(collateral),
                    delegator: address(0),
                    slasher: address(0),
                    burner: address(0),
                    epochDuration: epochDuration,
                    depositWhitelist: false,
                    defaultAdminRoleHolder: vaultAdmin,
                    depositWhitelistSetRoleHolder: vaultAdmin,
                    depositorWhitelistRoleHolder: vaultAdmin
                }),
                delegatorIndex: 0,
                delegatorParams: hex"00000000000000000000000000000000000000000000000000000000000000200000000000000000000000009b4e5e7438c17f13bf368d331c864b01b64458bc00000000000000000000000000000000000000000000000000000000000000000000000000000000000000009b4e5e7438c17f13bf368d331c864b01b64458bc00000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000e000000000000000000000000000000000000000000000000000000000000000010000000000000000000000009b4e5e7438c17f13bf368d331c864b01b64458bc00000000000000000000000000000000000000000000000000000000000000010000000000000000000000009b4e5e7438c17f13bf368d331c864b01b64458bc",
                withSlasher: false,
                slasherIndex: 0,
                slasherParams: ""
            })
        );
        symbioticVault = ISymbioticVault(vault_);
    }

    function test() external {
        require(block.chainid == 17000, "This test can only be run on the Holesky testnet");

        MellowSymbioticVault mellowSymbioticVault = new MellowSymbioticVault(bytes32(uint256(1)), 1);

        ISymbioticVault symbioticVault = createNewSymbioticVault();
        SymbioticWithdrawalQueue withdrawalQueue =
            new SymbioticWithdrawalQueue(address(mellowSymbioticVault), address(symbioticVault));

        mellowSymbioticVault.initialize(
            IMellowSymbioticVault.InitParams({
                name: "MellowSymbioticVault",
                symbol: "MSV",
                symbioticVault: address(symbioticVault),
                withdrawalQueue: address(withdrawalQueue),
                admin: admin,
                limit: 1 ether,
                depositPause: false,
                withdrawalPause: false,
                depositWhitelist: false
            })
        );

        address collateral = withdrawalQueue.symbioticVault().collateral();
        address token = IDefaultCollateral(collateral).asset();

        vm.startPrank(user);

        deal(token, user, 1 ether);
        IERC20(token).approve(address(mellowSymbioticVault), 1 ether);

        mellowSymbioticVault.deposit(1 ether, user);
        mellowSymbioticVault.withdraw(1 ether, user, user);

        skip(epochDuration * 2);

        mellowSymbioticVault.claim(user, user, type(uint256).max);

        vm.stopPrank();
    }
}
