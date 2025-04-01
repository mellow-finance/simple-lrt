// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../BaseTest.sol";
import "../mocks/MockSymbioticFarm.sol";

import "../../src/utils/DefaultStakingModule.sol";
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

    function testDVV() external {
        DVV dvvSingleton = new DVV(
            0xC035a7cf15375cE2706766804551791aD035E0C2, 0xfA1fDbBD71B0aA16162D76914d69cD8CB3Ef92da
        );

        DefaultStakingModule stakingModule = new DefaultStakingModule(
            0xC1d0b3DE6792Bf6b4b37EccdcC24e45978Cfd2Eb, address(dvvSingleton.WETH()), 2
        );

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
            new bytes(0) //abi.encodeCall(DVV.initialize, (admin, address(stakingModule)))
        );

        DVV(payable(dvv)).initialize(admin, address(stakingModule));

        vm.stopPrank();
    }
}
