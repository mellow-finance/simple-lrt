// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../BaseTest.sol";
import "../mocks/MockSymbioticFarm.sol";

import "../../src/vaults/DVV.sol";

interface ISimpleDVTStakingStrategy {
    function processWithdrawals(address[] memory users, uint256 amountForStake)
        external
        returns (bool[] memory statuses);
}

interface IMellowLRT {
    function pendingWithdrawers() external view returns (address[] memory);
}

contract Unit is Test {
    address public constant dvv = 0x5E362eb2c0706Bd1d134689eC75176018385430B;
    address public constant proxyAdminOwner = 0x81698f87C6482bF1ce9bFcfC0F103C4A0Adf0Af0;
    address public constant admin = 0x9437B2a8cF3b69D782a61f9814baAbc172f72003;
    address public constant proxyAdmin = 0x8E6C80c41450D3fA7B1Fd0196676b99Bfb34bF48;

    address public immutable weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public immutable wsteth = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address public constant depositWrapper = 0xfD4a4922d1AFe70000Ce0Ec6806454e78256504e;

    function testDVVMigration() external {
        DVV dvvSingleton = new DVV(weth, wsteth);

        vm.startPrank(admin);
        {
            address[] memory users = IMellowLRT(dvv).pendingWithdrawers();
            ISimpleDVTStakingStrategy(0x078b1C03d14652bfeeDFadf7985fdf2D8a2e8108).processWithdrawals(
                users, 0
            );
        }
        vm.stopPrank();
        vm.startPrank(proxyAdminOwner);
        ProxyAdmin(proxyAdmin).upgradeAndCall(
            ITransparentUpgradeableProxy(dvv),
            address(dvvSingleton),
            abi.encodeCall(DVV.initialize, (admin, depositWrapper))
        );

        console2.log(DVV(payable(dvv)).totalAssets());
        console2.log(DVV(payable(dvv)).totalSupply());

        vm.stopPrank();
    }
}
