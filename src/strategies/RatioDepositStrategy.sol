// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../MetaVault.sol";
import "../interfaces/strategies/IBaseDepositStrategy.sol";
import "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

contract RatioDepositStrategy is IBaseDepositStrategy {
    using Math for uint256;

    bytes32 public constant SETTER_ROLE = keccak256("RATIO_DEPOSIT_STRATEGY_SETTER_ROLE");
    uint256 public constant D18 = 1e18;

    modifier onlySetter(address vault) {
        require(
            IAccessControlEnumerable(vault).hasRole(SETTER_ROLE, msg.sender),
            "RatioDepositStrategy: Not a setter"
        );
        _;
    }

    struct RatioData {
        uint256[] indices;
        uint256[] ratiosD18;
        bytes32 subvaultsHash;
    }

    mapping(address vault => RatioData) private _data;

    function getRatio(address metaVault_)
        external
        view
        returns (uint256[] memory, uint256[] memory)
    {
        RatioData storage data = _data[metaVault_];
        return (data.indices, data.ratiosD18);
    }

    function setVaultRatio(
        address metaVault_,
        uint256[] calldata subvaultIndices,
        uint256[] calldata ratiosD18,
        bytes32 subvaultHash
    ) external onlySetter(metaVault_) {
        require(
            subvaultIndices.length == ratiosD18.length
                && subvaultHash == MetaVault(metaVault_).subvaultsHash(),
            "RatioDepositStrategy: Invalid input"
        );
        uint256 subvaults = MetaVault(metaVault_).subvaultsCount();
        uint256 cumulativeRatioD18 = 0;
        uint256 subvaultMask = 0;
        for (uint256 i = 0; i < subvaultIndices.length; i++) {
            if (subvaultIndices[i] >= subvaults) {
                revert("RatioDepositStrategy: Invalid subvault index");
            }
            if (ratiosD18[i] > D18) {
                revert("RatioDepositStrategy: Invalid ratio");
            }
            if (((subvaultMask >> subvaultIndices[i]) & 1) == 1) {
                revert("RatioDepositStrategy: Duplicate subvault index");
            }
            subvaultMask |= 1 << subvaultIndices[i];
            cumulativeRatioD18 += ratiosD18[i];
        }

        require(
            subvaultIndices[subvaultIndices.length - 1] == 0,
            "RatioDepositStrategy: Last subvault index must be 0 (IdleVault)"
        );
        require(
            ratiosD18[subvaultIndices.length - 1] == 0,
            "RatioDepositStrategy: Last subvault ratio must be D18 (IdleVault)"
        );

        _data[metaVault_] =
            RatioData({indices: subvaultIndices, ratiosD18: ratiosD18, subvaultsHash: subvaultHash});
    }

    function calculateDepositAmounts(address metaVault_, uint256 amount)
        external
        view
        override
        returns (Data[] memory data)
    {
        MetaVault metaVault = MetaVault(metaVault_);
        if (metaVault.subvaultsHash() != _data[metaVault_].subvaultsHash) {
            revert("RatioDepositStrategy: Invalid subvaults");
        }
        uint256 subvaultsCount = metaVault.subvaultsCount();
        data = new Data[](subvaultsCount);
        RatioData memory ratioData = _data[metaVault_];
        uint256 distributed = 0;
        uint256 count = 0;
        for (uint256 i = 0; i < subvaultsCount; i++) {
            uint256 maxDeposit_ = IERC4626Vault(metaVault.subvaultAt(ratioData.indices[i]))
                .maxDeposit(address(metaVault));
            uint256 amount_ = maxDeposit_.min(
                (amount - distributed).min(
                    amount.mulDiv(ratioData.ratiosD18[i], D18, Math.Rounding.Ceil)
                )
            );
            if (amount_ == 0) {
                continue;
            }
            data[count++] = Data({subvaultIndex: ratioData.indices[i], depositAmount: amount_});
            distributed += amount_;
        }
        require(distributed == amount, "RatioDepositStrategy: Incorrect distribution");
        assembly {
            mstore(data, count)
        }
    }
}
