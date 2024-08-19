// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import "./Imports.sol";

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
    address wsteth = 0x8d09a4502Cc8Cf1547aD300E066060D043f6982D;
    address steth = 0x3F1c547b21f65e10480dE3ad8E19fAAC46C95034;
    address weth = 0x94373a4919B3240D86eA41593D5eBa789FEF3848;

    function testEth() external {
        require(block.chainid == 17000, "This test can only be run on the Holesky testnet");

        MellowSymbioticVotesVault singleton =
            new MellowSymbioticVotesVault("MellowSymbioticVotesVault", 1);
        MellowSymbioticVaultFactory factory = new MellowSymbioticVaultFactory(address(singleton));

        ISymbioticVault symbioticVault = ISymbioticVault(
            SymbioticHelperLibrary.createNewSymbioticVault(
                SymbioticHelperLibrary.CreationParams({
                    limitIncreaser: limitIncreaser,
                    vaultOwner: vaultOwner,
                    vaultAdmin: vaultAdmin,
                    epochDuration: epochDuration,
                    asset: wsteth,
                    limit: 1 ether
                })
            )
        );

        (IMellowSymbioticVault mellowSymbioticVault, IWithdrawalQueue withdrawalQueue) = factory
            .create(
            IMellowSymbioticVaultFactory.InitParams({
                proxyAdmin: makeAddr("proxyAdmin"),
                limit: 100 ether,
                symbioticVault: address(symbioticVault),
                admin: admin,
                depositPause: false,
                withdrawalPause: false,
                depositWhitelist: false,
                name: "MellowSymbioticVault",
                symbol: "MSV"
            })
        );

        address collateral =
            SymbioticWithdrawalQueue(address(withdrawalQueue)).symbioticVault().collateral();
        address token = IDefaultCollateral(collateral).asset();
        assertEq(token, wsteth);

        vm.startPrank(user);

        uint256 amount = 0.5 ether;
        uint256 n = 25;

        EthWrapper wrapper = new EthWrapper(weth, wsteth, steth);

        deal(token, user, amount * n);
        IERC20(token).approve(address(wrapper), amount * n);

        for (uint256 i = 0; i < n; i++) {
            wrapper.deposit(
                wsteth, amount, address(mellowSymbioticVault), user, makeAddr("referrer")
            );
        }
        for (uint256 i = 0; i < n; i++) {
            MellowSymbioticVault(address(mellowSymbioticVault)).withdraw(amount, user, user);
        }

        skip(epochDuration * 2);

        for (uint256 i = 0; i < n; i++) {
            MellowSymbioticVault(address(mellowSymbioticVault)).claim(user, user, amount);
        }
        vm.stopPrank();
    }
}
