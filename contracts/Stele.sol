// SPDX-License-Identifier: MIT
pragma solidity =0.7.6;
pragma abicoder v2;

import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol';
import '@uniswap/v3-periphery/contracts/libraries/OracleLibrary.sol';
import './interfaces/IERC20Minimal.sol';

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
  uint256 entryFee;
  uint8 maxAssets;
  address[5] topUsers; // top 5 users
  uint256[5] score; // score of top 5 users
  mapping(address => UserPortfolio) portfolios;
  mapping(address => bool) isRegistered;
}

contract Stele {

  // Base Mainnet
  address public uniswapV3Factory = 0x1F98431c8aD98523631AE4a59f267346ea31F984;

  // State variables
  address public owner;
  address public usdToken;
  address public wethToken;
  uint8 public usdTokenDecimals;
  uint8 public maxAssets;
  uint256 public seedMoney;
  uint256 public entryFee;
  uint256[5] public rewardRatio;
  mapping(address => bool) public isInvestable;

  // Stele Token Bonus System
  address public steleToken;
  uint256 public createChallengeBonus;
  uint256 public getRewardsBonus;

  // Challenge repository
  mapping(uint256 => Challenge) public challenges;
  uint256 public challengeCounter;
  // Latest challenge ID by challenge type
  mapping(ChallengeType => uint256) public latestChallengesByType;


  // Event definitions
  event SteleCreated(address owner,address usdToken, uint8 maxAssets, uint256 seedMoney, uint256 entryFee, uint256[5] rewardRatio);
  event RewardRatio(uint256[5] newRewardRatio);
  event EntryFee(uint256 newEntryFee);
  event MaxAssets(uint8 newMaxAssets);
  event SeedMoney(uint256 newSeedMoney);
  event AddToken(address tokenAddress);
  event RemoveToken(address tokenAddress);
  event Create(uint256 challengeId, ChallengeType challengeType, uint256 seedMoney, uint256 entryFee, uint8 maxAssets);
  event Join(uint256 challengeId, address user, uint256 seedMoney);
  event Swap(uint256 challengeId, address user, address fromAsset, address toAsset, uint256 fromAmount, uint256 toAmount);
  event Register(uint256 challengeId, address user, uint256 performance);
  event Reward(uint256 challengeId, address user, uint256 rewardAmount);
  event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
  event SteleTokenBonus(uint256 challengeId, address indexed user, string action, uint256 amount);

  modifier onlyOwner() {
      require(msg.sender == owner, 'NO');
      _;
  }
  
  // Contract constructor
  constructor(address _wethToken, address _usdToken, address _steleToken) {
    owner = msg.sender;
    usdToken = _usdToken;
    wethToken = _wethToken;
    usdTokenDecimals = IERC20Minimal(_usdToken).decimals(); 
    maxAssets = 10;
    seedMoney = 1000 * 10**usdTokenDecimals;
    entryFee = 1 * 10**usdTokenDecimals; // 1 USD for initial testing period, default : 10 USD
    rewardRatio = [50, 26, 13, 7, 4];
    challengeCounter = 0;
    // Initialize Stele Token Bonus
    steleToken = _steleToken;
    createChallengeBonus = 1000 * 10**18; // 10000 STL tokens
    getRewardsBonus = 100000 * 10**18;     // 100000 STL tokens

    // Initialize investable tokens directly
    isInvestable[wethToken] = true;
    emit AddToken(wethToken);
    isInvestable[usdToken] = true;
    emit AddToken(usdToken);

    emit SteleCreated(owner, usdToken, maxAssets, seedMoney, entryFee, rewardRatio);
  }

  // Transfer ownership of the contract to a new account
  function transferOwnership(address newOwner) external onlyOwner {
    require(newOwner != address(0), "NZ");
    emit OwnershipTransferred(owner, newOwner);
    owner = newOwner;
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

  // Reward distribution ratio setting function
  function setRewardRatio(uint256[5] calldata _rewardRatio) external onlyOwner {
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
    require(tokenAddress != address(0), "ZA"); // Zero Address
    require(!isInvestable[tokenAddress], "AT"); // Already Token
    
    isInvestable[tokenAddress] = true;
    emit AddToken(tokenAddress);
  }
  
  // Non-investable token setting function
  function resetToken(address tokenAddress) external onlyOwner {
    require(tokenAddress != address(0), "ZA"); // Zero Address
    require(isInvestable[tokenAddress], "NT"); // Not investableToken
    require(tokenAddress != usdToken, "UCR"); // USD token Cannot be Removed
    require(tokenAddress != wethToken, "WCR"); // WETH Cannot be Removed

    isInvestable[tokenAddress] = false;
    emit RemoveToken(tokenAddress);
  }

  // Max assets setting function
  function setMaxAssets(uint8 _maxAssets) external onlyOwner {
    maxAssets = _maxAssets;
    emit MaxAssets(_maxAssets);
  }

  // Get user's portfolio in a specific challenge
  function getUserPortfolio(uint256 challengeId, address user) external view returns (address[] memory tokenAddresses, uint256[] memory amounts) {
    Challenge storage challenge = challenges[challengeId];
    require(challenge.startTime > 0, "CNE");
    
    UserPortfolio memory portfolio = challenge.portfolios[user];
    uint256 assetCount = portfolio.assets.length;
    
    tokenAddresses = new address[](assetCount);
    amounts = new uint256[](assetCount);
    
    for (uint256 i = 0; i < assetCount; i++) {
      tokenAddresses[i] = portfolio.assets[i].tokenAddress;
      amounts[i] = portfolio.assets[i].amount;
    }
    
    return (tokenAddresses, amounts);
  }

  // Get USD price from ETH (1 ETH = ? USD)
  function getETHPriceUSD() internal view returns (uint256) {
    uint16[3] memory fees = [500, 3000, 10000];
    uint256 quoteAmount = 0;

    for (uint256 i=0; i<fees.length; i++) {
      address pool = IUniswapV3Factory(uniswapV3Factory).getPool(wethToken, usdToken, uint24(fees[i]));
      if (pool == address(0)) {
          continue;
      }

      uint32 secondsAgo = OracleLibrary.getOldestObservationSecondsAgo(pool);
      uint32 maxSecondsAgo = 1800;
      secondsAgo = secondsAgo > maxSecondsAgo ? maxSecondsAgo : secondsAgo;

      (int24 tick, ) = OracleLibrary.consult(address(pool), secondsAgo);
      uint256 _quoteAmount = OracleLibrary.getQuoteAtTick(tick, uint128(1 * 10**18), wethToken, usdToken);
      
      if (quoteAmount < _quoteAmount) {
        quoteAmount = _quoteAmount;
      }
    }

    return quoteAmount;
  }

  // Get token price in ETH
  function getTokenPriceETH(address baseToken, uint128 baseAmount) internal view returns (uint256) { 
    address quoteToken = wethToken;
    uint16[3] memory fees = [500, 3000, 10000];
    uint256 quoteAmount = 0;

    for (uint256 i=0; i<fees.length; i++) {
      address pool = IUniswapV3Factory(uniswapV3Factory).getPool(baseToken, quoteToken, uint24(fees[i]));
      if (pool == address(0)) {
          continue;
      }

      uint32 secondsAgo = OracleLibrary.getOldestObservationSecondsAgo(pool);
      uint32 maxSecondsAgo = 1800;
      secondsAgo = secondsAgo > maxSecondsAgo ? maxSecondsAgo : secondsAgo;

      (int24 tick, ) = OracleLibrary.consult(address(pool), secondsAgo);
      uint256 _quoteAmount = OracleLibrary.getQuoteAtTick(tick, baseAmount, baseToken, quoteToken);
      
      if (quoteAmount < _quoteAmount) {
        quoteAmount = _quoteAmount;
      }
    }

    return quoteAmount;
  }

  // Create a new challenge
  function createChallenge(ChallengeType challengeType) external {
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
    challenge.maxAssets = maxAssets;
    
    // Initialize top users and their values
    for (uint i = 0; i < 5; i++) {
      challenge.topUsers[i] = address(0);
      challenge.score[i] = 0;
    }
    
    emit Create(challengeId, challengeType, challenge.seedMoney, challenge.entryFee, challenge.maxAssets);
    
    // Distribute Stele token bonus for creating challenge
    distributeSteleBonus(challengeId, msg.sender, createChallengeBonus, "CR");
  }

  // Join an existing challenge
  function joinChallenge(uint256 challengeId) external {
    Challenge storage challenge = challenges[challengeId];
    
    // Check if challenge exists and is still active
    require(challenge.startTime > 0, "CNE");
    require(block.timestamp < challenge.endTime, "E");
    require(!challenge.isRegistered[msg.sender], "C");
    
    // Check if user has already joined
    require(challenge.portfolios[msg.sender].assets.length == 0, "AJ");
    
    // Transfer USD token to contract
    IERC20Minimal usdTokenContract = IERC20Minimal(usdToken);
    
    // First check if user has enough tokens
    require(usdTokenContract.balanceOf(msg.sender) >= entryFee, "NEB");
    
    // Check if user has approved the contract to transfer tokens
    require(usdTokenContract.allowance(msg.sender, address(this)) >= entryFee, "NA");
    
    // Transfer tokens
    bool transferSuccess = usdTokenContract.transferFrom(msg.sender, address(this), entryFee);
    require(transferSuccess, "TF");
    
    // Add user to challenge
    UserPortfolio storage portfolio = challenge.portfolios[msg.sender];
    
    // Initialize with seed money in USD
    Asset memory initialAsset = Asset({
      tokenAddress: usdToken,
      amount: challenge.seedMoney
    });
    
    portfolio.assets.push(initialAsset);
    
    // Update challenge total rewards
    challenge.totalRewards = safeAdd(challenge.totalRewards, entryFee);
    
    emit Join(challengeId, msg.sender, challenge.seedMoney);  
  }

  // Swap assets within a challenge portfolio
  function swap(uint256 challengeId, address from, address to, uint256 amount) external {
    Challenge storage challenge = challenges[challengeId];
    
    // Validate challenge and user
    require(challenge.startTime > 0, "CNE");
    require(block.timestamp < challenge.endTime, "E");
    require(!challenge.isRegistered[msg.sender], "C");
    
    // Validate assets
    require(from != to, "ST"); // Prevent same token swap
    require(isInvestable[to], "IT"); // Not investableToken
    
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

    // Get asset prices using ETH as intermediate
    uint8 fromTokenDecimals = IERC20Minimal(from).decimals();
    uint8 toTokenDecimals = IERC20Minimal(to).decimals();

    uint256 fromPriceUSD;
    uint256 toPriceUSD;
        
    // Calculate fromPriceUSD using ETH as intermediate
    if (from == usdToken) {
      fromPriceUSD = 1 * 10 ** usdTokenDecimals;
    } else if (from == wethToken) {
      fromPriceUSD = getETHPriceUSD();
    } else {
      fromPriceUSD = safeDiv(safeMul(getTokenPriceETH(from, uint128(1 * 10 ** fromTokenDecimals)), getETHPriceUSD()), 10 ** 18);
    }
    
    // Calculate toPriceUSD using ETH as intermediate
    if (to == usdToken) {
      toPriceUSD = 1 * 10 ** usdTokenDecimals;
    } else if (to == wethToken) {
      toPriceUSD = getETHPriceUSD();
    } else {
      toPriceUSD = safeDiv(safeMul(getTokenPriceETH(to, uint128(1 * 10 ** toTokenDecimals)), getETHPriceUSD()), 10 ** 18);
    }
        
    // Validate that prices are available
    require(fromPriceUSD > 0, "FP0");
    require(toPriceUSD > 0, "TP0");

    // Calculate swap amount with decimal adjustment
    uint256 toAmount = safeDiv(safeMul(amount, fromPriceUSD), toPriceUSD);

    // Adjust for decimal differences
    if (toTokenDecimals > fromTokenDecimals) {
      toAmount = safeMul(toAmount, 10 ** (toTokenDecimals - fromTokenDecimals));
    } else if (fromTokenDecimals > toTokenDecimals) {
      toAmount = safeDiv(toAmount, 10 ** (fromTokenDecimals - toTokenDecimals));
    }
    
    // Ensure swap amount is not zero
    require(toAmount > 0, "TA0");
    
    // Update source asset
    portfolio.assets[index].amount = safeSub(portfolio.assets[index].amount, amount);
    
    // Add or update target asset
    bool foundTarget = false;

    for (uint256 i = 0; i < portfolio.assets.length; i++) {
      if (portfolio.assets[i].tokenAddress == to) {
        portfolio.assets[i].amount = safeAdd(portfolio.assets[i].amount, toAmount);
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
      // Only reorganize array if not already the last element
      if (index != portfolio.assets.length - 1) {
        portfolio.assets[index] = portfolio.assets[portfolio.assets.length - 1];
      }
      portfolio.assets.pop();
    }

    emit Swap(challengeId, msg.sender, from, to, amount, toAmount);
  }

  // Register final performance and close position
  function register(uint256 challengeId) external {
    Challenge storage challenge = challenges[challengeId];
    
    // Validate challenge and user
    require(challenge.startTime > 0, "CNE");
    require(block.timestamp < challenge.endTime, "E");
    require(!challenge.isRegistered[msg.sender], "C");
    
    // Calculate total portfolio value USD using ETH as intermediate
    uint256 userScore = 0;
    uint256 ethPriceUSD = getETHPriceUSD(); // Get ETH price once for efficiency
    
    UserPortfolio memory portfolio = challenge.portfolios[msg.sender];
    for (uint256 i = 0; i < portfolio.assets.length; i++) {
      address tokenAddress = portfolio.assets[i].tokenAddress;
      uint8 _tokenDecimals = IERC20Minimal(tokenAddress).decimals();

      if(!isInvestable[tokenAddress]) continue;

      uint256 assetPriceUSD;
      if (tokenAddress == usdToken) {
        assetPriceUSD = 1 * 10 ** usdTokenDecimals;
      } else if (tokenAddress == wethToken) {
        assetPriceUSD = ethPriceUSD;
      } else {
        uint256 assetPriceETH = getTokenPriceETH(tokenAddress, uint128(1 * 10 ** _tokenDecimals));
        assetPriceUSD = safeDiv(safeMul(assetPriceETH, ethPriceUSD), 10 ** 18);
      }
      
      uint256 assetValueUSD = safeDiv(safeMul(portfolio.assets[i].amount, assetPriceUSD), 10 ** _tokenDecimals);
      userScore = safeAdd(userScore, assetValueUSD);
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
        challenge.score[i] = challenge.score[i + 1];
      }
      
      // Clear last position
      challenge.topUsers[4] = address(0);
      challenge.score[4] = 0;
    }
    
    // Find insertion position using binary search concept (for sorted array)
    uint256 insertPos = 5; // Default: not in top 5
    
    for (uint256 i = 0; i < 5; i++) {
      if (challenge.topUsers[i] == address(0) || userScore > challenge.score[i]) {
        insertPos = i;
        break;
      }
    }
    
    // Insert if position found
    if (insertPos < 5) {
      // Shift elements to make space
      for (uint256 i = 4; i > insertPos; i--) {
        challenge.topUsers[i] = challenge.topUsers[i - 1];
        challenge.score[i] = challenge.score[i - 1];
      }
      
      // Insert new entry
      challenge.topUsers[insertPos] = user;
      challenge.score[insertPos] = userScore;
    }
  }
  
  function getRanking(uint256 challengeId) external view returns (address[5] memory topUsers, uint256[5] memory scores) {
    Challenge storage challenge = challenges[challengeId];
    for (uint256 i = 0; i < 5; i++) {
      topUsers[i] = challenge.topUsers[i];
      scores[i] = challenge.score[i];
    }
  }

  // Rewards distribution tracking
  mapping(uint256 => bool) public rewardsDistributed;

  // Claim rewards after challenge ends
  function getRewards(uint256 challengeId) external {
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
        totalInitialRewardWeight = safeAdd(totalInitialRewardWeight, rewardRatio[i]);
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
        uint256 rewardAmount = safeDiv(safeMul(challenge.totalRewards, initialRewards[i]), totalInitialRewardWeight);
        
        // Cannot distribute more than the available balance
        if (rewardAmount > undistributed) {
          rewardAmount = undistributed;
        }
        
        if (rewardAmount > 0) {
          // Update state before external call (Checks-Effects-Interactions pattern)
          undistributed = safeSub(undistributed, rewardAmount);
          
          bool success = usdTokenContract.transfer(userAddress, rewardAmount);
          require(success, "RTF");

          emit Reward(challengeId, userAddress, rewardAmount);
          
          // Distribute Stele token bonus to each ranker
          distributeSteleBonus(challengeId, userAddress, getRewardsBonus, "RW");
        }
      }
    }
  }

  function safeAdd(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a + b;
    require(c >= a, "OFA");
    return c;
  }

  function safeSub(uint256 a, uint256 b) internal pure returns (uint256) {
    require(b <= a, "UF");
    return a - b;
  }

  function safeMul(uint256 a, uint256 b) internal pure returns (uint256) {
    if (a == 0) {
      return 0;
    }
    uint256 c = a * b;
    require(c / a == b, "OFM");
    return c;
  }

  function safeDiv(uint256 a, uint256 b) internal pure returns (uint256) {
    require(b > 0, "DZ");
    return a / b;
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
}