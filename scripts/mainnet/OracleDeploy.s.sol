// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

// import "../../src/utils/DVVRateOracle.sol";
// import "../../src/utils/VaultRateOracle.sol";

import "../../src/utils/OracleFactory.sol";

import "forge-std/Script.sol";

contract Deploy is Script {
    function run() external {
        vm.startBroadcast(uint256(bytes32(vm.envBytes("MAINNET_TEST_DEPLOYER"))));
        OracleFactory factory = new OracleFactory();

        address[15] memory vaultsStatic = [
            0xBEEF69Ac7870777598A04B2bd4771c71212E6aBc,
            0x84631c0d0081FDe56DeB72F6DE77abBbF6A9f93a,
            0x5fD13359Ba15A84B76f7F87568309040176167cd,
            0x7a4EffD87C2f3C55CA251080b1343b605f327E3a,
            0x49cd586dd9BA227Be9654C735A659a1dB08232a9,
            0x82dc3260f599f4fC4307209A1122B6eAa007163b,
            0xd6E09a5e6D719d1c881579C9C8670a210437931b,
            0x8c9532a60E0E7C6BbD2B2c1303F63aCE1c3E9811,
            0x7b31F008c48EFb65da78eA0f255EE424af855249,
            0x4f3Cc6359364004b245ad5bE36E6ad4e805dC961,
            0x375A8eE22280076610cA2B4348d37cB1bEEBeba0,
            0xcC36e5272c422BEE9A8144cD2493Ac472082eBaD,
            0xB908c9FE885369643adB5FBA4407d52bD726c72d,
            0x24183535a24CF0272841B05047A26e200fFAB696,
            0xE4357bDAE017726eE5E83Db3443bcd269BbF125d
        ];

        address[] memory vaults = new address[](vaultsStatic.length);
        for (uint256 i = 0; i < vaultsStatic.length; i++) {
            vaults[i] = vaultsStatic[i];
        }

        factory.multiCreate(vaults, new bool[](vaults.length));

        for (uint256 i = 0; i < vaults.length; i++) {
            address oracle = factory.oracles(vaults[i], false);
            console2.log("oracle:", oracle);
        }

        uint256 j = 0;
        for (uint256 i = 0; i < vaults.length; i++) {
            if (IERC4626(vaults[i]).asset() == 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0) {
                vaults[j] = vaults[i];
                j++;
            }
        }
        assembly {
            mstore(vaults, j)
        }
        bool[] memory isETHBased = new bool[](j);
        for (uint256 i = 0; i < j; i++) {
            isETHBased[i] = true;
        }

        factory.multiCreate(vaults, isETHBased);

        for (uint256 i = 0; i < vaults.length; i++) {
            address oracle = factory.oracles(vaults[i], true);
            console2.log("eth oracle:", oracle);
        }

        vm.stopBroadcast();
        // revert("ok");
    }
}
