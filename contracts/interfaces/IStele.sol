// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.28;

interface IStele {
  // Enums
  enum ChallengeType { OneWeek, OneMonth, ThreeMonths, SixMonths, OneYear }
  
  // Events
  event SteleCreated(address owner, address usdToken, uint8 maxTokens, uint256 seedMoney, uint256 entryFee, uint256[5] rewardRatio);
  event AddToken(address tokenAddress);
  event Create(uint256 challengeId, ChallengeType challengeType, uint256 seedMoney, uint256 entryFee);
  event Join(uint256 challengeId, address user, uint256 seedMoney);
  event Swap(uint256 challengeId, address user, address tokenIn, address tokenOut, uint256 tokenInAmount, uint256 tokenOutAmount);
  event Register(uint256 challengeId, address user, uint256 performance);
  event Reward(uint256 challengeId, address user, uint256 rewardAmount);
  event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
  event PerformanceNFTContractSet(address indexed nftContract);

  // Read functions
  function owner() external view returns (address);
  function weth9() external view returns (address);
  function usdToken() external view returns (address);
  function wbtc() external view returns (address);
  function uni() external view returns (address);
  function link() external view returns (address);
  function usdTokenDecimals() external view returns (uint8);
  function maxTokens() external view returns (uint8);
  function seedMoney() external view returns (uint256);
  function entryFee() external view returns (uint256);
  function rewardRatio(uint256 index) external view returns (uint256);
  function isInvestable(address tokenAddress) external view returns (bool);
  function performanceNFTContract() external view returns (address);
  function rewardsDistributed(uint256 challengeId) external view returns (bool);
  function getChallengeInfo(uint256 challengeId) external view returns (
    uint256 _id,
    ChallengeType _challengeType,
    uint256 _startTime,
    uint256 _endTime,
    uint256 _totalRewards,
    uint256 _seedMoney,
    uint256 _entryFee,
    uint32 _totalUsers
  );
  function challengeCounter() external view returns (uint256);
  function latestChallengesByType(ChallengeType challengeType) external view returns (uint256);
  
  function setPerformanceNFTContract(address _nftContract) external;
  function transferOwnership(address newOwner) external;
  function renounceOwnership() external;

  // Challenge management functions
  function createChallenge(ChallengeType challengeType) external;
  function joinChallenge(uint256 challengeId) external;
  function swap(uint256 challengeId, address tokenIn, address tokenOut, uint256 tokenInAmount) external;
  function register(uint256 challengeId) external;
  function getRewards(uint256 challengeId) external;
  function mintPerformanceNFT(uint256 challengeId) external;

  function getRanking(uint256 challengeId) external view returns (address[5] memory topUsers, uint256[5] memory scores);
  function getUserPortfolio(uint256 challengeId, address user) external view returns (address[] memory tokenAddresses, uint256[] memory amounts);  
} 