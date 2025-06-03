// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../vaults/DVV.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

interface IDVVStrategy {
    function processWithdrawals(address[] memory users, uint256 amountForStake)
        external
        returns (bool[] memory statuses);
}

interface IMellowLRT {
    function pendingWithdrawers() external view returns (address[] memory);
}

contract MigratorDVV {
    address public constant DVSTETH = 0x5E362eb2c0706Bd1d134689eC75176018385430B;
    address public constant PROXY_ADMIN_OWNER = 0x81698f87C6482bF1ce9bFcfC0F103C4A0Adf0Af0;
    address public constant ADMIN = 0x9437B2a8cF3b69D782a61f9814baAbc172f72003;
    address public constant PROXY_ADMIN = 0x8E6C80c41450D3fA7B1Fd0196676b99Bfb34bF48;
    address public constant DEPOSIT_WRAPPER = 0xfD4a4922d1AFe70000Ce0Ec6806454e78256504e;
    address public constant SIMPLE_DVT_STAKING_STRATEGY = 0x078b1C03d14652bfeeDFadf7985fdf2D8a2e8108;

    address public immutable dvvImplementation;
    uint256 public immutable limit;

    constructor(address dvvImplementation_, uint256 limit_) {
        dvvImplementation = dvvImplementation_;
        limit = limit_;
    }

    function migrateDVV() external {
        require(msg.sender == PROXY_ADMIN_OWNER, "MigratorDVV: forbidden");
        IDVVStrategy(SIMPLE_DVT_STAKING_STRATEGY).processWithdrawals(
            IMellowLRT(DVSTETH).pendingWithdrawers(), 0
        );
        require(
            IMellowLRT(DVSTETH).pendingWithdrawers().length == 0,
            "MigratorDVV: pending withdrawers exist"
        );
        ProxyAdmin(PROXY_ADMIN).upgradeAndCall(
            ITransparentUpgradeableProxy(DVSTETH),
            address(dvvImplementation),
            abi.encodeCall(DVV.initialize, (ADMIN, DEPOSIT_WRAPPER, limit))
        );
    }

    function renounceOwnership() external {
        require(msg.sender == PROXY_ADMIN_OWNER, "MigratorDVV: forbidden");
        ProxyAdmin(PROXY_ADMIN).transferOwnership(PROXY_ADMIN_OWNER);
    }
}
