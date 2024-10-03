// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import "../BaseTest.sol";

contract Integration is BaseTest {
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

    uint256 symbioticLimit = 1000 ether;

    function testEth() external {
        require(block.chainid == 17000, "This test can only be run on the Holesky testnet");

        MellowSymbioticVault singleton = new MellowSymbioticVault("MellowSymbioticVault", 1);
        MellowSymbioticVaultFactory factory = new MellowSymbioticVaultFactory(address(singleton));

        ISymbioticVault symbioticVault = ISymbioticVault(
            symbioticHelper.createNewSymbioticVault(
                SymbioticHelper.CreationParams({
                    vaultOwner: vaultOwner,
                    vaultAdmin: vaultAdmin,
                    epochDuration: epochDuration,
                    asset: HOLESKY_WSTETH,
                    isDepositLimit: false,
                    depositLimit: symbioticLimit
                })
            )
        );

        (IMellowSymbioticVault mellowSymbioticVault, IWithdrawalQueue withdrawalQueue) = factory
            .create(
            IMellowSymbioticVaultFactory.InitParams({
                proxyAdmin: makeAddr("proxyAdmin"),
                limit: 100 ether,
                symbioticCollateral: address(HOLESKY_WSTETH_SYMBIOTIC_COLLATERAL),
                symbioticVault: address(symbioticVault),
                admin: admin,
                depositPause: false,
                withdrawalPause: false,
                depositWhitelist: false,
                name: "MellowSymbioticVault",
                symbol: "MSV"
            })
        );

        address token =
            SymbioticWithdrawalQueue(address(withdrawalQueue)).symbioticVault().collateral();
        assertEq(token, HOLESKY_WSTETH);

        vm.startPrank(user);

        uint256 amount = 0.5 ether;
        uint256 n = 25;

        EthWrapper wrapper = new EthWrapper(HOLESKY_WETH, HOLESKY_WSTETH, HOLESKY_STETH);

        deal(token, user, amount * n);
        IERC20(token).approve(address(wrapper), amount * n);

        for (uint256 i = 0; i < n; i++) {
            wrapper.deposit(
                HOLESKY_WSTETH, amount, address(mellowSymbioticVault), user, makeAddr("referrer")
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
