// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import "../BaseTest.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockSymbioticFarm is IStakerRewards {
    function version() external pure returns (uint64) {
        return 1;
    }

    function claimable(address, address, bytes calldata) external pure returns (uint256) {
        return 0;
    }

    function distributeRewards(address network, address token, uint256 amount, bytes calldata data)
        external
    {}

    function claimRewards(address recipient, address token, bytes calldata /* data */ ) external {
        IERC20(token).transfer(recipient, IERC20(token).balanceOf(address(this)));
    }

    function test() external pure {}
}

contract MockSymbioticVault is ERC20 {
    address public immutable wsteth = 0x8d09a4502Cc8Cf1547aD300E066060D043f6982D;

    constructor() ERC20("MockSymbioticVault", "MSV") {}

    bool public isDepositLimit = false;
    uint256 public depositLimit = 0;
    bool public depositWhitelist = false;
    uint256 public loss = 0;

    function collateral() external view returns (address) {
        return wsteth;
    }

    function activeBalanceOf(address user) external view returns (uint256) {
        return balanceOf(user);
    }

    function setLimit(bool _isDepositLimit, uint256 _depositLimit) external {
        isDepositLimit = _isDepositLimit;
        depositLimit = _depositLimit;
    }

    function totalStake() external view returns (uint256) {
        return IERC20(wsteth).balanceOf(address(this));
    }

    function setLoss() external {
        loss = loss ^ 1;
    }

    function deposit(address onBehalfOf, uint256 amount)
        external
        returns (uint256 depositedAmount, uint256 mintedShares)
    {
        IERC20(wsteth).transferFrom(onBehalfOf, address(this), amount);
        _mint(onBehalfOf, amount);
        depositedAmount = amount - loss;
        mintedShares = amount;
    }

    function test() external pure {}
}

