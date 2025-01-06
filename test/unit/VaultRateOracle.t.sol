// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../src/utils/VaultRateOracle.sol";
import "../BaseTest.sol";
import "../mocks/MockMultiVault.sol";

contract Unit is Test {
    function testVaultRateOracleBeforeMigration() external {
        VaultRateOracle oracle = new VaultRateOracle(0xBF706Bb08D760a766D990697477F6da2f1834993);

        vm.expectRevert();
        oracle.migrationCallback();

        console2.log(oracle.getRate());
    }

    function testVaultRateOracleAfterMigration() external {
        VaultRateOracle oracle = new VaultRateOracle(0x7B25d3a9DE72025F120eb5DcFD6E9E311487be7A);

        oracle.migrationCallback();

        console2.log(oracle.getRate());
    }
}
