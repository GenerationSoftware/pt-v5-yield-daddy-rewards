/// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { AaveV3ERC4626 } from "yield-daddy/aave-v3/AaveV3ERC4626.sol";
import {
    TpdaLiquidationPairFactory,
    ILiquidationSource
} from "pt-v5-tpda-liquidator/TpdaLiquidationPairFactory.sol";
import { TpdaLiquidationPair } from "pt-v5-tpda-liquidator/TpdaLiquidationPair.sol";
import { IERC20 } from "openzeppelin/token/ERC20/IERC20.sol";
import { SafeERC20 } from "openzeppelin/token/ERC20/utils/SafeERC20.sol";

import { IPrizePool } from "./external/interfaces/IPrizePool.sol";

contract AaveV3ERC4626Liquidator is ILiquidationSource {
    using SafeERC20 for IERC20;

    address public immutable creator;
    address public immutable vaultBeneficiary;
    IPrizePool public immutable prizePool;
    TpdaLiquidationPairFactory public immutable liquidationPairFactory;
    uint256 public immutable targetAuctionPeriod;
    uint192 public immutable targetAuctionPrice;
    uint256 public immutable smoothingFactor;

    AaveV3ERC4626 public yieldVault;

    mapping(address tokenOut => TpdaLiquidationPair liquidationPair) public liquidationPairs;

    constructor(
        address _creator,
        address _vaultBeneficiary,
        IPrizePool _prizePool,
        TpdaLiquidationPairFactory _liquidationPairFactory,
        uint256 _targetAuctionPeriod,
        uint192 _targetAuctionPrice,
        uint256 _smoothingFactor
    ) {
        vaultBeneficiary = _vaultBeneficiary;
        targetAuctionPeriod = _targetAuctionPeriod;
        targetAuctionPrice = _targetAuctionPrice;
        smoothingFactor = _smoothingFactor;
        prizePool = _prizePool;
        liquidationPairFactory = _liquidationPairFactory;
        creator = _creator;
    }

    function setYieldVault(AaveV3ERC4626 _yieldVault) external {
        require(msg.sender == creator, "AaveV3ERC4626Liquidator: FORBIDDEN");
        require(address(yieldVault) == address(0), "AaveV3ERC4626Liquidator: ALREADY_SET");
        require(_yieldVault.rewardRecipient() == address(this), "Not reward recipient");
        yieldVault = _yieldVault;
    }

    function addPair(address tokenOut) external {
        if (address(liquidationPairs[tokenOut]) != address(0)) {
            revert("Already initialized");
        }
        liquidationPairs[tokenOut] = liquidationPairFactory.createPair(
            this,
            address(prizePool.prizeToken()),
            tokenOut,
            targetAuctionPeriod,
            targetAuctionPrice,
            smoothingFactor
        );
    }

    /**
    * @notice Get the available amount of tokens that can be swapped.
    * @param tokenOut Address of the token to get available balance for
    * @return uint256 Available amount of `token`
    */
    function liquidatableBalanceOf(address tokenOut) external returns (uint256) {
        yieldVault.claimRewards();
        return IERC20(tokenOut).balanceOf(address(this));
    }

    /// @inheritdoc ILiquidationSource
    function transferTokensOut(
        address sender,
        address receiver,
        address tokenOut,
        uint256 amountOut
    ) external returns (bytes memory) {
        require(msg.sender == address(liquidationPairs[tokenOut]), "AaveV3ERC4626Liquidator: FORBIDDEN");
        IERC20(tokenOut).safeTransfer(receiver, amountOut);
    }

    /// @inheritdoc ILiquidationSource
    function verifyTokensIn(
        address tokenIn,
        uint256 amountIn,
        bytes calldata transferTokensOutData
    ) external {
        prizePool.contributePrizeTokens(vaultBeneficiary, amountIn);
    }

    /// @inheritdoc ILiquidationSource
    function targetOf(address tokenIn) external returns (address) {
        return address(prizePool);
    }

    /// @inheritdoc ILiquidationSource
    function isLiquidationPair(address tokenOut, address liquidationPair) external returns (bool) {
        return address(liquidationPairs[tokenOut]) == liquidationPair;
    }
}
