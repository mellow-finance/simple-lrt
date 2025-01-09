// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/tokens/IWETH.sol";
import "../interfaces/tokens/IWSTETH.sol";
import "../interfaces/utils/IStakingModule.sol";
import "./ERC4626CompatVault.sol";
import "./VaultControlStorage.sol";
import {ERC20Upgradeable} from
    "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts/access/IAccessControl.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";

abstract contract DVVStorage is VaultControlStorage {
    using SafeERC20 for IERC20;

    struct DVVStorageStruct {
        address yieldVault;
        address stakingModule;
    }

    bytes32 private immutable storageSlotRef;
    IWSTETH public immutable WSTETH;
    IWETH public immutable WETH;

    constructor(bytes32 name_, uint256 version_, address wsteth_, address weth_)
        VaultControlStorage(name_, version_)
    {
        storageSlotRef = keccak256(
            abi.encode(
                uint256(
                    keccak256(
                        abi.encodePacked("mellow.simple-lrt.storage.DVVStorage", name_, version_)
                    )
                ) - 1
            )
        ) & ~bytes32(uint256(0xff));
        WSTETH = IWSTETH(wsteth_);
        WETH = IWETH(weth_);

        _disableInitializers();
    }

    function __init_DVVStorage(address _stakingModule, address _yieldVault)
        internal
        onlyInitializing
    {
        _setStakingModule(_stakingModule);
        _setYieldVault(_yieldVault);
    }

    function yieldVault() public view returns (IERC4626) {
        return IERC4626(_dvvStorage().yieldVault);
    }

    function stakingModule() public view returns (IStakingModule) {
        return IStakingModule(_dvvStorage().stakingModule);
    }

    function _setStakingModule(address newStakingModule) internal {
        require(newStakingModule != address(0), "DVV: zero address");
        _dvvStorage().stakingModule = newStakingModule;
    }

    function _setYieldVault(address yieldVault_) internal onlyInitializing {
        require(yieldVault_ != address(0), "DVV: zero address");
        require(IERC4626(yieldVault_).asset() == address(WSTETH), "DVV: invalid asset");
        _dvvStorage().yieldVault = yieldVault_;
    }

    function _dvvStorage() private view returns (DVVStorageStruct storage $) {
        bytes32 slot = storageSlotRef;
        assembly {
            $.slot := slot
        }
    }
}
