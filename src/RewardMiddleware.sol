// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

contract RewardMiddleware is AccessControlEnumerable {
    using SafeERC20 for IERC20;

    // Struct defining the properties of an Escrow.
    struct Escrow {
        address tokenIn; // Token to be deposited into escrow.
        address tokenOut; // Token to be withdrawn from escrow.
        uint256 amountIn; // Amount of `tokenIn` to be deposited.
        uint256 minAmountOut; // Minimum amount of `tokenOut` required to withdraw.
    }

    // Role definitions for access control.
    bytes32 public constant SWAP_ROLE = keccak256("SWAP_ROLE");
    bytes32 public constant ESCROW_ROLE = keccak256("ESCROW_ROLE");
    bytes32 public constant SEND_ROLE = keccak256("SEND_ROLE");

    // Mappings to track allowed tokens, farms, and routers.
    mapping(address token => bool isAllowed) public allowedTokens;
    mapping(address farm => bool isAllowed) public allowedFarms;
    mapping(address router => bool isAllowed) public allowedRouters;

    // Array to store all escrows.
    Escrow[] private _escrows;

    // Constructor to set up roles and assign the admin role.
    constructor(address admin_) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
        _setRoleAdmin(SWAP_ROLE, DEFAULT_ADMIN_ROLE);
        _setRoleAdmin(ESCROW_ROLE, DEFAULT_ADMIN_ROLE);
        _setRoleAdmin(SEND_ROLE, DEFAULT_ADMIN_ROLE);
    }

    // Allows the admin to set permissions for a router.
    function setRouterPermission(address router, bool isAllowed)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        allowedRouters[router] = isAllowed;
    }

    // Allows the admin to set permissions for a token.
    function setTokenPermission(address token, bool isAllowed)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        allowedTokens[token] = isAllowed;
    }

    // Allows the admin to set permissions for a farm.
    function setFarmPermission(address farm, bool isAllowed) public onlyRole(DEFAULT_ADMIN_ROLE) {
        allowedFarms[farm] = isAllowed;
    }

    // Function to perform token swaps through an approved router.
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
        // Initial balance of `tokenOut` to calculate the amount swapped.
        amountOut = IERC20(tokenOut).balanceOf(this_);

        // Approving the router to transfer `tokenIn`.
        IERC20(tokenIn).forceApprove(router, amountIn);

        // Calling the router with provided data for the swap.
        Address.functionCall(router, data);

        // Calculating the amount of `tokenOut` received after the swap.
        amountOut = IERC20(tokenOut).balanceOf(this_) - amountOut;

        // Ensuring the amount received meets the minimum requirement.
        require(amountOut >= minAmountOut, "Amount out too low");

        // Resetting approval for security.
        IERC20(tokenIn).forceApprove(router, 0);
    }

    // Function to transfer tokens to a farm.
    function send(address token, uint256 amount, address farm) external onlyRole(SEND_ROLE) {
        require(allowedTokens[token], "Token not allowed");
        require(allowedFarms[farm], "Farm not allowed");

        // Safely transferring the tokens to the farm.
        IERC20(token).safeTransfer(farm, amount);
    }

    // Function to create a new escrow.
    function escrow(Escrow calldata escrow_) external onlyRole(ESCROW_ROLE) returns (uint256 id) {
        require(allowedTokens[escrow_.tokenIn], "Token not allowed");
        require(allowedTokens[escrow_.tokenOut], "Token not allowed");

        // Adding the escrow to the list and returning its ID.
        id = _escrows.length;
        _escrows.push(escrow_);
    }

    // Function to stop an escrow by deleting it.
    function stopEscrow(uint256 id) external onlyRole(ESCROW_ROLE) {
        require(id < _escrows.length, "Escrow not found");

        // Deleting the escrow.
        delete _escrows[id];
    }

    // Function to handle an escrow by performing a token swap.
    function handleEscrow(uint256 id, uint256 tokenOutAmount, uint256 minTokenInAmount)
        external
        returns (uint256 tokenInAmount)
    {
        require(id < _escrows.length, "Escrow not found");

        Escrow memory escrow_ = _escrows[id];
        // Adjusting `tokenOutAmount` to ensure it does not exceed the minimum required.
        tokenOutAmount = Math.min(tokenOutAmount, escrow_.minAmountOut);

        address tokenIn = escrow_.tokenIn;
        address tokenOut = escrow_.tokenOut;
        address sender = msg.sender;

        // Calculating the amount of `tokenIn` to be provided based on the `tokenOutAmount`.
        tokenInAmount = Math.mulDiv(escrow_.amountIn, tokenOutAmount, escrow_.minAmountOut);
        require(tokenInAmount >= minTokenInAmount, "Amount out too low");

        // Transferring `tokenOut` from the sender and `tokenIn` to the sender.
        IERC20(tokenOut).safeTransferFrom(sender, address(this), tokenOutAmount);
        IERC20(tokenIn).safeTransfer(sender, tokenInAmount);

        // Updating escrow balances.
        escrow_.amountIn -= tokenInAmount;
        escrow_.minAmountOut -= tokenOutAmount;
        _escrows[id] = escrow_;
    }
}
