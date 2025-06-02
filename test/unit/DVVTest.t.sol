// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../BaseTest.sol";
import "../mocks/MockSymbioticFarm.sol";

import "../../src/utils/MigratorDVV.sol";
import "../../src/vaults/DVV.sol";

interface X {}

contract Unit is Test {
    function testDVVMigration() external {
        DVV dvvSingleton = new DVV();
        MigratorDVV migratorDVV = new MigratorDVV(address(dvvSingleton), 11679 ether);
        vm.startPrank(migratorDVV.ADMIN());
        IAccessControl(migratorDVV.SIMPLE_DVT_STAKING_STRATEGY()).grantRole(
            keccak256("admin_delegate"), migratorDVV.ADMIN()
        );
        IAccessControl(migratorDVV.SIMPLE_DVT_STAKING_STRATEGY()).grantRole(
            keccak256("operator"), address(migratorDVV)
        );
        vm.stopPrank();

        vm.startPrank(migratorDVV.PROXY_ADMIN_OWNER());
        ProxyAdmin(migratorDVV.PROXY_ADMIN()).transferOwnership(address(migratorDVV));
        migratorDVV.migrateDVV();
        vm.stopPrank();
    }
}
