// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

contract RewardMiddleware is AccessControlEnumerable {
    using SafeERC20 for IERC20;

    struct Escrow {
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint256 minAmountOut;
    }

    bytes32 public constant SWAP_ROLE = keccak256("SWAP_ROLE");
    bytes32 public constant ESCROW_ROLE = keccak256("ESCROW_ROLE");
    bytes32 public constant SEND_ROLE = keccak256("SEND_ROLE");

    mapping(address token => bool isAllowed) public allowedTokens;
    mapping(address farm => bool isAllowed) public allowedFarms;
    mapping(address router => bool isAllowed) public allowedRouters;
    Escrow[] private _escrows;

    constructor(address admin_) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
        _setRoleAdmin(SWAP_ROLE, DEFAULT_ADMIN_ROLE);
        _setRoleAdmin(ESCROW_ROLE, DEFAULT_ADMIN_ROLE);
        _setRoleAdmin(SEND_ROLE, DEFAULT_ADMIN_ROLE);
    }

    function setRouterPermission(address router, bool isAllowed)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        allowedRouters[router] = isAllowed;
    }

    function setTokenPermission(address token, bool isAllowed)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        allowedTokens[token] = isAllowed;
    }

    function setFarmPermission(address farm, bool isAllowed) public onlyRole(DEFAULT_ADMIN_ROLE) {
        allowedFarms[farm] = isAllowed;
    }

    function swap(
        address tokenIn,
        uint256 amountIn,
        address tokenOut,
        uint256 minAmountOut,
        address router,
        bytes calldata data
    ) external onlyRole(SWAP_ROLE) returns (uint256 amountOut) {
        require(allowedTokens[tokenIn], "Token not allowed");
        require(allowedTokens[tokenOut], "Token not allowed");
        require(allowedRouters[router], "Router not allowed");

        address this_ = address(this);
        amountOut = IERC20(tokenOut).balanceOf(this_);
        IERC20(tokenIn).forceApprove(router, amountIn);
        Address.functionCall(router, data);
        amountOut = IERC20(tokenOut).balanceOf(this_) - amountOut;
        require(amountOut >= minAmountOut, "Amount out too low");
        IERC20(tokenIn).forceApprove(router, 0);
    }

    function send(address token, uint256 amount, address farm) external onlyRole(SEND_ROLE) {
        require(allowedTokens[token], "Token not allowed");
        require(allowedFarms[farm], "Farm not allowed");
        IERC20(token).safeTransfer(farm, amount);
    }

    function escrow(Escrow calldata escrow_) external onlyRole(ESCROW_ROLE) returns (uint256 id) {
        require(allowedTokens[escrow_.tokenIn], "Token not allowed");
        require(allowedTokens[escrow_.tokenOut], "Token not allowed");
        id = _escrows.length;
        _escrows.push(escrow_);
    }

    function stopEscrow(uint256 id) external onlyRole(ESCROW_ROLE) {
        require(id < _escrows.length, "Escrow not found");
        delete _escrows[id];
    }

    function handleEscrow(uint256 id, uint256 amountIn, uint256 minAmountOut)
        external
        returns (uint256 amountOut)
    {
        require(id < _escrows.length, "Escrow not found");
        Escrow memory escrow_ = _escrows[id];
        amountIn = Math.min(amountIn, escrow_.amountIn);
        address tokenIn = escrow_.tokenIn;
        address tokenOut = escrow_.tokenOut;
        address sender = msg.sender;
        amountOut = Math.mulDiv(escrow_.amountIn, amountIn, escrow_.minAmountOut);
        require(amountOut >= minAmountOut, "Amount out too low");
        IERC20(tokenOut).safeTransferFrom(sender, address(this), amountIn);
        IERC20(tokenIn).safeTransfer(sender, amountOut);
        escrow_.amountIn -= amountOut;
        escrow_.minAmountOut -= amountIn;
        _escrows[id] = escrow_;
    }
}
