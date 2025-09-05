// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

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

// Challenge type definition
enum ChallengeType { OneWeek, OneMonth, ThreeMonths, SixMonths, OneYear }

contract StelePerformanceNFT is ERC721, ERC721Enumerable, Ownable {
  using Strings for uint256;

  // Events
  event PerformanceNFTMinted(uint256 indexed tokenId, uint256 indexed challengeId, address indexed user, uint8 rank, uint256 returnRate);
  event TransferAttemptBlocked(uint256 indexed tokenId, address from, address to, string reason);
  event BaseImageURIUpdated(string newBaseImageURI);

  // State variables
  address public steleContract;
  string public baseImageURI;
  
  // NFT storage
  uint256 private _nextTokenId = 1;
  mapping(uint256 => PerformanceNFT) public performanceNFTs;
  mapping(address => mapping(uint256 => uint256)) public userNFTsByIndex;
  mapping(address => uint256) public userNFTCount;
  mapping(uint256 => mapping(address => bool)) public hasClaimedNFT; // challengeId => user => claimed


  modifier onlySteleContract() {
    require(msg.sender == steleContract, "NSC"); // Not Stele Contract
    _;
  }

  constructor(address _steleContract) ERC721("Stele Performance NFT", "SPNFT") {
    steleContract = _steleContract;
    baseImageURI = "https://stele.io/nft/challenge/";
  }

  // Transfer ownership (only owner) - Override Ownable
  function transferOwnership(address newOwner) public override onlyOwner {
    require(newOwner != address(0), "ZA"); // Zero Address
    super.transferOwnership(newOwner);
  }

  // Set base image URI (only owner)
  function setBaseImageURI(string calldata _baseImageURI) external onlyOwner {
    baseImageURI = _baseImageURI;
    emit BaseImageURIUpdated(_baseImageURI);
  }

  // Calculate return rate based on final score and initial value (basis points: 10000 = 100%)
  function calculateReturnRate(uint256 finalScore, uint256 initialValue) internal pure returns (uint256) {
    if (finalScore > initialValue) {
      return ((finalScore - initialValue) * 10000) / initialValue;
    } else {
      return 0;
    }
  }
  
  // Calculate profit/loss percentage with 3 decimal places (1000000 = 100.000%)
  function calculateProfitLossPercentage(uint256 finalScore, uint256 seedMoney) internal pure returns (int256) {
    if (seedMoney == 0) return 0;
    
    if (finalScore >= seedMoney) {
      // Profit: ((finalScore - seedMoney) / seedMoney) * 1000000
      uint256 profit = finalScore - seedMoney;
      uint256 profitPercentage = (profit * 1000000) / seedMoney;
      return int256(profitPercentage);
    } else {
      // Loss: -((seedMoney - finalScore) / seedMoney) * 1000000
      uint256 loss = seedMoney - finalScore;
      uint256 lossPercentage = (loss * 1000000) / seedMoney;
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
  ) external onlySteleContract returns (uint256) {
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
    
    // Mint NFT using OpenZeppelin's _mint function
    _mint(user, tokenId);
    
    // Update custom mappings for user enumeration
    userNFTsByIndex[user][userNFTCount[user]] = tokenId;
    userNFTCount[user]++;
    
    emit PerformanceNFTMinted(tokenId, challengeId, user, rank, returnRate);
    
    return tokenId;
  }

  // Get NFT metadata
  function getPerformanceNFTData(uint256 tokenId) external view returns (
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
    require(_ownerOf(tokenId) != address(0), "TNE"); // Token Not Exists
    
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
  function canMintNFT(uint256 challengeId, address user) external view returns (bool) {
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
      return string(abi.encodePacked("+", Strings.toString(uint256(profitLossPercent) / 10000), ".", Strings.toString((uint256(profitLossPercent) % 10000) / 100), "%"));
    } else {
      return string(abi.encodePacked("-", Strings.toString(uint256(-profitLossPercent) / 10000), ".", Strings.toString((uint256(-profitLossPercent) % 10000) / 100), "%"));
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
    require(_ownerOf(tokenId) != address(0), "TNE");
    
    PerformanceNFT memory nft = performanceNFTs[tokenId];
    int256 profitLossPercent = calculateProfitLossPercentage(nft.finalScore, nft.seedMoney);
    
    string memory periodText = getChallengePeriodText(nft.challengeType);
    string memory returnRateText = getReturnRateText(profitLossPercent);
    string memory imageUrl = string(abi.encodePacked(baseImageURI, getImageName(nft.rank)));
    string memory rankText = Strings.toString(nft.rank);
    string memory totalUsersText = Strings.toString(nft.totalUsers);

    // Build JSON in two parts to avoid stack too deep error
    string memory part1 = string(abi.encodePacked(
      '{"name":"Stele Performance NFT #', Strings.toString(tokenId),
      '","description":"Invested for ', periodText, 
      ' starting from ', Strings.toString(nft.challengeStartTime), 
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
  function transferFrom(address from, address to, uint256 tokenId) public override(ERC721, IERC721) {
    emit TransferAttemptBlocked(tokenId, from, to, "Soulbound NFT cannot be transferred");
    revert("SBT");
  }
  
  function safeTransferFrom(address from, address to, uint256 tokenId) public override(ERC721, IERC721) {
    emit TransferAttemptBlocked(tokenId, from, to, "Soulbound NFT cannot be transferred");
    revert("SBT");
  }
  
  function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory /* data */) public override(ERC721, IERC721) {
    emit TransferAttemptBlocked(tokenId, from, to, "Soulbound NFT cannot be transferred");
    revert("SBT");
  }
  
  // Approval functions are blocked since transfers are not allowed
  function approve(address /* to */, uint256 /* tokenId */) public pure override(ERC721, IERC721) {
    revert("SBT");
  }
  
  function setApprovalForAll(address /* operator */, bool /* approved */) public pure override(ERC721, IERC721) {
    revert("SBT");
  }
  
  function getApproved(uint256 tokenId) public view override(ERC721, IERC721) returns (address) {
    require(_ownerOf(tokenId) != address(0), "TNE");
    return address(0); // Always return zero address for soulbound tokens
  }
  
  function isApprovedForAll(address /* tokenOwner */, address /* operator */) public pure override(ERC721, IERC721) returns (bool) {
    return false; // Always return false for soulbound tokens
  }
  
  // Check if this is a soulbound token
  function isSoulbound() external pure returns (bool) {
    return true;
  }
  
  // Get soulbound token information
  function getSoulboundInfo(uint256 tokenId) external view returns (
    bool isSoulboundToken,
    address boundTo,
    string memory reason
  ) {
    require(_ownerOf(tokenId) != address(0), "TNE");
    return (true, ownerOf(tokenId), "Performance NFT bound to achievement owner");
  }

  // Verify if NFT was minted by this contract with challenge validation
  function verifyNFTAuthenticity(uint256 tokenId) external view returns (
    bool isAuthentic,
    uint256 challengeId,
    address originalMinter,
    uint8 rank,
    uint256 blockTimestamp
  ) {
    if (_ownerOf(tokenId) == address(0)) {
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
  function getContractInfo() external pure returns (string memory contractName, string memory version) {
    return ("Stele Performance NFT", "1.0.0");
  }

  // Override required functions for ERC721Enumerable compatibility
  function _beforeTokenTransfer(address from, address to, uint256 tokenId, uint256 batchSize)
    internal
    override(ERC721, ERC721Enumerable)
  {
    super._beforeTokenTransfer(from, to, tokenId, batchSize);
  }

  function supportsInterface(bytes4 interfaceId)
    public
    view
    override(ERC721, ERC721Enumerable)
    returns (bool)
  {
    return super.supportsInterface(interfaceId);
  }

  // Custom enumeration functions (using ERC721Enumerable for standard functions)
  function tokenOfOwnerByIndex(address tokenOwner, uint256 index) public view override returns (uint256) {
    require(index < userNFTCount[tokenOwner], "OOB"); // Out of bounds
    return userNFTsByIndex[tokenOwner][index];
  }

  // ERC721 functions are inherited from OpenZeppelin

  // Get user's NFT tokens with pagination
  function getUserNFTs(address user, uint256 offset, uint256 limit) external view returns (uint256[] memory tokens, uint256 total) {
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
  function getAllUserNFTs(address user) external view returns (uint256[] memory) {
    uint256 total = userNFTCount[user];
    uint256[] memory tokens = new uint256[](total);
    
    for (uint256 i = 0; i < total; i++) {
      tokens[i] = userNFTsByIndex[user][i];
    }
    
    return tokens;
  }

  // totalSupply is provided by ERC721Enumerable

  // Check if token exists
  function exists(uint256 tokenId) external view returns (bool) {
    return _ownerOf(tokenId) != address(0);
  }

  // supportsInterface is handled by the override above
}
