/// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { AaveV3ERC4626 } from "yield-daddy/aave-v3/AaveV3ERC4626.sol";
import { TwabRewards, TwabController, IERC20 } from "pt-v5-twab-rewards/TwabRewards.sol";

contract AaveV3ERC4626TwabRewards {

    event RewardsDistributed(
        address indexed prizeVault,
        AaveV3ERC4626 indexed yieldVault,
        IERC20 indexed rewardToken,
        uint256 rewardsDistributed,
        uint256 startTime,
        uint256 endTime
    );

    error TooEarlyToStartPromotion(uint256 nextPromotionStartTime, uint256 currentTimestamp);
    error PromotionTooShort(uint256 promotionDuration, uint256 minPromotionSpacing);

    TwabRewards public immutable twabRewards;
    address public immutable prizeVault;
    uint256 public immutable minPromotionSpacing;

    mapping(IERC20 rewardToken => uint256 lastPromotionEndTime) public lastPromotionEndTime;

    /// @notice Constructs a new Twab Rewards controller for an Aave V3 wrapped vault.
    /// @dev prizeVault address will likely need to be pre-computed
    /// @param twabRewards_ The TWAB rewards contract
    /// @param prizeVault_ The prize vault to send the rewards to
    /// @param minPromotionSpacing_ The minimum amount of seconds that must pass before starting a new promotion
    constructor(TwabRewards twabRewards_, address prizeVault_, uint256 minPromotionSpacing_) {
        twabRewards = twabRewards_;
        prizeVault = prizeVault_;
        minPromotionSpacing = minPromotionSpacing_;
    }

    /// @notice Distributes accrued rewards through TWAB rewards.
    /// @dev The start time of the promotion if set to the end time of the last promotion for simplicity. This will result
    /// in older depositors receiving some of the rewards that newer deposits generated. If this behaviour is not desirable,
    /// anyone can permissionlessly trigger an empty distribution right at the start of the reward accrual to ensure only
    /// new deposits are rewarded.
    /// @param wrappedAaveV3Vault The wrapped Aave v3 vault to pull rewards from
    /// @param rewardToken The reward token to claim and distribute
    function distributeRewards(AaveV3ERC4626 wrappedAaveV3Vault, IERC20 rewardToken) external {
        TwabController twabController = twabRewards.twabController();
        uint256 periodOffset = twabController.PERIOD_OFFSET();

        uint256 assetLastPromotionEndTime = lastPromotionEndTime[rewardToken];
        uint256 startTime = periodOffset > assetLastPromotionEndTime ? periodOffset : assetLastPromotionEndTime;
        if (startTime >= block.timestamp) revert TooEarlyToStartPromotion(startTime, block.timestamp);
        uint256 endTime = twabController.periodEndOnOrAfter(block.timestamp);
        if (endTime - startTime < minPromotionSpacing) revert PromotionTooShort(endTime - startTime, minPromotionSpacing);

        wrappedAaveV3Vault.claimRewards();

        uint256 rewardsToDistribute = rewardToken.balanceOf(address(this));
        if (rewardsToDistribute > 0) {
            twabRewards.createPromotion(
                prizeVault,
                rewardToken,
                uint64(startTime),
                rewardsToDistribute,
                uint48(endTime - startTime),
                1 // each promotion is only 1 epoch
            );
        }

        // We still update the last promotion end time even if there were no rewards to distribute incase this was called
        // to "reset" the promotion eligibility for new rewards.
        lastPromotionEndTime[rewardToken] = endTime;
        emit RewardsDistributed(prizeVault, wrappedAaveV3Vault, rewardToken, rewardsToDistribute, startTime, endTime);
    }

}
