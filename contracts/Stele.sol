// SPDX-License-Identifier: MIT
pragma solidity =0.7.6;
pragma abicoder v2;

import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol';
import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol';
import '@uniswap/v3-periphery/contracts/libraries/OracleLibrary.sol';
import './interfaces/IERC20Minimal.sol';
import "hardhat/console.sol";

// Challenge type definition
enum ChallengeType { OneWeek, OneMonth, ThreeMonths, SixMonths, OneYear }

struct Asset {
  address tokenAddress;
  uint256 amount;
}

struct UserPortfolio {
  Asset[] assets;
}

struct Challenge {
  uint256 id;
  ChallengeType challengeType;
  uint256 startTime;
  uint256 endTime;
  uint256 totalRewards; // USD Token
  uint256 seedMoney;
  address usdToken;
  uint8 usdTokenDecimals;
  uint8 maxAssets;
  address creator;
  uint256 entryFee;
  address[10] topUsers; // 상위 10명의 주소
  uint256[10] userTotalValues; // 각 상위 참가자의 수익율
  mapping(address => UserPortfolio) portfolios;
  mapping(address => bool) isClosed;
}

contract Stele {

  address public uniswapV3Factory = 0x33128a8fC17869897dcE68Ed026d694621f6FDfD;
  address public WETH = 0x4200000000000000000000000000000000000006;

  // State variables
  address public owner;
  address public usdToken;
  uint8 public usdTokenDecimals;
  uint8 public maxAssets;
  uint256 public seedMoney;
  uint256 public entryFee;
  uint256[5] public rewardDistribution;
  mapping(address => bool) public isInvestable;

  // Challenge repository
  mapping(uint256 => Challenge) public challenges;
  uint256 public challengeCounter;
  // Active challenge ID by challenge type
  mapping(ChallengeType => uint256) public activeChallengesByType;
  
  // Event definitions
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

  modifier onlyOwner() {
      require(msg.sender == owner, 'NO');
      _;
  }
  
  // Contract constructor
  constructor(address _usdToken) {
    owner = msg.sender;
    usdToken = _usdToken;
    usdTokenDecimals = IERC20Minimal(_usdToken).decimals(); 
    maxAssets = 10;
    seedMoney = 1000; // $1000 (ex. 1000 USDC token)
    entryFee = 10; // $10 (ex. 10 USDC token)
    rewardDistribution = [50, 26, 13, 7, 4];
    isInvestable[WETH] = true;
    isInvestable[usdToken] = true;
    challengeCounter = 0;
  }

  // Duration in seconds for each challenge type
  function getDuration(ChallengeType challengeType) internal pure returns (uint256) {
    if (challengeType == ChallengeType.OneWeek) return 7 days;
    if (challengeType == ChallengeType.OneMonth) return 30 days;
    if (challengeType == ChallengeType.ThreeMonths) return 90 days;
    if (challengeType == ChallengeType.SixMonths) return 180 days;
    if (challengeType == ChallengeType.OneYear) return 365 days;
    return 0;
  }

  // Set USD token function
  function setUSDToken(address _usdToken) external onlyOwner {
    require(_usdToken != address(0), "IT");
    usdToken = _usdToken;
    usdTokenDecimals = IERC20Minimal(_usdToken).decimals();
  }

  // Reward distribution ratio setting function
  function setRewardRatio(uint256[5] calldata _rewardDistribution) external onlyOwner {
    uint256 sum = 0;
    for (uint i = 0; i < 5; i++) {
        require(_rewardDistribution[i] > 0, "IR");
        sum += _rewardDistribution[i];
    }
    require(sum == 100, "IS");
    
    rewardDistribution = _rewardDistribution;
    emit RewardRatio(_rewardDistribution);
  }
  
  // Entry fee setting function
  function setEntryFee(uint256 _entryFee) external onlyOwner {
    entryFee = _entryFee;
    emit EntryFee(_entryFee);
  }
  
  // Initial capital setting function
  function setSeedMoney(uint256 _seedMoney) external onlyOwner {
    seedMoney = _seedMoney;
    emit SeedMoney(_seedMoney);
  }
  
  // Investable token setting function
  function setToken(address tokenAddress) external onlyOwner {
    isInvestable[tokenAddress] = true;
    emit AddToken(tokenAddress);
  }
  
  // Non-investable token setting function
  function resetToken(address tokenAddress) external onlyOwner {
    isInvestable[tokenAddress] = false;
    emit RemoveToken(tokenAddress);
  }

  // Token price query function using Uniswap V3 pool
  // Get Token A price from Token B
  function getTokenPrice(address baseToken, uint128 baseAmount, address quoteToken) public returns (uint256) {
    if (baseToken == quoteToken) return baseAmount;
    
    uint16[3] memory fees = [500, 3000, 10000];
    uint256 quoteAmount = 0;

    for (uint256 i=0; i<fees.length; i++) {
      address pool = IUniswapV3Factory(uniswapV3Factory).getPool(baseToken, quoteToken, uint24(fees[i]));
      if (pool == address(0)) {
          continue;
      }

      uint32 secondsAgo = OracleLibrary.getOldestObservationSecondsAgo(pool);
      uint32 maxSecondsAgo = 300;
      secondsAgo = secondsAgo > maxSecondsAgo ? maxSecondsAgo : secondsAgo;

      (int24 tick, ) = OracleLibrary.consult(address(pool), secondsAgo);
      uint256 _quoteAmount = OracleLibrary.getQuoteAtTick(tick, baseAmount, baseToken, quoteToken);
      
      if (quoteAmount < _quoteAmount) {
        quoteAmount = _quoteAmount;
      }
    }

    emit DebugTokenPrice(baseToken, baseAmount, quoteToken, quoteAmount);
    return quoteAmount;
  }

  // Create a new challenge
  function createChallenge(ChallengeType challengeType) external {
    uint256 activeChallengeId = activeChallengesByType[challengeType];
    Challenge storage latestChallenge = challenges[activeChallengeId];
    require(block.timestamp > latestChallenge.endTime, "NE");

    uint256 challengeId = challengeCounter;
    challengeCounter++;
    
    Challenge storage challenge = challenges[challengeId];
    challenge.id = challengeId;
    challenge.challengeType = challengeType;
    challenge.startTime = block.timestamp;
    challenge.endTime = block.timestamp + getDuration(challengeType);
    challenge.totalRewards = 0;
    challenge.seedMoney = seedMoney;
    challenge.usdToken = usdToken;
    challenge.usdTokenDecimals = usdTokenDecimals;
    challenge.maxAssets = maxAssets;
    challenge.creator = msg.sender;
    challenge.entryFee = entryFee;
    
    // Initialize top users and their values
    for (uint i = 0; i < 10; i++) {
      challenge.topUsers[i] = address(0);
      challenge.userTotalValues[i] = 0;
    }
    
    // Update active challenge for this type
    activeChallengesByType[challengeType] = challengeId;
    
    emit Create(challengeId, challengeType, challenge.startTime, challenge.endTime);
  }

  // Join an existing challenge
  function joinChallenge(uint256 challengeId) external {
    Challenge storage challenge = challenges[challengeId];
    
    // Check if challenge exists and is still active
    require(challenge.startTime > 0, "CNE");
    require(block.timestamp < challenge.endTime, "E");
    require(!challenge.isClosed[msg.sender], "C");
    
    // Check if user has already joined
    require(challenge.portfolios[msg.sender].assets.length == 0, "AJ");
    
    // Calculate entry fee (USD token)
    uint256 entryFeeUSD = challenge.entryFee * 10 ** challenge.usdTokenDecimals; // Convert to token decimals
    // TODO : test
    entryFeeUSD = entryFeeUSD / 100;
    //entryFeeUSD = entryFeeUSD;

    // Transfer USD token to contract
    IERC20Minimal usdTokenContract = IERC20Minimal(challenge.usdToken);
    
    // First check if user has enough tokens
    require(usdTokenContract.balanceOf(msg.sender) >= entryFeeUSD, "NEB");
    
    // Check if user has approved the contract to transfer tokens
    require(usdTokenContract.allowance(msg.sender, address(this)) >= entryFeeUSD, "NA");
    
    // Transfer tokens
    bool transferSuccess = usdTokenContract.transferFrom(msg.sender, address(this), entryFeeUSD);
    require(transferSuccess, "TF");
    
    // Add user to challenge
    UserPortfolio storage portfolio = challenge.portfolios[msg.sender];
    
    // Initialize with seed money in USD
    Asset memory initialAsset = Asset({
      tokenAddress: challenge.usdToken,
      amount: challenge.seedMoney * 10 ** challenge.usdTokenDecimals
    });
    
    portfolio.assets.push(initialAsset);
    
    // Update challenge total rewards
    challenge.totalRewards += entryFeeUSD;
    
    emit DebugJoin(portfolio.assets[0].tokenAddress, portfolio.assets[0].amount, challenge.totalRewards);
    emit Join(challengeId, msg.sender);
  }

  // Swap assets within a challenge portfolio
  function swap(uint256 challengeId, address from, address to, uint256 amount) external {
    Challenge storage challenge = challenges[challengeId];
    
    // Validate challenge and user
    require(challenge.startTime > 0, "CNE");
    require(block.timestamp < challenge.endTime, "E");
    require(!challenge.isClosed[msg.sender], "C");
    
    // Validate assets
    require(isInvestable[from], "IF");
    require(isInvestable[to], "ITO");
    
    // Get user portfolio
    UserPortfolio storage portfolio = challenge.portfolios[msg.sender];
    require(portfolio.assets.length > 0, "UNE");
    
    // Find the source asset in portfolio
    bool found = false;
    uint256 index;
    for (uint256 i = 0; i < portfolio.assets.length; i++) {
      if (portfolio.assets[i].tokenAddress == from) {
        require(portfolio.assets[i].amount >= amount, "FAM");
        index = i;
        found = true;
        break;
      }
    }
    
    require(found, "ANE");

    // Get asset prices
    uint8 fromTokenDecimals = IERC20Minimal(from).decimals();
    uint8 toTokenDecimals = IERC20Minimal(to).decimals();

    uint256 fromPriceUSD = getTokenPrice(from, uint128(1 * 10 ** fromTokenDecimals), challenge.usdToken);
    uint256 toPriceUSD = getTokenPrice(to, uint128(1 * 10 ** toTokenDecimals), challenge.usdToken);
    
    require(amount * fromPriceUSD >= toPriceUSD);
    
    // Calculate swap amount with decimal adjustment
    uint256 toAmount;
    if (toTokenDecimals >= fromTokenDecimals) {
        // When to token has larger decimals (e.g., USDC(6) -> BTC(8))
        toAmount = amount * fromPriceUSD * (10 ** (toTokenDecimals - fromTokenDecimals)) / toPriceUSD;
    } else {
        // When from token has larger decimals (e.g., BTC(8) -> USDC(6))
        toAmount = amount * fromPriceUSD / (10 ** (fromTokenDecimals - toTokenDecimals)) / toPriceUSD;
    }
    
    // Update source asset
    portfolio.assets[index].amount -= amount;
    
    // Add or update target asset
    bool foundTarget = false;

    for (uint256 i = 0; i < portfolio.assets.length; i++) {
      if (portfolio.assets[i].tokenAddress == to) {
        portfolio.assets[i].amount += toAmount;
        foundTarget = true;
        break;
      }
    }
    
    if (!foundTarget) {
      require(portfolio.assets.length < challenge.maxAssets, "FA");
      portfolio.assets.push(Asset({
        tokenAddress: to,
        amount: toAmount
      }));
    }
    
    // Remove asset if balance is zero
    if (portfolio.assets[index].amount == 0) {
      portfolio.assets[index] = portfolio.assets[portfolio.assets.length - 1];
      portfolio.assets.pop();
    }

    emit Swap(challengeId, msg.sender, from, to, amount, fromPriceUSD, toPriceUSD, toAmount);
  }

  // Register final performance and close position
  function register(uint256 challengeId) external {
    Challenge storage challenge = challenges[challengeId];
    
    // Validate challenge and user
    require(challenge.startTime > 0, "CNE");
    require(block.timestamp < challenge.endTime, "E");
    require(!challenge.isClosed[msg.sender], "C");
    
    // Calculate total portfolio value USD
    uint256 totalValueUSD = 0;
    
    UserPortfolio storage portfolio = challenge.portfolios[msg.sender];
    for (uint256 i = 0; i < portfolio.assets.length; i++) {
      uint8 _tokenDecimals = IERC20Minimal(portfolio.assets[i].tokenAddress).decimals();
      uint256 assetPriceUSD = getTokenPrice(portfolio.assets[i].tokenAddress, uint128(1 * 10 ** _tokenDecimals), challenge.usdToken);
      uint256 assetValueUSD = (portfolio.assets[i].amount / 10 ** _tokenDecimals) * assetPriceUSD;
      totalValueUSD += assetValueUSD;
    }
    
    // Update ranking
    updateRanking(challengeId, msg.sender, totalValueUSD);
    
    // Mark position as closed
    challenge.isClosed[msg.sender] = true;
    
    emit Register(challengeId, msg.sender, totalValueUSD);
  }

  // Helper function to update top performers
  function updateRanking(uint256 challengeId, address user, uint256 totalValueUSD) internal {
    Challenge storage challenge = challenges[challengeId];
    
    // Check if user is already in top performers
    bool isAlreadyTop = false;
    uint256 existingIndex;
    
    for (uint256 i = 0; i < 10; i++) {
      if (challenge.topUsers[i] == user) {
        isAlreadyTop = true;
        existingIndex = i;
        break;
      }
    }
    
    if (isAlreadyTop) {
      // Update existing entry
      challenge.userTotalValues[existingIndex] = totalValueUSD;
      
      // Re-sort if needed
      for (uint256 i = existingIndex; i > 0; i--) {
        if (challenge.userTotalValues[i] > challenge.userTotalValues[i-1]) {
          // Swap positions
          (challenge.topUsers[i], challenge.topUsers[i-1]) = 
              (challenge.topUsers[i-1], challenge.topUsers[i]);
          (challenge.userTotalValues[i], challenge.userTotalValues[i-1]) = 
              (challenge.userTotalValues[i-1], challenge.userTotalValues[i]);
        } else {
          break;
        }
      }
    } else {
      // Check if totalValue is higher than the lowest in top 10
      if (challenge.topUsers[9] == address(0) || totalValueUSD > challenge.userTotalValues[9]) {
        // Replace the last entry
        challenge.topUsers[9] = user;
        challenge.userTotalValues[9] = totalValueUSD;
        
        // Bubble up to correct position
        for (uint256 i = 9; i > 0; i--) {
          if (challenge.userTotalValues[i] > challenge.userTotalValues[i-1]) {
            // Swap positions
            (challenge.topUsers[i], challenge.topUsers[i-1]) = 
                (challenge.topUsers[i-1], challenge.topUsers[i]);
            (challenge.userTotalValues[i], challenge.userTotalValues[i-1]) = 
                (challenge.userTotalValues[i-1], challenge.userTotalValues[i]);
          } else {
            break;
          }
        }
      }
    }
  }

  // Claim rewards after challenge ends
  function getRewards(uint256 challengeId) external onlyOwner {
    Challenge storage challenge = challenges[challengeId];
    
    // Validate challenge
    require(challenge.startTime > 0, "CNE");
    require(block.timestamp >= challenge.endTime, "NE");
    
    // Rewards distribution to top 5 participants
    uint256 undistributed = challenge.totalRewards;
    IERC20Minimal usdTokenContract = IERC20Minimal(challenge.usdToken);
    
    // Check USD token balance of the contract
    uint256 balance = usdTokenContract.balanceOf(address(this));
    require(balance > undistributed, "NBR");
    
    // Calculate actual ranker count and initial rewards
    uint8 actualRankerCount = 0;
    address[5] memory validRankers;
    uint256[5] memory initialRewards;
    uint256 totalInitialRewardWeight = 0;
    
    for (uint8 i = 0; i < 5; i++) {
      address userAddress = challenge.topUsers[i];
      if (userAddress != address(0)) {
        validRankers[actualRankerCount] = userAddress;
        initialRewards[actualRankerCount] = rewardDistribution[i];
        totalInitialRewardWeight += rewardDistribution[i];
        actualRankerCount++;
      }
    }
    
    // Only distribute rewards if there are actual rankers
    if (actualRankerCount > 0) {
      // Distribute rewards to each ranker
      for (uint8 i = 0; i < actualRankerCount; i++) {
        address userAddress = validRankers[i];
        
        // Calculate reward based on original ratio
        uint256 adjustedRatio = initialRewards[i] * 100 / totalInitialRewardWeight;
        uint256 rewardAmount = (challenge.totalRewards * adjustedRatio) / 100;
        
        // Cannot distribute more than the available balance
        if (rewardAmount > undistributed) {
          rewardAmount = undistributed;
        }
        
        if (rewardAmount > 0) {
          bool success = usdTokenContract.transfer(userAddress, rewardAmount);
          require(success, "RTF");
          
          undistributed -= rewardAmount;

          emit Claim(challengeId, userAddress, rewardAmount);
        }
      }
    }
  }
}