contract Unit is BaseTest {
    address wsteth = 0x8d09a4502Cc8Cf1547aD300E066060D043f6982D;
    address steth = 0x3F1c547b21f65e10480dE3ad8E19fAAC46C95034;
    address weth = 0x94373a4919B3240D86eA41593D5eBa789FEF3848;
    address user = makeAddr("user");

    uint64 vaultVersion = 1;

    address symbioticVaultOwner = makeAddr("symbioticVaultOwner");
    address symbioticVaultAdmin = makeAddr("vaultAdmin");
    uint48 epochDuration = 8 hours;
    uint256 symbioticLimit = 100 ether;
    uint256 vaultLimit = 200 ether;
    address vaultProxyAdmin = makeAddr("vaultProxyAdmin");
    address vaultAdmin = makeAddr("vaultAdmin");

    function testMellowSymbioticVaultInstantWithdrawal() external {
        MellowSymbioticVault singleton = new MellowSymbioticVault("MellowSymbioticVault", 1);
        MellowSymbioticVaultFactory factory = new MellowSymbioticVaultFactory(address(singleton));

        ISymbioticVault symbioticVault = ISymbioticVault(
            symbioticHelper.createNewSymbioticVault(
                SymbioticHelper.CreationParams({
                    vaultOwner: symbioticVaultOwner,
                    vaultAdmin: symbioticVaultAdmin,
                    epochDuration: epochDuration,
                    asset: wsteth,
                    isDepositLimit: true,
                    depositLimit: symbioticLimit
                })
            )
        );

        (IMellowSymbioticVault mellowSymbioticVault, IWithdrawalQueue withdrawalQueue) = factory
            .create(
            IMellowSymbioticVaultFactory.InitParams({
                proxyAdmin: vaultProxyAdmin,
                limit: vaultLimit,
                symbioticVault: address(symbioticVault),
                admin: vaultAdmin,
                depositPause: false,
                withdrawalPause: false,
                depositWhitelist: false,
                name: "MellowSymbioticVault",
                symbol: "MSV"
            })
        );

        vm.expectRevert();
        mellowSymbioticVault.initialize(
            IMellowSymbioticVault.InitParams({
                withdrawalQueue: address(withdrawalQueue),
                limit: vaultLimit,
                symbioticVault: address(symbioticVault),
                admin: vaultAdmin,
                depositPause: false,
                withdrawalPause: false,
                depositWhitelist: false,
                name: "MellowSymbioticVault",
                symbol: "MSV"
            })
        );

        vm.startPrank(user);

        deal(wsteth, user, vaultLimit);
        IERC20(wsteth).approve(address(mellowSymbioticVault), vaultLimit);
        uint256 lpAmount = mellowSymbioticVault.deposit(vaultLimit, user, address(1));
        assertEq(lpAmount, vaultLimit);

        assertEq(
            IERC20(wsteth).balanceOf(address(mellowSymbioticVault)),
            vaultLimit / 2,
            "Incorrect wsteth balance of the vault"
        );
        assertEq(
            IERC20(address(symbioticVault)).balanceOf(address(mellowSymbioticVault)),
            vaultLimit / 2,
            "Incorrect symbioticVault balance of the vault"
        );

        mellowSymbioticVault.withdraw(vaultLimit / 2, user, user);

        assertEq(
            IERC20(wsteth).balanceOf(user), vaultLimit / 2, "Incorrect wsteth balance for user"
        );

        assertEq(
            IERC20(wsteth).balanceOf(address(mellowSymbioticVault)),
            0,
            "Incorrect wsteth balance of the vault"
        );

        assertEq(
            IERC20(address(symbioticVault)).balanceOf(address(mellowSymbioticVault)),
            vaultLimit / 2,
            "Incorrect symbioticVault balance of the vault"
        );

        assertEq(
            mellowSymbioticVault.pendingAssetsOf(user), 0, "Incorrect pending assets of the user"
        );

        assertEq(
            mellowSymbioticVault.claimableAssetsOf(user), 0, "Incorrect pending assets of the user"
        );

        vm.stopPrank();
    }

    function testMellowSymbioticVaultPausedWithdrawal() external {
        MellowSymbioticVault singleton = new MellowSymbioticVault("MellowSymbioticVault", 1);
        MellowSymbioticVaultFactory factory = new MellowSymbioticVaultFactory(address(singleton));

        ISymbioticVault symbioticVault = ISymbioticVault(
            symbioticHelper.createNewSymbioticVault(
                SymbioticHelper.CreationParams({
                    vaultOwner: symbioticVaultOwner,
                    vaultAdmin: symbioticVaultAdmin,
                    epochDuration: epochDuration,
                    asset: wsteth,
                    isDepositLimit: true,
                    depositLimit: symbioticLimit
                })
            )
        );

        (IMellowSymbioticVault mellowSymbioticVault, /*IWithdrawalQueue withdrawalQueue*/ ) =
        factory.create(
            IMellowSymbioticVaultFactory.InitParams({
                proxyAdmin: vaultProxyAdmin,
                limit: vaultLimit,
                symbioticVault: address(symbioticVault),
                admin: vaultAdmin,
                depositPause: false,
                withdrawalPause: true,
                depositWhitelist: false,
                name: "MellowSymbioticVault",
                symbol: "MSV"
            })
        );

        vm.startPrank(user);

        deal(wsteth, user, vaultLimit);
        IERC20(wsteth).approve(address(mellowSymbioticVault), vaultLimit);
        uint256 lpAmount = mellowSymbioticVault.deposit(vaultLimit, user);
        assertEq(lpAmount, vaultLimit);

        assertEq(
            IERC20(wsteth).balanceOf(address(mellowSymbioticVault)),
            vaultLimit / 2,
            "Incorrect wsteth balance of the vault"
        );
        assertEq(
            IERC20(address(symbioticVault)).balanceOf(address(mellowSymbioticVault)),
            vaultLimit / 2,
            "Incorrect symbioticVault balance of the vault"
        );

        vm.expectRevert();
        mellowSymbioticVault.withdraw(vaultLimit / 2, user, user);

        vm.stopPrank();
    }

    function testMellowSymbioticVaultInstantAndPendingWithdrawal() external {
        MellowSymbioticVault singleton = new MellowSymbioticVault("MellowSymbioticVault", 1);
        MellowSymbioticVaultFactory factory = new MellowSymbioticVaultFactory(address(singleton));

        ISymbioticVault symbioticVault = ISymbioticVault(
            symbioticHelper.createNewSymbioticVault(
                SymbioticHelper.CreationParams({
                    vaultOwner: symbioticVaultOwner,
                    vaultAdmin: symbioticVaultAdmin,
                    epochDuration: epochDuration,
                    asset: wsteth,
                    isDepositLimit: true,
                    depositLimit: symbioticLimit
                })
            )
        );

        (IMellowSymbioticVault mellowSymbioticVault, IWithdrawalQueue withdrawalQueue) = factory
            .create(
            IMellowSymbioticVaultFactory.InitParams({
                proxyAdmin: vaultProxyAdmin,
                limit: vaultLimit,
                symbioticVault: address(symbioticVault),
                admin: vaultAdmin,
                depositPause: false,
                withdrawalPause: false,
                depositWhitelist: false,
                name: "MellowSymbioticVault",
                symbol: "MSV"
            })
        );

        vm.startPrank(user);

        deal(wsteth, user, vaultLimit);
        IERC20(wsteth).approve(address(mellowSymbioticVault), vaultLimit);
        uint256 lpAmount = mellowSymbioticVault.deposit(vaultLimit, user);
        assertEq(lpAmount, vaultLimit);

        (
            uint256 accountAssets,
            uint256 accountInstantAssets,
            uint256 accountShares,
            uint256 accountInstantShares
        ) = mellowSymbioticVault.getBalances(user);

        assertEq(accountAssets, vaultLimit, "Incorrect assets");
        assertEq(accountInstantAssets, vaultLimit / 2, "Incorrect instant assets");
        assertEq(accountShares, vaultLimit, "Incorrect shares");
        assertEq(accountInstantShares, vaultLimit / 2, "Incorrect instant shares");

        assertEq(
            IERC20(wsteth).balanceOf(address(mellowSymbioticVault)),
            vaultLimit / 2,
            "Incorrect wsteth balance of the vault"
        );
        assertEq(
            IERC20(address(symbioticVault)).balanceOf(address(mellowSymbioticVault)),
            vaultLimit / 2,
            "Incorrect symbioticVault balance of the vault"
        );

        mellowSymbioticVault.withdraw(vaultLimit, user, user);

        assertEq(
            IERC20(wsteth).balanceOf(user), vaultLimit / 2, "Incorrect wsteth balance for user"
        );

        assertEq(
            IERC20(wsteth).balanceOf(address(mellowSymbioticVault)),
            0,
            "Incorrect wsteth balance of the vault"
        );

        assertEq(
            IERC20(address(symbioticVault)).balanceOf(address(mellowSymbioticVault)),
            0,
            "Incorrect symbioticVault balance of the vault"
        );

        assertEq(
            IERC20(address(symbioticVault)).balanceOf(address(withdrawalQueue)),
            vaultLimit / 2,
            "Incorrect symbioticVault balance of the vault"
        );

        assertEq(
            mellowSymbioticVault.pendingAssetsOf(user),
            vaultLimit / 2,
            "Incorrect pending assets of the user"
        );

        assertEq(
            mellowSymbioticVault.claimableAssetsOf(user), 0, "Incorrect pending assets of the user"
        );

        skip(epochDuration * 2);

        assertEq(
            mellowSymbioticVault.pendingAssetsOf(user), 0, "Incorrect pending assets of the user"
        );

        assertEq(
            mellowSymbioticVault.claimableAssetsOf(user),
            vaultLimit / 2,
            "Incorrect pending assets of the user"
        );

        vm.stopPrank();
    }

    function testMellowSymbioticVaultInstantAndPendingWithdrawalOnBehalf() external {
        MellowSymbioticVault singleton = new MellowSymbioticVault("MellowSymbioticVault", 1);
        MellowSymbioticVaultFactory factory = new MellowSymbioticVaultFactory(address(singleton));

        ISymbioticVault symbioticVault = ISymbioticVault(
            symbioticHelper.createNewSymbioticVault(
                SymbioticHelper.CreationParams({
                    vaultOwner: symbioticVaultOwner,
                    vaultAdmin: symbioticVaultAdmin,
                    epochDuration: epochDuration,
                    asset: wsteth,
                    isDepositLimit: true,
                    depositLimit: symbioticLimit
                })
            )
        );

        (IMellowSymbioticVault mellowSymbioticVault, IWithdrawalQueue withdrawalQueue) = factory
            .create(
            IMellowSymbioticVaultFactory.InitParams({
                proxyAdmin: vaultProxyAdmin,
                limit: vaultLimit,
                symbioticVault: address(symbioticVault),
                admin: vaultAdmin,
                depositPause: false,
                withdrawalPause: false,
                depositWhitelist: false,
                name: "MellowSymbioticVault",
                symbol: "MSV"
            })
        );

        vm.startPrank(user);

        deal(wsteth, user, vaultLimit);
        IERC20(wsteth).approve(address(mellowSymbioticVault), vaultLimit);
        uint256 lpAmount = mellowSymbioticVault.deposit(vaultLimit, user);
        assertEq(lpAmount, vaultLimit);

        assertEq(
            IERC20(wsteth).balanceOf(address(mellowSymbioticVault)),
            vaultLimit / 2,
            "Incorrect wsteth balance of the vault"
        );
        assertEq(
            IERC20(address(symbioticVault)).balanceOf(address(mellowSymbioticVault)),
            vaultLimit / 2,
            "Incorrect symbioticVault balance of the vault"
        );

        address anotherUser = makeAddr("anotherUser");
        mellowSymbioticVault.approve(anotherUser, type(uint256).max);

        vm.stopPrank();

        vm.startPrank(anotherUser);

        mellowSymbioticVault.withdraw(vaultLimit, anotherUser, user);

        assertEq(
            IERC20(wsteth).balanceOf(anotherUser),
            vaultLimit / 2,
            "Incorrect wsteth balance for anotherUser"
        );

        assertEq(
            IERC20(wsteth).balanceOf(address(mellowSymbioticVault)),
            0,
            "Incorrect wsteth balance of the vault"
        );

        assertEq(
            IERC20(address(symbioticVault)).balanceOf(address(mellowSymbioticVault)),
            0,
            "Incorrect symbioticVault balance of the vault"
        );

        assertEq(
            IERC20(address(symbioticVault)).balanceOf(address(withdrawalQueue)),
            vaultLimit / 2,
            "Incorrect symbioticVault balance of the vault"
        );

        assertEq(
            mellowSymbioticVault.pendingAssetsOf(anotherUser),
            vaultLimit / 2,
            "Incorrect pending assets of the user"
        );

        assertEq(
            mellowSymbioticVault.claimableAssetsOf(anotherUser),
            0,
            "Incorrect pending assets of the anotherUser"
        );

        skip(epochDuration * 2);

        assertEq(
            mellowSymbioticVault.pendingAssetsOf(anotherUser),
            0,
            "Incorrect pending assets of the anotherUser"
        );

        assertEq(
            mellowSymbioticVault.claimableAssetsOf(anotherUser),
            vaultLimit / 2,
            "Incorrect pending assets of the user"
        );

        vm.stopPrank();

        vm.startPrank(user);
        vm.expectRevert();
        mellowSymbioticVault.claim(anotherUser, user, type(uint256).max);
        vm.stopPrank();
    }

    function testPushIntoSymbiotic() external {
        MellowSymbioticVault singleton = new MellowSymbioticVault("MellowSymbioticVault", 1);
        MellowSymbioticVaultFactory factory = new MellowSymbioticVaultFactory(address(singleton));

        ISymbioticVault symbioticVault = ISymbioticVault(
            symbioticHelper.createNewSymbioticVault(
                SymbioticHelper.CreationParams({
                    vaultOwner: symbioticVaultOwner,
                    vaultAdmin: symbioticVaultAdmin,
                    epochDuration: epochDuration,
                    asset: wsteth,
                    isDepositLimit: true,
                    depositLimit: symbioticLimit
                })
            )
        );

        (IMellowSymbioticVault mellowSymbioticVault, /*IWithdrawalQueue withdrawalQueue*/ ) =
        factory.create(
            IMellowSymbioticVaultFactory.InitParams({
                proxyAdmin: vaultProxyAdmin,
                limit: vaultLimit,
                symbioticVault: address(symbioticVault),
                admin: vaultAdmin,
                depositPause: false,
                withdrawalPause: false,
                depositWhitelist: false,
                name: "MellowSymbioticVault",
                symbol: "MSV"
            })
        );

        vm.startPrank(user);

        deal(wsteth, user, vaultLimit);
        IERC20(wsteth).approve(address(mellowSymbioticVault), vaultLimit);
        uint256 lpAmount = mellowSymbioticVault.deposit(vaultLimit, user);
        vm.stopPrank();

        assertEq(lpAmount, vaultLimit);
        assertEq(mellowSymbioticVault.pushIntoSymbiotic(), 0, "Incorrect pushIntoSymbiotic result");

        vm.prank(symbioticVaultAdmin);
        symbioticVault.setDepositLimit(symbioticLimit + 1 ether);

        vm.startPrank(symbioticVaultAdmin);
        symbioticVault.setDepositWhitelist(true);
        vm.stopPrank();

        assertEq(
            mellowSymbioticVault.pushIntoSymbiotic(), 0 ether, "Incorrect pushIntoSymbiotic result"
        );

        vm.startPrank(symbioticVaultAdmin);
        symbioticVault.setDepositorWhitelistStatus(address(mellowSymbioticVault), true);
        vm.stopPrank();

        assertEq(
            mellowSymbioticVault.pushIntoSymbiotic(), 1 ether, "Incorrect pushIntoSymbiotic result"
        );

        assertEq(
            mellowSymbioticVault.pushIntoSymbiotic(), 0 ether, "Incorrect pushIntoSymbiotic result"
        );

        vm.startPrank(symbioticVaultAdmin);
        symbioticVault.setDepositWhitelist(false);
        vm.stopPrank();

        assertEq(
            mellowSymbioticVault.pushIntoSymbiotic(), 0 ether, "Incorrect pushIntoSymbiotic result"
        );
    }

    function testPushIntoSymbioticNothingToPush() external {
        MellowSymbioticVault singleton = new MellowSymbioticVault("MellowSymbioticVault", 1);
        MellowSymbioticVaultFactory factory = new MellowSymbioticVaultFactory(address(singleton));

        ISymbioticVault symbioticVault = ISymbioticVault(
            symbioticHelper.createNewSymbioticVault(
                SymbioticHelper.CreationParams({
                    vaultOwner: symbioticVaultOwner,
                    vaultAdmin: symbioticVaultAdmin,
                    epochDuration: epochDuration,
                    asset: wsteth,
                    isDepositLimit: true,
                    depositLimit: symbioticLimit
                })
            )
        );

        (IMellowSymbioticVault mellowSymbioticVault, /*IWithdrawalQueue withdrawalQueue*/ ) =
        factory.create(
            IMellowSymbioticVaultFactory.InitParams({
                proxyAdmin: vaultProxyAdmin,
                limit: vaultLimit,
                symbioticVault: address(symbioticVault),
                admin: vaultAdmin,
                depositPause: false,
                withdrawalPause: false,
                depositWhitelist: false,
                name: "MellowSymbioticVault",
                symbol: "MSV"
            })
        );

        vm.startPrank(user);

        deal(wsteth, user, vaultLimit);
        IERC20(wsteth).approve(address(mellowSymbioticVault), vaultLimit);
        uint256 lpAmount = mellowSymbioticVault.deposit(vaultLimit, user);
        vm.stopPrank();

        assertEq(lpAmount, vaultLimit);
        assertEq(mellowSymbioticVault.pushIntoSymbiotic(), 0, "Incorrect pushIntoSymbiotic result");

        vm.prank(symbioticVaultAdmin);
        symbioticVault.setDepositLimit(symbioticLimit + 1000 ether);

        assertEq(
            mellowSymbioticVault.pushIntoSymbiotic(),
            100 ether,
            "Incorrect pushIntoSymbiotic result"
        );

        assertEq(
            mellowSymbioticVault.pushIntoSymbiotic(), 0 ether, "Incorrect pushIntoSymbiotic result"
        );
    }

    function testPushIntoSymbioticMockSymbioticVault() external {
        MellowSymbioticVault singleton = new MellowSymbioticVault("MellowSymbioticVault", 1);
        MellowSymbioticVaultFactory factory = new MellowSymbioticVaultFactory(address(singleton));

        MockSymbioticVault symbioticVault = new MockSymbioticVault();

        (IMellowSymbioticVault mellowSymbioticVault, /*IWithdrawalQueue withdrawalQueue*/ ) =
        factory.create(
            IMellowSymbioticVaultFactory.InitParams({
                proxyAdmin: vaultProxyAdmin,
                limit: vaultLimit,
                symbioticVault: address(symbioticVault),
                admin: vaultAdmin,
                depositPause: false,
                withdrawalPause: false,
                depositWhitelist: false,
                name: "MellowSymbioticVault",
                symbol: "MSV"
            })
        );

        vm.startPrank(user);

        deal(wsteth, user, vaultLimit);
        IERC20(wsteth).approve(address(mellowSymbioticVault), vaultLimit);

        symbioticVault.setLimit(true, symbioticLimit);

        uint256 lpAmount = mellowSymbioticVault.deposit(vaultLimit, user);
        vm.stopPrank();

        symbioticVault.setLimit(false, 0);
        symbioticVault.setLoss();

        assertEq(lpAmount, vaultLimit);
        assertEq(
            mellowSymbioticVault.pushIntoSymbiotic(),
            100 ether - 1 wei,
            "Incorrect pushIntoSymbiotic result"
        );
    }

    function testPushRewards() external {
        MellowSymbioticVault singleton = new MellowSymbioticVault("MellowSymbioticVault", 1);
        MellowSymbioticVaultFactory factory = new MellowSymbioticVaultFactory(address(singleton));

        ISymbioticVault symbioticVault = ISymbioticVault(
            symbioticHelper.createNewSymbioticVault(
                SymbioticHelper.CreationParams({
                    vaultOwner: symbioticVaultOwner,
                    vaultAdmin: symbioticVaultAdmin,
                    epochDuration: epochDuration,
                    asset: wsteth,
                    isDepositLimit: true,
                    depositLimit: symbioticLimit
                })
            )
        );

        (IMellowSymbioticVault mellowSymbioticVault, /*IWithdrawalQueue withdrawalQueue*/ ) =
        factory.create(
            IMellowSymbioticVaultFactory.InitParams({
                proxyAdmin: vaultProxyAdmin,
                limit: vaultLimit,
                symbioticVault: address(symbioticVault),
                admin: vaultAdmin,
                depositPause: false,
                withdrawalPause: false,
                depositWhitelist: false,
                name: "MellowSymbioticVault",
                symbol: "MSV"
            })
        );

        vm.startPrank(vaultAdmin);
        MellowSymbioticVault(address(mellowSymbioticVault)).grantRole(
            keccak256("SET_FARM_ROLE"), vaultAdmin
        );

        address mockSymbioticFarm = address(new MockSymbioticFarm());
        address mockDistributionFarm = makeAddr("mockDistributionFarm");
        address curatorTreasury = makeAddr("curatorTreasury");
        uint64 curatorFeeD6 = 1e5; // 10%

        vm.expectRevert();
        mellowSymbioticVault.setFarm(
            1,
            IMellowSymbioticVaultStorage.FarmData({
                rewardToken: address(mellowSymbioticVault),
                symbioticFarm: mockSymbioticFarm,
                distributionFarm: mockDistributionFarm,
                curatorTreasury: curatorTreasury,
                curatorFeeD6: curatorFeeD6
            })
        );

        assertEq(
            mellowSymbioticVault.totalAssets(),
            0,
            "Incorrect total assets of the mellowSymbioticVault"
        );

        vm.expectRevert();
        mellowSymbioticVault.setFarm(
            1,
            IMellowSymbioticVaultStorage.FarmData({
                rewardToken: address(symbioticVault),
                symbioticFarm: mockSymbioticFarm,
                distributionFarm: mockDistributionFarm,
                curatorTreasury: curatorTreasury,
                curatorFeeD6: curatorFeeD6
            })
        );

        vm.expectRevert();
        mellowSymbioticVault.setFarm(
            1,
            IMellowSymbioticVaultStorage.FarmData({
                rewardToken: wsteth,
                symbioticFarm: mockSymbioticFarm,
                distributionFarm: mockDistributionFarm,
                curatorTreasury: curatorTreasury,
                curatorFeeD6: 1e6 + 1
            })
        );

        mellowSymbioticVault.setFarm(
            1,
            IMellowSymbioticVaultStorage.FarmData({
                rewardToken: wsteth,
                symbioticFarm: mockSymbioticFarm,
                distributionFarm: mockDistributionFarm,
                curatorTreasury: curatorTreasury,
                curatorFeeD6: curatorFeeD6
            })
        );

        vm.stopPrank();

        deal(wsteth, mockSymbioticFarm, 10 ether);

        mellowSymbioticVault.pushRewards(1, new bytes(0));

        assertEq(
            IERC20(wsteth).balanceOf(mockDistributionFarm),
            9 ether,
            "Incorrect balance of the mockDistributionFarm"
        );

        assertEq(
            IERC20(wsteth).balanceOf(curatorTreasury),
            1 ether,
            "Incorrect balance of the curatorTreasury"
        );

        assertEq(
            IERC20(wsteth).balanceOf(mockSymbioticFarm),
            0 ether,
            "Incorrect balance of the mockSymbioticFarm"
        );

        mellowSymbioticVault.pushRewards(1, new bytes(0));
        assertEq(
            IERC20(wsteth).balanceOf(mockDistributionFarm),
            9 ether,
            "Incorrect balance of the mockDistributionFarm"
        );

        assertEq(
            IERC20(wsteth).balanceOf(curatorTreasury),
            1 ether,
            "Incorrect balance of the curatorTreasury"
        );

        assertEq(
            IERC20(wsteth).balanceOf(mockSymbioticFarm),
            0 ether,
            "Incorrect balance of the mockSymbioticFarm"
        );

        vm.expectRevert();
        mellowSymbioticVault.pushRewards(0, new bytes(0));
    }
}
