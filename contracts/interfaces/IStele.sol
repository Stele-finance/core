// SPDX-License-Identifier: MIT
pragma solidity =0.7.6;
pragma abicoder v2;

interface IStele {
    // Enums
    enum ChallengeType { OneWeek, OneMonth, ThreeMonths, SixMonths, OneYear }
    
    // Events
    event RewardRatio(uint256[5] newRewardDistribution);
    event EntryFee(uint256 newEntryFee);
    event MaxAssets(uint8 newMaxAssets);
    event SeedMoney(uint256 newSeedMoney);
    event AddToken(address tokenAddress);
    event RemoveToken(address tokenAddress);
    event Create(uint256 challengeId, ChallengeType challengeType, uint256 startTime, uint256 endTime);
    event Join(uint256 challengeId, address user);
    event Swap(uint256 challengeId, address user, address fromAsset, address toAsset, uint256 fromAmount, uint256 fromPriceUSD, uint256 toPriceUSD, uint256 toAmount);
    event Register(uint256 challengeId, address user, uint256 performance);
    event Claim(uint256 challengeId, address user, uint256 rewardAmount);
    event DebugJoin(address tokenAddress, uint256 amount, uint256 totalRewards);
    event DebugTokenPrice(address baseToken, uint128 baseAmount, address quoteToken, uint256 quoteAmount);

    // Read functions
    function owner() external view returns (address);
    function uniswapV3Factory() external view returns (address);
    function WETH() external view returns (address);
    function usdToken() external view returns (address);
    function usdTokenDecimals() external view returns (uint8);
    function maxAssets() external view returns (uint8);
    function seedMoney() external view returns (uint256);
    function entryFee() external view returns (uint256);
    function rewardDistribution(uint256 index) external view returns (uint256);
    function isInvestable(address tokenAddress) external view returns (bool);
    function challenges(uint256 challengeId) external view returns (
        uint256 _id,
        ChallengeType _challengeType,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _totalRewards,
        uint256 _seedMoney,
        address _usdToken,
        uint8 _usdTokenDecimals,
        uint8 _maxAssets,
        address _creator,
        uint256 _entryFee
    );
    function challengeCounter() external view returns (uint256);
    function latestChallengesByType(ChallengeType challengeType) external view returns (uint256);
    
    // Governance functions (onlyOwner)
    function setUSDToken(address _usdToken) external;
    function setRewardRatio(uint256[5] calldata _rewardDistribution) external;
    function setEntryFee(uint256 _entryFee) external;
    function setSeedMoney(uint256 _seedMoney) external;
    function setToken(address tokenAddress) external;
    function resetToken(address tokenAddress) external;

    // Challenge management functions
    function createChallenge(ChallengeType challengeType) external;
    function joinChallenge(uint256 challengeId) external;
    function swap(uint256 challengeId, address from, address to, uint256 amount) external;
    function register(uint256 challengeId) external;
    
    // Reward function (onlyOwner)
    function getRewards(uint256 challengeId) external;
    
    // Price function
    function getTokenPrice(address baseToken, uint128 baseAmount, address quoteToken) external returns (uint256);
} 