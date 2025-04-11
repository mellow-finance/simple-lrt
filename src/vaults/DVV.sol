// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {IWETH} from "../interfaces/tokens/IWETH.sol";
import "./MellowVaultCompat.sol";
import "./VaultControlStorage.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

contract DVV is MellowVaultCompat {
    address public immutable WETH;
    address public immutable WSTETH;

    constructor(address weth_, address wsteth_) VaultControlStorage("DVV", 2) {
        WETH = weth_;
        WSTETH = wsteth_;
        _disableInitializers();
    }

    function initialize(address admin, address depositWrapper) external initializer {
        __initializeERC4626(
            admin, 0, false, false, true, WSTETH, "Decentralized Validator Token", "DVstETH"
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
