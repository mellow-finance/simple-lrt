// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {IWETH} from "../interfaces/tokens/IWETH.sol";
import "./MellowVaultCompat.sol";
import "./VaultControlStorage.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

contract DVV is MellowVaultCompat {
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant WSTETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;

    constructor() VaultControlStorage("DVV", 2) {
        _disableInitializers();
    }

    function initialize(address admin, address depositWrapper, uint256 limit)
        external
        initializer
    {
        __initializeERC4626(
            admin, limit, false, false, true, WSTETH, "Decentralized Validator Token", "DVstETH"
        );
        _setDepositorWhitelistStatus(depositWrapper, true);
        submit();
    }

    receive() external payable {
        require(_msgSender() == WETH, "DVV: Only WETH");
    }

    function submit() public {
        uint256 balance = IERC20(WETH).balanceOf(address(this));
        if (balance == 0) {
            return;
        }
        IWETH(WETH).withdraw(balance);
        Address.sendValue(payable(WSTETH), balance);
    }
}
