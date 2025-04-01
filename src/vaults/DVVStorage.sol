// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/tokens/IWETH.sol";
import "../interfaces/tokens/IWSTETH.sol";
import "../interfaces/utils/IStakingModule.sol";
import "./VaultControlStorage.sol";

import {
    ERC4626Upgradeable,
    IERC4626
} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

interface IAToken is IERC20 {
    function POOL() external view returns (IAPool);

    function UNDERLYING_ASSET_ADDRESS() external view returns (address);
}

interface IAPool {
    function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode)
        external;

    function withdraw(address asset, uint256 amount, address to) external returns (uint256);

    struct ReserveConfigurationMap {
        uint256 data;
    }

    struct ReserveDataLegacy {
        ReserveConfigurationMap configuration;
        uint128 liquidityIndex;
        uint128 currentLiquidityRate;
        uint128 variableBorrowIndex;
        uint128 currentVariableBorrowRate;
        uint128 currentStableBorrowRate;
        uint40 lastUpdateTimestamp;
        uint16 id;
        address aTokenAddress;
        address stableDebtTokenAddress;
        address variableDebtTokenAddress;
        address interestRateStrategyAddress;
        uint128 accruedToTreasury;
        uint128 unbacked;
        uint128 isolationModeTotalDebt;
    }

    function getReserveData(address asset) external view returns (ReserveDataLegacy memory);
}

abstract contract DVVStorage is VaultControlStorage {
    struct DVVStorageStruct {
        address stakingModule;
    }

    /// @dev abi.encode(uint256(keccak256(abi.encodePacked("mellow.simple-lrt.storage.DVVStorage"))) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant storageSlotRef =
        0xb0787753e394c40407d3a492a97769e1ad930648e15771df7fdf39acdc744e00;
    IAToken public immutable AAVE_WSTETH;
    IAToken public immutable AAVE_WETH;
    IAPool public immutable AAVE_POOL;
    IWSTETH public immutable WSTETH;
    IWETH public immutable WETH;

    constructor(address aaveWstETH_, address aaveWETH_) VaultControlStorage("DVVStorage", 1) {
        AAVE_WSTETH = IAToken(aaveWstETH_);
        AAVE_WETH = IAToken(aaveWETH_);
        AAVE_POOL = AAVE_WSTETH.POOL();
        WSTETH = IWSTETH(AAVE_WSTETH.UNDERLYING_ASSET_ADDRESS());
        WETH = IWETH(AAVE_WETH.UNDERLYING_ASSET_ADDRESS());
        _disableInitializers();
    }

    function __init_DVVStorage(address _stakingModule) internal onlyInitializing {
        _setStakingModule(_stakingModule);
    }

    function stakingModule() public view returns (IStakingModule) {
        return IStakingModule(_dvvStorage().stakingModule);
    }

    function _setStakingModule(address newStakingModule) internal {
        require(newStakingModule != address(0), "DVV: zero address");
        _dvvStorage().stakingModule = newStakingModule;
        emit StakingModuleSet(newStakingModule);
    }

    function _dvvStorage() private pure returns (DVVStorageStruct storage $) {
        assembly {
            $.slot := storageSlotRef
        }
    }

    event StakingModuleSet(address indexed newStakingModule);
}
