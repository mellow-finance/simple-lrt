// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "./EthWrapper.sol";
import "@openzeppelin/contracts/access/IAccessControl.sol";

contract WhitelistedEthWrapper is EthWrapper {
    constructor(address WETH_, address wstETH_, address stETH_)
        EthWrapper(WETH_, wstETH_, stETH_)
    {}

    bytes32 public constant SET_WRAPPER_DEPOSIT_WHITELIST_ROLE =
        keccak256("SET_WRAPPER_DEPOSIT_WHITELIST_ROLE");
    bytes32 public constant SET_WRAPPER_DEPOSITOR_WHITELIST_STATUS_ROLE =
        keccak256("SET_WRAPPER_DEPOSITOR_WHITELIST_STATUS_ROLE");

    mapping(address vault => bool) public depositWhitelist;
    mapping(address vault => mapping(address account => bool)) public isDepositWhitelist;

    function setDepositWhitelist(address vault, bool depositWhitelist_) external {
        require(
            IAccessControl(vault).hasRole(SET_WRAPPER_DEPOSIT_WHITELIST_ROLE, msg.sender),
            "WhitelistedEthWrapper: msg.sender must have SET_WRAPPER_DEPOSIT_WHITELIST_ROLE"
        );
        depositWhitelist[vault] = depositWhitelist_;
    }

    function setDepositWhitelist(address vault, address account, bool isDepositWhitelist_)
        external
    {
        require(
            IAccessControl(vault).hasRole(SET_WRAPPER_DEPOSITOR_WHITELIST_STATUS_ROLE, msg.sender),
            "WhitelistedEthWrapper: msg.sender must have SET_WRAPPER_DEPOSITOR_WHITELIST_STATUS_ROLE"
        );
        isDepositWhitelist[vault][account] = isDepositWhitelist_;
    }

    /// @inheritdoc IEthWrapper
    function deposit(
        address depositToken,
        uint256 amount,
        address vault,
        address receiver,
        address referral
    ) public payable override returns (uint256 shares) {
        require(depositToken == ETH || depositToken == WETH, "EthWrapper: invalid depositToken");
        require(
            !depositWhitelist[vault] || isDepositWhitelist[vault][msg.sender],
            "EthWrapper: deposit not whitelisted"
        );
        return super.deposit(depositToken, amount, vault, receiver, referral);
    }
}
