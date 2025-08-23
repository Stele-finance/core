// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import './interfaces/IERC20Minimal.sol';
import './interfaces/IStele.sol';
import {PriceOracle, IUniswapV3Factory} from './libraries/PriceOracle.sol';

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
  mapping(address => bool) isRegistered;
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

contract Stele is IStele {
  using PriceOracle for *;
  
  address public constant swapRouter = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
  address public constant uniswapV3Factory = 0x1F98431c8aD98523631AE4a59f267346ea31F984;
  
  // State variables
  address public override owner;
  address public override usdToken;
  address public override weth9;
  uint256 public override seedMoney;
  uint256 public override entryFee;
  uint8 public override usdTokenDecimals;
  uint8 public override maxTokens;
  uint256[5] public override rewardRatio;
  mapping(address => bool) public override isInvestable;
  mapping(uint256 => bool) public override rewardsDistributed;

  // Stele Token Bonus System
  address public override steleToken;
  uint256 public override createBonus;
  uint256 public override joinBonus;
  uint256 public override getRewardsBonus;

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
  constructor(address _weth9, address _usdToken, address _steleToken) {
    owner = msg.sender;
    usdToken = _usdToken;
    weth9 = _weth9;
    usdTokenDecimals = IERC20Minimal(_usdToken).decimals(); 
    maxTokens = 10;
    seedMoney = 1000 * 10**usdTokenDecimals;
    entryFee = 10 * 10**usdTokenDecimals; // 10 USD
    rewardRatio = [50, 26, 13, 7, 4];
    challengeCounter = 0;
    // Initialize Stele Token Bonus
    steleToken = _steleToken;
    createBonus = 1000 * 10**18; // 1000 STL tokens
    joinBonus = 500 * 10**18; // 500 STL tokens
    getRewardsBonus = 50000 * 10**18; // 50000 STL tokens

    // Initialize investable tokens directly
    isInvestable[weth9] = true;
    emit AddToken(weth9);
    isInvestable[usdToken] = true;
    emit AddToken(usdToken);

    emit SteleCreated(owner, usdToken, maxTokens, seedMoney, entryFee, rewardRatio);
  }

  // Transfer ownership of the contract to a new account
  function transferOwnership(address newOwner) external override onlyOwner {
    require(newOwner != address(0), "NZ");
    emit OwnershipTransferred(owner, newOwner);
    owner = newOwner;
  }

  // Set Performance NFT contract address
  function setPerformanceNFTContract(address _nftContract) external override onlyOwner {
    require(_nftContract != address(0), "NZ");
    performanceNFTContract = _nftContract;
    emit PerformanceNFTContractSet(_nftContract);
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

  // Reward distribution ratio setting function
  function setRewardRatio(uint256[5] calldata _rewardRatio) external override onlyOwner {
    uint256 sum = 0;
    for (uint i = 0; i < 5; i++) {
        require(_rewardRatio[i] > 0, "IR");
        sum += _rewardRatio[i];
    }
    require(sum == 100, "IS");
    
    // Ensure reward ratio is in descending order (1st > 2nd > 3rd > 4th > 5th)
    for (uint i = 0; i < 4; i++) {
        require(_rewardRatio[i] > _rewardRatio[i + 1], "RD"); // Reward ratio must be Descending
    }
    
    rewardRatio = _rewardRatio;
    emit RewardRatio(_rewardRatio);
  }
  
  // Entry fee setting function
  function setEntryFee(uint256 _entryFee) external override onlyOwner {
    entryFee = _entryFee;
    emit EntryFee(_entryFee);
  }
  
  // Initial capital setting function
  function setSeedMoney(uint256 _seedMoney) external override onlyOwner {
    seedMoney = _seedMoney;
    emit SeedMoney(_seedMoney);
  }
  
  // Investable token setting function
  function setToken(address tokenAddress) external override onlyOwner {
    require(tokenAddress != address(0), "ZA"); // Zero Address
    require(!isInvestable[tokenAddress], "AT"); // Already Token
    
    isInvestable[tokenAddress] = true;
    emit AddToken(tokenAddress);
  }
  
  // Non-investable token setting function
  function resetToken(address tokenAddress) external override onlyOwner {
    require(tokenAddress != address(0), "ZA"); // Zero Address
    require(isInvestable[tokenAddress], "NT"); // Not investableToken
    require(tokenAddress != usdToken, "UCR"); // USD token Cannot be Removed
    require(tokenAddress != weth9, "WCR"); // WETH Cannot be Removed

    isInvestable[tokenAddress] = false;
    emit RemoveToken(tokenAddress);
  }

  // Max tokens setting function
  function setMaxTokens(uint8 _maxTokens) external override onlyOwner {
    maxTokens = _maxTokens;
    emit MaxTokens(_maxTokens);
  }

  // Create challenge bonus setting function
  function setCreateBonus(uint256 _createBonus) external onlyOwner {
    createBonus = _createBonus;
    emit CreateBonusUpdated(_createBonus);
  }

  // Join challenge bonus setting function
  function setJoinBonus(uint256 _joinBonus) external onlyOwner {
    joinBonus = _joinBonus;
    emit JoinBonusUpdated(_joinBonus);
  }

  // Get rewards bonus setting function
  function setGetRewardsBonus(uint256 _getRewardsBonus) external onlyOwner {
    getRewardsBonus = _getRewardsBonus;
    emit GetRewardsBonusUpdated(_getRewardsBonus);
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
    
    // Distribute Stele token bonus for creating challenge
    distributeSteleBonus(challengeId, msg.sender, createBonus, "CR");
  }

  // Join an existing challenge
  function joinChallenge(uint256 challengeId) external override {
    Challenge storage challenge = challenges[challengeId];
    
    // Check if challenge exists and is still active
    require(challenge.startTime > 0, "CNE");
    require(block.timestamp < challenge.endTime, "E");
    require(!challenge.isRegistered[msg.sender], "C");
    
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

    // Distribute Stele token bonus for joining challenge
    distributeSteleBonus(challengeId, msg.sender, joinBonus, "JCR");
  }

  // Swap tokens within a challenge portfolio
  function swap(uint256 challengeId, address tokenIn, address tokenOut, uint256 amount) external override {
    Challenge storage challenge = challenges[challengeId];
    
    // Validate challenge and user
    require(challenge.startTime > 0, "CNE");
    require(block.timestamp < challenge.endTime, "E");
    require(!challenge.isRegistered[msg.sender], "C");
    
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

    // Calculate swap amount with decimal adjustment
    uint256 toAmount = (amount * tokenInPriceUSD) / tokenOutPriceUSD;

    // Adjust for decimal differences
    if (tokenOutDecimals > tokenInDecimals) {
      toAmount = toAmount * 10 ** (tokenOutDecimals - tokenInDecimals);
    } else if (tokenInDecimals > tokenOutDecimals) {
      toAmount = toAmount / 10 ** (tokenInDecimals - tokenOutDecimals);
    }
    
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
  }

  // Register final performance and close position
  function register(uint256 challengeId) external override {
    Challenge storage challenge = challenges[challengeId];
    
    // Validate challenge and user
    require(challenge.startTime > 0, "CNE");
    require(block.timestamp < challenge.endTime, "E");
    require(!challenge.isRegistered[msg.sender], "C");
    
    // Calculate total portfolio value USD using ETH as intermediate
    uint256 userScore = 0;
    uint256 ethPriceUSD = PriceOracle.getETHPriceUSD(uniswapV3Factory, weth9, usdToken); // Get ETH price once for efficiency
    
    UserPortfolio memory portfolio = challenge.portfolios[msg.sender];
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
    
    // Mark position as closed
    challenge.isRegistered[msg.sender] = true;
    
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

  // Claim rewards after challenge ends
  function getRewards(uint256 challengeId) external override {
    Challenge storage challenge = challenges[challengeId];
    // Validate challenge
    require(challenge.startTime > 0, "CNE");
    require(block.timestamp >= challenge.endTime, "NE");
    require(!rewardsDistributed[challengeId], "AD");
    
    // Check if caller is in top 5 rankers
    bool isTopRanker = false;
    for (uint8 i = 0; i < 5; i++) {
      if (challenge.topUsers[i] == msg.sender) {
        isTopRanker = true;
        break;
      }
    }
    require(isTopRanker, "NT5");

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
      // Distribute rewards to each ranker
      for (uint8 i = 0; i < actualRankerCount; i++) {
        address userAddress = validRankers[i];
        
        // Calculate reward based on original ratio
        require(totalInitialRewardWeight > 0, "IW");
        // Use direct calculation to avoid precision loss
        uint256 rewardAmount = (challenge.totalRewards * initialRewards[i]) / totalInitialRewardWeight;
        
        // Cannot distribute more than the available balance
        if (rewardAmount > undistributed) {
          rewardAmount = undistributed;
        }
        
        if (rewardAmount > 0) {
          // Update state before external call (Checks-Effects-Interactions pattern)
          undistributed = undistributed - rewardAmount;
          
          bool success = usdTokenContract.transfer(userAddress, rewardAmount);
          require(success, "RTF");

          emit Reward(challengeId, userAddress, rewardAmount);
          
          // Distribute Stele token bonus to each ranker
          distributeSteleBonus(challengeId, userAddress, getRewardsBonus, "RW");
        }
      }
    }
  }

  // Internal function to distribute Stele token bonus
  function distributeSteleBonus(uint256 challengeId, address recipient, uint256 amount, string memory action) internal {    
    IERC20Minimal steleTokenContract = IERC20Minimal(steleToken);
    uint256 contractBalance = steleTokenContract.balanceOf(address(this));
    
    if (contractBalance >= amount) {
      bool success = steleTokenContract.transfer(recipient, amount);
      if (success) {
        emit SteleTokenBonus(challengeId, recipient, action, amount);
      }
    }
    // Silently fail if insufficient balance - no revert to avoid breaking main functionality
  }

  // Mint Performance NFT for top 5 users after getRewards execution
  function mintPerformanceNFT(uint256 challengeId) external override {
    require(performanceNFTContract != address(0), "NNC"); // NFT contract Not set
    
    Challenge storage challenge = challenges[challengeId];
    
    // Validate challenge exists and has ended
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
