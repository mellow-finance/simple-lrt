// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import "forge-std/Test.sol";
import "src/MellowEigenLayerVault.sol";

contract EigenBaseTest is Test {
    address admin = makeAddr("admin");
    address user = makeAddr("user");

    MellowEigenLayerVault public mellowEigenLayerVault;
    /// @dev immutable for Eigen-Layer protocol
    address immutable delegationManagerAddress = 0x39053D51B77DC0d36036Fc1fCc8Cb819df8Ef37A;
    address immutable strategyManagerAddress = 0x858646372CC42E1A627fcE94aa7A7033e7CF075A;

    /// @dev specific stratey and its operator (Lido+P2P)
    address immutable strategyAddress = 0x93c4b944D05dfe6df7645A86cd2206016c51564D;
    address immutable operatorAddress = 0xDbEd88D83176316fc46797B43aDeE927Dc2ff2F5; // P2P.org
    address immutable underlyingTokenAddress = address(IStrategy(strategyAddress).underlyingToken());

    function setUp() public {
        IMellowEigenLayerVault.EigenLayerParam memory eigenLayerParam = IMellowEigenLayerVault
            .EigenLayerParam({
            storageParam: IMellowEigenLayerVaultStorage.EigenLayerStorage({
                delegationManager: IDelegationManager(delegationManagerAddress),
                strategyManager: IStrategyManager(strategyManagerAddress),
                strategy: IStrategy(strategyAddress),
                operator: operatorAddress,
                claimWithdrawalsMax: 1,
                nonce: 0
            }),
            delegationSignature: abi.encode("signature"),
            salt: bytes32(uint256(0x666)),
            expiry: 365 days
        });

        IMellowEigenLayerVault.InitParams memory initParams = IMellowEigenLayerVault.InitParams({
            limit: 10000 ether,
            admin: admin,
            eigenLayerParam: eigenLayerParam,
            depositPause: false,
            withdrawalPause: false,
            depositWhitelist: false,
            name: "Mellow-Eigen-Layer-Vault",
            symbol: "MellowEL"
        });

        mellowEigenLayerVault = new MellowEigenLayerVault(bytes32(uint256(1)), 1);
        mellowEigenLayerVault.initialize(initParams);
    }

    function test() public {}
}
