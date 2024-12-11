// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "./EthWrapper.sol";
import "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";

contract WhitelistedEthWrapper is EthWrapper, AccessControlEnumerable {
    constructor(address WETH_, address wstETH_, address stETH_, address admin_)
        EthWrapper(WETH_, wstETH_, stETH_)
    {
        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
    }

    bool public depositWhitelist;
    mapping(address account => bool) public isDepositWhitelist;

    function setDepositWhitelist(bool depositWhitelist_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        depositWhitelist = depositWhitelist_;
    }

    function setDepositWhitelist(address account, bool isDepositWhitelist_)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        isDepositWhitelist[account] = isDepositWhitelist_;
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
            !depositWhitelist || isDepositWhitelist[msg.sender],
            "EthWrapper: deposit not whitelisted"
        );
        return super.deposit(depositToken, amount, vault, receiver, referral);
    }
}
