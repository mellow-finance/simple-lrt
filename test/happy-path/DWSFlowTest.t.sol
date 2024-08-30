// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import "../BaseTest.sol";

interface IVetoSlasher {
    /**
     * @notice Request a slash using a subnetwork for a particular operator by a given amount using hints.
     * @param subnetwork full identifier of the subnetwork (address of the network concatenated with the uint96 identifier)
     * @param operator address of the operator
     * @param amount maximum amount of the collateral to be slashed
     * @param captureTimestamp time point when the stake was captured
     * @param hints hints for checkpoints' indexes
     * @return slashIndex index of the slash request
     * @dev Only network middleware can call this function.
     */
    function requestSlash(
        bytes32 subnetwork,
        address operator,
        uint256 amount,
        uint48 captureTimestamp,
        bytes calldata hints
    ) external returns (uint256 slashIndex);

    /**
     * @notice Execute a slash with a given slash index using hints.
     * @param slashIndex index of the slash request
     * @param hints hints for checkpoints' indexes
     * @return slashedAmount amount of the collateral slashed
     * @dev Anyone can call this function.
     */
    function executeSlash(uint256 slashIndex, bytes calldata hints)
        external
        returns (uint256 slashedAmount);
}

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
    uint48 epochDuration = 604800;
    address wsteth = 0x8d09a4502Cc8Cf1547aD300E066060D043f6982D;

    uint256 symbioticLimit = 1000 ether;

    function testSlashing() external {
        require(block.chainid == 17000, "This test can only be run on the Holesky testnet");

        MellowSymbioticVault mellowSymbioticVault = new MellowSymbioticVault(bytes32(uint256(1)), 1);

        ISymbioticVault symbioticVault = ISymbioticVault(
            symbioticHelper.createSlashingSymbioticVault(
                SymbioticHelper.CreationParams({
                    vaultOwner: vaultOwner,
                    vaultAdmin: vaultAdmin,
                    epochDuration: epochDuration,
                    asset: wsteth,
                    isDepositLimit: false,
                    depositLimit: symbioticLimit
                })
            )
        );
        SymbioticWithdrawalQueue withdrawalQueue =
            new SymbioticWithdrawalQueue(address(mellowSymbioticVault), address(symbioticVault));

        mellowSymbioticVault.initialize(
            IMellowSymbioticVault.InitParams({
                name: "MellowSymbioticVault",
                symbol: "MSV",
                symbioticCollateral: address(wstethSymbioticCollateral),
                symbioticVault: address(symbioticVault),
                withdrawalQueue: address(withdrawalQueue),
                admin: admin,
                limit: 1000 ether,
                depositPause: false,
                withdrawalPause: false,
                depositWhitelist: false
            })
        );

        address token = withdrawalQueue.symbioticVault().collateral();
        assertEq(token, wsteth);
        {
            vm.startPrank(user);
            deal(wsteth, user, 10 ether);
            IERC20(wsteth).approve(address(mellowSymbioticVault), 10 ether);
            uint256 lpAmount = mellowSymbioticVault.deposit(10 ether, user);
            assertEq(lpAmount, 10 ether);
            vm.stopPrank();
        }

        assertEq(IERC20(wsteth).balanceOf(address(mellowSymbioticVault)), 0);
        // assertEq(IERC20(collateral).balanceOf(address(mellowSymbioticVault)), 0);
        assertEq(IERC20(address(symbioticVault)).balanceOf(address(mellowSymbioticVault)), 10 ether);

        /*
            slashing
        */

        // IVetoSlasher slasher = IVetoSlasher(symbioticVault.slasher());

        // slasher.requestSlash(
        //     subnetwork,
        //     operator,
        //     1 ether, // amount of the collateral to be slashed
        //     block.timestamp, // captureTimestamp
        //     new bytes(0) //, hints
        // );
    }
}
