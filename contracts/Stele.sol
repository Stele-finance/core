// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.28;

import './interfaces/IERC20Minimal.sol';
import './interfaces/IStele.sol';
import {PriceOracle, IUniswapV3Factory} from './libraries/PriceOracle.sol';
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

struct Token {
  address tokenAddress;
  uint256 amount;
}

struct UserPortfolio {
  Token[] tokens;
}

struct Challenge {
  uint256 id;
  IStele.ChallengeType challengeType;
  uint256 startTime;
  uint256 endTime;
  uint256 totalRewards; // USD Token
  uint256 seedMoney;
  uint256 entryFee;
  uint32 totalUsers;
  address[5] topUsers; // top 5 users
  uint256[5] scores; // scores of top 5 users
  mapping(address => UserPortfolio) portfolios;
}

// Interface for StelePerformanceNFT contract
interface IStelePerformanceNFT {
  function mintPerformanceNFT(
    uint256 challengeId,
    address user,
    uint32 totalUsers,
    uint256 finalScore,
    uint8 rank,
    uint256 initialValue,
    IStele.ChallengeType challengeType,
    uint256 challengeStartTime
  ) external returns (uint256);
  
  function canMintNFT(uint256 challengeId, address user) external view returns (bool);
}

contract Stele is IStele, ReentrancyGuard {  
  address public constant uniswapV3Factory = 0x1F98431c8aD98523631AE4a59f267346ea31F984;
  
  // State variables
  address public override owner;
  
  address public override usdToken;
  address public override weth9;
  address public override wbtc;
  address public override uni;
  address public override link;

  uint256 public override seedMoney;
  uint256 public override entryFee;
  uint8 public override usdTokenDecimals;
  uint8 public override maxTokens;
  uint256[5] public override rewardRatio;
  mapping(address => bool) public override isInvestable;
  mapping(uint256 => bool) public override rewardsDistributed;

  // Challenge repository
  mapping(uint256 => Challenge) public challenges;
  uint256 public override challengeCounter;
  // Latest challenge ID by challenge type
  mapping(IStele.ChallengeType => uint256) public override latestChallengesByType;

  // NFT contract address
  address public override performanceNFTContract;

  modifier onlyOwner() {
      require(msg.sender == owner, 'NO');
      _;
  }
  
  // Contract constructor
  constructor(address _weth9, address _usdToken, address _wbtc, address _uni, address _link) {
    owner = msg.sender;

    usdToken = _usdToken;
    weth9 = _weth9;
    wbtc = _wbtc;
    uni = _uni;
    link = _link;

    usdTokenDecimals = IERC20Minimal(_usdToken).decimals(); 
    maxTokens = 10;
    seedMoney = 1000 * 10**usdTokenDecimals;
    entryFee = 5 * 10**usdTokenDecimals; // 5 USD
    rewardRatio = [50, 26, 13, 7, 4];
    challengeCounter = 0;

    // Initialize investable tokens directly
    isInvestable[weth9] = true;
    emit AddToken(weth9);
    isInvestable[usdToken] = true;
    emit AddToken(usdToken);
    isInvestable[wbtc] = true;
    emit AddToken(wbtc);
    isInvestable[uni] = true;
    emit AddToken(uni);
    isInvestable[link] = true;
    emit AddToken(link);

    emit SteleCreated(owner, usdToken, maxTokens, seedMoney, entryFee, rewardRatio);
  }

  // Duration in seconds for each challenge type
  function getDuration(IStele.ChallengeType challengeType) internal pure returns (uint256) {
    if (challengeType == IStele.ChallengeType.OneWeek) return 7 days;
    if (challengeType == IStele.ChallengeType.OneMonth) return 30 days;
    if (challengeType == IStele.ChallengeType.ThreeMonths) return 90 days;
    if (challengeType == IStele.ChallengeType.SixMonths) return 180 days;
    if (challengeType == IStele.ChallengeType.OneYear) return 365 days;
    return 0;
  }

  // Get challenge basic info (cannot return mappings in interface)
  function getChallengeInfo(uint256 challengeId) external view override returns (
    uint256 _id,
    IStele.ChallengeType _challengeType,
    uint256 _startTime,
    uint256 _endTime,
    uint256 _totalRewards,
    uint256 _seedMoney,
    uint256 _entryFee,
    uint32 _totalUsers
  ) {
    Challenge storage challenge = challenges[challengeId];
    return (
      challenge.id,
      challenge.challengeType,
      challenge.startTime,
      challenge.endTime,
      challenge.totalRewards,
      challenge.seedMoney,
      challenge.entryFee,
      challenge.totalUsers
    );
  }

  // Get user's portfolio in a specific challenge
  function getUserPortfolio(uint256 challengeId, address user) external view override returns (address[] memory tokenAddresses, uint256[] memory amounts) {
    Challenge storage challenge = challenges[challengeId];
    require(challenge.startTime > 0, "CNE");
    
    UserPortfolio memory portfolio = challenge.portfolios[user];
    uint256 tokenCount = portfolio.tokens.length;

    tokenAddresses = new address[](tokenCount);
    amounts = new uint256[](tokenCount);

    for (uint256 i = 0; i < tokenCount; i++) {
      tokenAddresses[i] = portfolio.tokens[i].tokenAddress;
      amounts[i] = portfolio.tokens[i].amount;
    }
    
    return (tokenAddresses, amounts);
  }


  // Create a new challenge
  function createChallenge(IStele.ChallengeType challengeType) external override {
    uint256 latestChallengeId = latestChallengesByType[challengeType];
    // Only allow creating a new challenge if it's the first challenge or the previous challenge has ended
    if (latestChallengeId != 0) {
      require(block.timestamp > challenges[latestChallengeId].endTime, "NE");
    }

    challengeCounter++;
    uint256 challengeId = challengeCounter;

    // Update latest challenge for this type
    latestChallengesByType[challengeType] = challengeId;

    Challenge storage challenge = challenges[challengeId];
    challenge.id = challengeId;
    challenge.challengeType = challengeType;
    challenge.startTime = block.timestamp;
    challenge.endTime = block.timestamp + getDuration(challengeType);
    challenge.totalRewards = 0;
    challenge.seedMoney = seedMoney;
    challenge.entryFee = entryFee;
    challenge.totalUsers = 0;
    
    // Initialize top users and their values
    for (uint i = 0; i < 5; i++) {
      challenge.topUsers[i] = address(0);
      challenge.scores[i] = 0;
    }
    
    emit Create(challengeId, challengeType, challenge.seedMoney, challenge.entryFee);
  }

  // Join an existing challenge
  function joinChallenge(uint256 challengeId) external override nonReentrant {
    Challenge storage challenge = challenges[challengeId];
    
    // Check if challenge exists and is still active
    require(challenge.startTime > 0, "CNE");
    require(block.timestamp < challenge.endTime, "E");
    
    // Check if user has already joined
    require(challenge.portfolios[msg.sender].tokens.length == 0, "AJ");
    
    // Transfer USD token to contract
    IERC20Minimal usdTokenContract = IERC20Minimal(usdToken);
    
    // First check if user has enough tokens
    require(usdTokenContract.balanceOf(msg.sender) >= challenge.entryFee, "NEB");
    
    // Check if user has approved the contract to transfer tokens
    require(usdTokenContract.allowance(msg.sender, address(this)) >= challenge.entryFee, "NA");
    
    // Transfer tokens
    bool transferSuccess = usdTokenContract.transferFrom(msg.sender, address(this), challenge.entryFee);
    require(transferSuccess, "TF");
    
    // Add user to challenge
    UserPortfolio storage portfolio = challenge.portfolios[msg.sender];
    
    // Initialize with seed money in USD
    Token memory initialToken = Token({
      tokenAddress: usdToken,
      amount: challenge.seedMoney
    });

    portfolio.tokens.push(initialToken);

    // Update challenge total rewards
    challenge.totalRewards = challenge.totalRewards + challenge.entryFee;
    challenge.totalUsers = uint32(challenge.totalUsers + 1);

    emit Join(challengeId, msg.sender, challenge.seedMoney);

    register(challengeId); // Auto-register after joining to update ranking
  }

  // Swap tokens within a challenge portfolio
  function swap(uint256 challengeId, address tokenIn, address tokenOut, uint256 amount) external override {
    Challenge storage challenge = challenges[challengeId];
    
    // Validate challenge and user
    require(challenge.startTime > 0, "CNE");
    require(block.timestamp < challenge.endTime, "E");
    
    // Validate tokens
    require(tokenIn != tokenOut, "ST"); // Prevent same token swap
    require(isInvestable[tokenOut], "IT"); // Not investableToken
    
    // Get user portfolio
    UserPortfolio storage portfolio = challenge.portfolios[msg.sender];
    require(portfolio.tokens.length > 0, "UNE");
    
    // Find the source token in portfolio
    bool found = false;
    uint256 index;
    for (uint256 i = 0; i < portfolio.tokens.length; i++) {
      if (portfolio.tokens[i].tokenAddress == tokenIn) {
        require(portfolio.tokens[i].amount >= amount, "FTM");
        index = i;
        found = true;
        break;
      }
    }
    
    require(found, "ANE");

    // Get token prices using ETH as intermediate
    uint8 tokenInDecimals = IERC20Minimal(tokenIn).decimals();
    uint8 tokenOutDecimals = IERC20Minimal(tokenOut).decimals();

    uint256 tokenInPriceUSD;
    uint256 tokenOutPriceUSD;

    // Calculate tokenInPriceUSD using ETH as intermediate
    if (tokenIn == usdToken) {
      tokenInPriceUSD = 1 * 10 ** usdTokenDecimals;
    } else if (tokenIn == weth9) {
      tokenInPriceUSD = PriceOracle.getETHPriceUSD(uniswapV3Factory, weth9, usdToken);
    } else {
      tokenInPriceUSD = (PriceOracle.getTokenPriceETH(uniswapV3Factory, tokenIn, weth9, uint128(1 * 10 ** tokenInDecimals)) * PriceOracle.getETHPriceUSD(uniswapV3Factory, weth9, usdToken)) / 10 ** 18;
    }

    // Calculate tokenOutPriceUSD using ETH as intermediate
    if (tokenOut == usdToken) {
      tokenOutPriceUSD = 1 * 10 ** usdTokenDecimals;
    } else if (tokenOut == weth9) {
      tokenOutPriceUSD = PriceOracle.getETHPriceUSD(uniswapV3Factory, weth9, usdToken);
    } else {
      tokenOutPriceUSD = (PriceOracle.getTokenPriceETH(uniswapV3Factory, tokenOut, weth9, uint128(1 * 10 ** tokenOutDecimals)) * PriceOracle.getETHPriceUSD(uniswapV3Factory, weth9, usdToken)) / 10 ** 18;
    }
        
    // Validate that prices are available
    require(tokenInPriceUSD > 0, "FP0");
    require(tokenOutPriceUSD > 0, "TP0");

    // Calculate swap amount with high precision using mulDiv
    // Step 1: Convert amount to USD value
    uint256 valueInUSD = PriceOracle.mulDiv(
      amount,
      tokenInPriceUSD,
      10 ** tokenInDecimals
    );

    // Step 2: Convert USD value to output token amount
    uint256 toAmount = PriceOracle.mulDiv(
      valueInUSD,
      10 ** tokenOutDecimals,
      tokenOutPriceUSD
    );

    // Ensure swap amount is not zero
    require(toAmount > 0, "TA0");
    
    // Update source token balance
    portfolio.tokens[index].amount = portfolio.tokens[index].amount - amount;

    // Add or update target token balance
    bool foundTarget = false;

    for (uint256 i = 0; i < portfolio.tokens.length; i++) {
      if (portfolio.tokens[i].tokenAddress == tokenOut) {
        portfolio.tokens[i].amount = portfolio.tokens[i].amount + toAmount;
        foundTarget = true;
        break;
      }
    }
    
    if (!foundTarget) {
      require(portfolio.tokens.length < maxTokens, "FA");
      portfolio.tokens.push(Token({
        tokenAddress: tokenOut,
        amount: toAmount
      }));
    }
    
    // Remove token if balance is zero
    if (portfolio.tokens[index].amount == 0) {
      // Only reorganize array if not already the last element
      if (index != portfolio.tokens.length - 1) {
        portfolio.tokens[index] = portfolio.tokens[portfolio.tokens.length - 1];
      }
      portfolio.tokens.pop();
    }

    emit Swap(challengeId, msg.sender, tokenIn, tokenOut, amount, toAmount);

    register(challengeId); // Auto-register after swap to update ranking
  }

  // Register latest performance
  function register(uint256 challengeId) public override {
    Challenge storage challenge = challenges[challengeId];

    // Validate challenge and user
    require(challenge.startTime > 0, "CNE");
    require(block.timestamp < challenge.endTime, "E");

    // Check if user has joined the challenge
    UserPortfolio memory portfolio = challenge.portfolios[msg.sender];
    require(portfolio.tokens.length > 0, "NJ"); // Not Joined

    // Calculate total portfolio value USD using ETH as intermediate
    uint256 userScore = 0;
    uint256 ethPriceUSD = PriceOracle.getETHPriceUSD(uniswapV3Factory, weth9, usdToken); // Get ETH price once for efficiency
    for (uint256 i = 0; i < portfolio.tokens.length; i++) {
      address tokenAddress = portfolio.tokens[i].tokenAddress;
      uint8 _tokenDecimals = IERC20Minimal(tokenAddress).decimals();

      if(!isInvestable[tokenAddress]) continue;

      uint256 tokenPriceUSD;
      if (tokenAddress == usdToken) {
        tokenPriceUSD = 1 * 10 ** usdTokenDecimals;
      } else if (tokenAddress == weth9) {
        tokenPriceUSD = ethPriceUSD;
      } else {
        uint256 tokenPriceETH = PriceOracle.getTokenPriceETH(uniswapV3Factory, tokenAddress, weth9, uint128(1 * 10 ** _tokenDecimals));
        tokenPriceUSD = (tokenPriceETH * ethPriceUSD) / 10 ** 18;
      }

      uint256 tokenValueUSD = (portfolio.tokens[i].amount * tokenPriceUSD) / 10 ** _tokenDecimals;
      userScore = userScore + tokenValueUSD;
    }
    
    // Update ranking
    updateRanking(challengeId, msg.sender, userScore);
    
    emit Register(challengeId, msg.sender, userScore);    
  }

  // Helper function to update top performers (optimized)
  function updateRanking(uint256 challengeId, address user, uint256 userScore) internal {
    Challenge storage challenge = challenges[challengeId];
    
    // Check if user is already in top performers
    int256 existingIndex = -1;
    
    for (uint256 i = 0; i < 5; i++) {
      if (challenge.topUsers[i] == user) {
        existingIndex = int256(i);
        break;
      }
    }
    
    if (existingIndex >= 0) {
      // User already exists - remove and reinsert
      uint256 idx = uint256(existingIndex);
      
      // Shift elements to remove current position
      for (uint256 i = idx; i < 4; i++) {
        challenge.topUsers[i] = challenge.topUsers[i + 1];
        challenge.scores[i] = challenge.scores[i + 1];
      }
      
      // Clear last position
      challenge.topUsers[4] = address(0);
      challenge.scores[4] = 0;
    }
    
    // Find insertion position using binary search concept (for sorted array)
    uint256 insertPos = 5; // Default: not in top 5
    
    for (uint256 i = 0; i < 5; i++) {
      if (challenge.topUsers[i] == address(0) || userScore > challenge.scores[i]) {
        insertPos = i;
        break;
      }
    }
    
    // Insert if position found
    if (insertPos < 5) {
      // Shift elements to make space
      for (uint256 i = 4; i > insertPos; i--) {
        challenge.topUsers[i] = challenge.topUsers[i - 1];
        challenge.scores[i] = challenge.scores[i - 1];
      }
      
      // Insert new entry
      challenge.topUsers[insertPos] = user;
      challenge.scores[insertPos] = userScore;
    }
  }
  
  function getRanking(uint256 challengeId) external view override returns (address[5] memory topUsers, uint256[5] memory scores) {
    Challenge storage challenge = challenges[challengeId];
    for (uint256 i = 0; i < 5; i++) {
      topUsers[i] = challenge.topUsers[i];
      scores[i] = challenge.scores[i];
    }
  }

  // Transfer ownership of the contract to a new account
  function transferOwnership(address newOwner) external override onlyOwner {
    require(newOwner != address(0), "NZ");
    emit OwnershipTransferred(owner, newOwner);
    owner = newOwner;
  }

  // Renounce ownership of the contract
  function renounceOwnership() external onlyOwner {
    emit OwnershipTransferred(owner, address(0));
    owner = address(0);
  }

  // Set Performance NFT contract address
  function setPerformanceNFTContract(address _nftContract) external override onlyOwner {
    require(_nftContract != address(0), "NZ");
    performanceNFTContract = _nftContract;
    emit PerformanceNFTContractSet(_nftContract);
  }

  // Claim rewards after challenge ends
  function getRewards(uint256 challengeId) external override nonReentrant {
    Challenge storage challenge = challenges[challengeId];
    // Validate challenge
    require(challenge.startTime > 0, "CNE");
    require(block.timestamp >= challenge.endTime, "NE");
    require(!rewardsDistributed[challengeId], "AD");

    // Mark as distributed first to prevent reentrancy
    rewardsDistributed[challengeId] = true;
    
    // Rewards distribution to top 5 participants
    uint256 undistributed = challenge.totalRewards;
    IERC20Minimal usdTokenContract = IERC20Minimal(usdToken);
    
    // Check USD token balance of the contract
    uint256 balance = usdTokenContract.balanceOf(address(this));
    require(balance >= undistributed, "NBR");
    
    // Calculate actual ranker count and initial rewards
    uint8 actualRankerCount = 0;
    address[5] memory validRankers;
    uint256[5] memory initialRewards;
    uint256 totalInitialRewardWeight = 0;
    
    for (uint8 i = 0; i < 5; i++) {
      address userAddress = challenge.topUsers[i];
      if (userAddress != address(0)) {
        validRankers[actualRankerCount] = userAddress;
        initialRewards[actualRankerCount] = rewardRatio[i];
        totalInitialRewardWeight = totalInitialRewardWeight + rewardRatio[i];
        actualRankerCount++;
      }
    }
    
    // Only distribute rewards if there are actual rankers
    if (actualRankerCount > 0) {
      // Distribute rewards in reverse order (rank 5 to rank 1)
      // This ensures rank 1 gets all remaining funds to avoid precision loss
      for (uint8 i = actualRankerCount; i > 0; i--) {
        uint8 idx = i - 1; // Convert to 0-indexed
        address userAddress = validRankers[idx];

        uint256 rewardAmount;

        // Give all remaining funds to the first ranker (rank 1) to avoid precision loss
        if (idx == 0) {
          rewardAmount = undistributed;
        } else {
          // Calculate reward based on original ratio
          require(totalInitialRewardWeight > 0, "IW");
          // Use direct calculation to avoid precision loss
          rewardAmount = (challenge.totalRewards * initialRewards[idx]) / totalInitialRewardWeight;

          // Cannot distribute more than the available balance
          if (rewardAmount > undistributed) {
            rewardAmount = undistributed;
          }
        }

        if (rewardAmount > 0) {
          // Update state before external call (Checks-Effects-Interactions pattern)
          undistributed = undistributed - rewardAmount;

          bool success = usdTokenContract.transfer(userAddress, rewardAmount);
          require(success, "RTF");

          emit Reward(challengeId, userAddress, rewardAmount);
        }
      }
    }
  }

  // Mint Performance NFT for top 5 users after getRewards execution
  function mintPerformanceNFT(uint256 challengeId) external override {
    require(performanceNFTContract != address(0), "NNC"); // NFT contract Not set
    Challenge storage challenge = challenges[challengeId];
    require(challenge.startTime > 0, "CNE"); // Challenge Not Exists
    require(block.timestamp >= challenge.endTime, "NE"); // Not Ended
    
    // Check if caller is in top 5
    uint8 userRank = 0;
    bool isTopRanker = false;
    
    for (uint8 i = 0; i < 5; i++) {
      if (challenge.topUsers[i] == msg.sender) {
        userRank = i + 1; // rank starts from 1
        isTopRanker = true;
        break;
      }
    }
    
    require(isTopRanker, "NT5"); // Not Top 5
    
    // Check if user can mint NFT (haven't claimed yet)
    require(IStelePerformanceNFT(performanceNFTContract).canMintNFT(challengeId, msg.sender), "AC");
    
    // Get user's final scores
    uint256 finalScore = challenge.scores[userRank - 1];
    
    // Call NFT contract to mint
    IStelePerformanceNFT(performanceNFTContract).mintPerformanceNFT(
      challengeId,
      msg.sender,
      challenge.totalUsers,
      finalScore,
      userRank,
      challenge.seedMoney, // initial value
      challenge.challengeType,
      challenge.startTime
    );
  }
}
