// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "./Oracle.sol";
import "@openzeppelin/contracts/interfaces/IERC4626.sol";

contract OracleFactory {
    mapping(address vault => mapping(bool isETHBased => address oracle)) public oracles;

    function create(address vault, bool isETHBased) public returns (address oracle) {
        if (oracles[vault][isETHBased] != address(0)) {
            revert("OracleFactory: oracle already exists");
        }

        bytes32 salt = keccak256(abi.encodePacked(vault, isETHBased));
        oracle = address(new Oracle{salt: salt}(vault, isETHBased));
        oracles[vault][isETHBased] = oracle;
    }

    function multiCreate(address[] calldata vault, bool[] calldata isETHBased) external {
        require(vault.length == isETHBased.length, "OracleFactory: invalid length");

        for (uint256 i = 0; i < vault.length; i++) {
            create(vault[i], isETHBased[i]);
        }
    }
}
