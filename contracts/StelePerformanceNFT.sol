// SPDX-License-Identifier: MIT
pragma solidity =0.7.6;
pragma abicoder v2;

import './libraries/SafeMath.sol';
import './libraries/StringUtils.sol';
import './interfaces/IStelePerformanceNFT.sol';

// NFT metadata structure for performance records
struct PerformanceNFT {
  uint256 challengeId;
  address user;
  uint32 totalUsers;
  uint256 finalScore;
  uint8 rank; // 1-5
  uint256 returnRate; // in basis points (10000 = 100%)
  ChallengeType challengeType;
  uint256 challengeStartTime;
  uint256 seedMoney; // Initial investment amount
}

contract StelePerformanceNFT is IStelePerformanceNFT {
  using SafeMath for uint256;

  // State variables
  address public override steleContract;
  address public override owner;
  string public override baseImageURI;
  
  // NFT storage
  uint256 private _nextTokenId = 1;
  mapping(uint256 => PerformanceNFT) public performanceNFTs;
  mapping(uint256 => address) public nftOwners;
  mapping(address => mapping(uint256 => uint256)) public userNFTsByIndex;
  mapping(address => uint256) public userNFTCount;
  mapping(uint256 => mapping(address => bool)) public override hasClaimedNFT; // challengeId => user => claimed
  uint256[] private _allTokens; // For enumerable functionality

  modifier onlyOwner() {
    require(msg.sender == owner, "NO");
    _;
  }

  modifier onlySteleContract() {
    require(msg.sender == steleContract, "NSC"); // Not Stele Contract
    _;
  }

  constructor(address _steleContract) {
    owner = msg.sender;
    steleContract = _steleContract;
    baseImageURI = "https://stele.io/nft/challenge/";
  }

  // Transfer ownership (only owner)
  function transferOwnership(address newOwner) external override onlyOwner {
    require(newOwner != address(0), "ZA"); // Zero Address
    address previousOwner = owner;
    owner = newOwner;
    emit OwnershipTransferred(previousOwner, newOwner);
  }

  // Set base image URI (only owner)
  function setBaseImageURI(string calldata _baseImageURI) external override onlyOwner {
    baseImageURI = _baseImageURI;
    emit BaseImageURIUpdated(_baseImageURI);
  }

  // Calculate return rate based on final score and initial value (basis points: 10000 = 100%)
  function calculateReturnRate(uint256 finalScore, uint256 initialValue) internal pure returns (uint256) {
    if (finalScore > initialValue) {
      return SafeMath.safeDiv(SafeMath.safeMul(SafeMath.safeSub(finalScore, initialValue), 10000), initialValue);
    } else {
      return 0;
    }
  }
  
  // Calculate profit/loss percentage with 3 decimal places (1000000 = 100.000%)
  function calculateProfitLossPercentage(uint256 finalScore, uint256 seedMoney) internal pure returns (int256) {
    if (seedMoney == 0) return 0;
    
    if (finalScore >= seedMoney) {
      // Profit: ((finalScore - seedMoney) / seedMoney) * 1000000
      uint256 profit = SafeMath.safeSub(finalScore, seedMoney);
      uint256 profitPercentage = SafeMath.safeDiv(SafeMath.safeMul(profit, 1000000), seedMoney);
      return int256(profitPercentage);
    } else {
      // Loss: -((seedMoney - finalScore) / seedMoney) * 1000000
      uint256 loss = SafeMath.safeSub(seedMoney, finalScore);
      uint256 lossPercentage = SafeMath.safeDiv(SafeMath.safeMul(loss, 1000000), seedMoney);
      return -int256(lossPercentage);
    }
  }

  // Mint Performance NFT (only callable by Stele contract)
  function mintPerformanceNFT(
    uint256 challengeId,
    address user,
    uint32 totalUsers,
    uint256 finalScore,
    uint8 rank,
    uint256 initialValue,
    ChallengeType challengeType,
    uint256 challengeStartTime
  ) external override onlySteleContract returns (uint256) {
    require(!hasClaimedNFT[challengeId][user], "AC"); // Already Claimed
    
    // Calculate return rate (basis points for backward compatibility)
    uint256 returnRate = calculateReturnRate(finalScore, initialValue);
    
    // Get next token ID
    uint256 tokenId = _nextTokenId;
    _nextTokenId++;
    
    // Store NFT metadata (initialValue is seedMoney from challenge)
    performanceNFTs[tokenId] = PerformanceNFT({
      challengeId: challengeId,
      user: user,
      totalUsers: totalUsers,
      finalScore: finalScore,
      rank: rank,
      returnRate: returnRate,
      challengeType: challengeType,
      challengeStartTime: challengeStartTime,
      seedMoney: initialValue
    });
    
    // Mark as claimed
    hasClaimedNFT[challengeId][user] = true;
    
    // Assign NFT to user
    nftOwners[tokenId] = user;
    userNFTsByIndex[user][userNFTCount[user]] = tokenId;
    userNFTCount[user]++;
    _allTokens.push(tokenId);
    
    // Emit ERC-721 Transfer event for external dapp detection (minting: from = address(0))
    emit Transfer(address(0), user, tokenId);
    
    emit PerformanceNFTMinted(tokenId, challengeId, user, rank, returnRate);
    
    return tokenId;
  }

  // Get NFT metadata
  function getPerformanceNFTData(uint256 tokenId) external view override returns (
    uint256 challengeId,
    address user,
    uint32 totalUsers,
    uint256 finalScore,
    uint8 rank,
    uint256 returnRate,
    ChallengeType challengeType,
    uint256 challengeStartTime,
    uint256 seedMoney
  ) {
    require(nftOwners[tokenId] != address(0), "TNE"); // Token Not Exists
    
    PerformanceNFT memory nft = performanceNFTs[tokenId];
    return (
      nft.challengeId,
      nft.user,
      nft.totalUsers,
      nft.finalScore,
      nft.rank,
      nft.returnRate,
      nft.challengeType,
      nft.challengeStartTime,
      nft.seedMoney
    );
  }

  // Check if user can mint NFT for a challenge
  function canMintNFT(uint256 challengeId, address user) external view override returns (bool) {
    return !hasClaimedNFT[challengeId][user];
  }

  // Get challenge period text
  function getChallengePeriodText(ChallengeType challengeType) internal pure returns (string memory) {
    if (challengeType == ChallengeType.OneWeek) return "1 week";
    if (challengeType == ChallengeType.OneMonth) return "1 month";
    if (challengeType == ChallengeType.ThreeMonths) return "3 months";
    if (challengeType == ChallengeType.SixMonths) return "6 months";
    if (challengeType == ChallengeType.OneYear) return "1 year";
    return "unknown period";
  }

  // Get return rate text
  function getReturnRateText(int256 profitLossPercent) internal pure returns (string memory) {
    if (profitLossPercent >= 0) {
      return string(abi.encodePacked("+", StringUtils.uint2str(uint256(profitLossPercent) / 10000), ".", StringUtils.uint2str((uint256(profitLossPercent) % 10000) / 100), "%"));
    } else {
      return string(abi.encodePacked("-", StringUtils.uint2str(uint256(-profitLossPercent) / 10000), ".", StringUtils.uint2str((uint256(-profitLossPercent) % 10000) / 100), "%"));
    }
  }

  // Get image name based on rank
  function getImageName(uint8 rank) internal pure returns (string memory) {
    if (rank == 1) return "1st.png";
    if (rank == 2) return "2nd.png";
    if (rank == 3) return "3rd.png";
    if (rank == 4) return "4th.png";
    if (rank == 5) return "5th.png";
    return "participant.png";
  }

  // Get token metadata URI with investment period, return rate, and ranking information
  function tokenURI(uint256 tokenId) public view override returns (string memory) {
    require(nftOwners[tokenId] != address(0), "TNE");
    
    PerformanceNFT memory nft = performanceNFTs[tokenId];
    int256 profitLossPercent = calculateProfitLossPercentage(nft.finalScore, nft.seedMoney);
    
    string memory periodText = getChallengePeriodText(nft.challengeType);
    string memory returnRateText = getReturnRateText(profitLossPercent);
    string memory imageUrl = string(abi.encodePacked(baseImageURI, getImageName(nft.rank)));
    string memory rankText = StringUtils.uint2str(nft.rank);
    string memory totalUsersText = StringUtils.uint2str(nft.totalUsers);

    // Build JSON in two parts to avoid stack too deep error
    string memory part1 = string(abi.encodePacked(
      '{"name":"Stele Performance NFT #', StringUtils.uint2str(tokenId),
      '","description":"Invested for ', periodText, 
      ' starting from ', StringUtils.timestampToDate(nft.challengeStartTime), 
      ' and achieved ', rankText, 
      ' place out of ', totalUsersText,
      ' participants with ', returnRateText, 
      ' return rate.","image":"', imageUrl, '"'
    ));

    string memory part2 = string(abi.encodePacked(
      ',"attributes":[{"trait_type":"Challenge Period","value":"', periodText,
      '"},{"trait_type":"Rank","value":', rankText,
      '},{"trait_type":"Return Rate","value":"', returnRateText,
      '"},{"trait_type":"Total Participants","value":', totalUsersText,
      '}]}'
    ));

    return string(abi.encodePacked(part1, part2));
  }

  // ============ SOULBOUND NFT FUNCTIONS ============
  
  // Transfer functions are blocked for soulbound functionality
  function transferFrom(address from, address to, uint256 tokenId) external override {
    emit TransferAttemptBlocked(tokenId, from, to, "Soulbound NFT cannot be transferred");
    revert("SBT");
  }
  
  function safeTransferFrom(address from, address to, uint256 tokenId) external override {
    emit TransferAttemptBlocked(tokenId, from, to, "Soulbound NFT cannot be transferred");
    revert("SBT");
  }
  
  function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata /* data */) external override {
    emit TransferAttemptBlocked(tokenId, from, to, "Soulbound NFT cannot be transferred");
    revert("SBT");
  }
  
  // Approval functions are blocked since transfers are not allowed
  function approve(address /* to */, uint256 /* tokenId */) external pure override {
    revert("SBT");
  }
  
  function setApprovalForAll(address /* operator */, bool /* approved */) external pure override {
    revert("SBT");
  }
  
  function getApproved(uint256 tokenId) external view override returns (address) {
    require(nftOwners[tokenId] != address(0), "TNE");
    return address(0); // Always return zero address for soulbound tokens
  }
  
  function isApprovedForAll(address /* tokenOwner */, address /* operator */) external pure override returns (bool) {
    return false; // Always return false for soulbound tokens
  }
  
  // Check if this is a soulbound token
  function isSoulbound() external pure override returns (bool) {
    return true;
  }
  
  // Get soulbound token information
  function getSoulboundInfo(uint256 tokenId) external view override returns (
    bool isSoulboundToken,
    address boundTo,
    string memory reason
  ) {
    require(nftOwners[tokenId] != address(0), "TNE");
    return (true, nftOwners[tokenId], "Performance NFT bound to achievement owner");
  }

  // Verify if NFT was minted by this contract with challenge validation
  function verifyNFTAuthenticity(uint256 tokenId) external view override returns (
    bool isAuthentic,
    uint256 challengeId,
    address originalMinter,
    uint8 rank,
    uint256 blockTimestamp
  ) {
    if (nftOwners[tokenId] == address(0)) {
      return (false, 0, address(0), 0, 0);
    }
    
    PerformanceNFT memory nft = performanceNFTs[tokenId];
    return (
      true,
      nft.challengeId,
      nft.user,
      nft.rank,
      nft.challengeStartTime
    );
  }

  // Get contract name and version for verification
  function getContractInfo() external pure override returns (string memory contractName, string memory version) {
    return ("Stele Performance NFT", "1.0.0");
  }

  // IERC721Metadata compatibility functions for external wallet/marketplace support
  function name() external pure override returns (string memory) {
    return "Stele Performance NFT";
  }

  function symbol() external pure override returns (string memory) {
    return "SPNFT";
  }

  // IERC721Enumerable compatibility functions for marketplace/explorer support
  function tokenOfOwnerByIndex(address tokenOwner, uint256 index) external view override returns (uint256) {
    require(index < userNFTCount[tokenOwner], "OOB"); // Out of bounds
    return userNFTsByIndex[tokenOwner][index];
  }

  function tokenByIndex(uint256 index) external view override returns (uint256) {
    require(index < _allTokens.length, "OOB"); // Out of bounds
    return _allTokens[index];
  }

  // Get NFT owner
  function ownerOf(uint256 tokenId) external view override returns (address) {
    require(nftOwners[tokenId] != address(0), "TNE");
    return nftOwners[tokenId];
  }

  // Get NFT balance of owner (ERC-721 standard)
  function balanceOf(address tokenOwner) external view override returns (uint256) {
    require(tokenOwner != address(0), "ZA"); // Zero Address
    return userNFTCount[tokenOwner];
  }

  // Get user's NFT tokens with pagination
  function getUserNFTs(address user, uint256 offset, uint256 limit) external view override returns (uint256[] memory tokens, uint256 total) {
    total = userNFTCount[user];
    
    if (offset >= total) {
      return (new uint256[](0), total);
    }
    
    uint256 end = offset + limit;
    if (end > total) {
      end = total;
    }
    
    uint256 length = end - offset;
    tokens = new uint256[](length);
    
    for (uint256 i = 0; i < length; i++) {
      tokens[i] = userNFTsByIndex[user][offset + i];
    }
    
    return (tokens, total);
  }
  
  // Get all user's NFT tokens (for backward compatibility, gas limit aware)
  function getAllUserNFTs(address user) external view override returns (uint256[] memory) {
    uint256 total = userNFTCount[user];
    uint256[] memory tokens = new uint256[](total);
    
    for (uint256 i = 0; i < total; i++) {
      tokens[i] = userNFTsByIndex[user][i];
    }
    
    return tokens;
  }

  // Get total NFT supply
  function totalSupply() external view override returns (uint256) {
    return _nextTokenId - 1;
  }

  // Check if token exists
  function exists(uint256 tokenId) external view override returns (bool) {
    return nftOwners[tokenId] != address(0);
  }

  // ERC165 support - indicates which interfaces this contract implements
  function supportsInterface(bytes4 interfaceId) public pure override returns (bool) {
    return
      interfaceId == 0x01ffc9a7 || // ERC165 Interface ID
      interfaceId == 0x80ac58cd || // ERC721 Interface ID
      interfaceId == 0x5b5e139f || // ERC721Metadata Interface ID
      interfaceId == 0x780e9d63;   // ERC721Enumerable Interface ID
  }
}
