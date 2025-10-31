// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.28;

// Challenge type definition
enum ChallengeType { OneWeek, OneMonth, ThreeMonths, SixMonths, OneYear }

interface IStelePerformanceNFT {
  // Events
  event PerformanceNFTMinted(uint256 indexed tokenId, uint256 indexed challengeId, address indexed user, uint8 rank, uint256 returnRate);
  event TransferAttemptBlocked(uint256 indexed tokenId, address from, address to, string reason);
  event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
  event BaseImageURIUpdated(string newBaseImageURI);
  
  // ERC-721 Standard Events (for external dapp detection)
  event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
  event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
  event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

  // Core NFT functions
  function mintPerformanceNFT(
    uint256 challengeId,
    address user,
    uint32 totalUsers,
    uint256 finalScore,
    uint8 rank,
    uint256 initialValue,
    ChallengeType challengeType,
    uint256 challengeStartTime
  ) external returns (uint256);
  
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
  );
  
  function canMintNFT(uint256 challengeId, address user) external view returns (bool);
  
  // Contract management functions
  function steleContract() external view returns (address);
  
  // NFT ownership functions
  function ownerOf(uint256 tokenId) external view returns (address);
  function balanceOf(address tokenOwner) external view returns (uint256);
  function totalSupply() external view returns (uint256);
  function exists(uint256 tokenId) external view returns (bool);
  function tokenURI(uint256 tokenId) external view returns (string memory);

  function getUserNFTs(address user, uint256 offset, uint256 limit) external view returns (uint256[] memory tokens, uint256 total);
  function getAllUserNFTs(address user) external view returns (uint256[] memory tokens);
  
  // IERC721Metadata compatibility functions
  function name() external view returns (string memory);
  function symbol() external view returns (string memory);
  
  // IERC721Enumerable compatibility functions
  function tokenOfOwnerByIndex(address tokenOwner, uint256 index) external view returns (uint256);
  function tokenByIndex(uint256 index) external view returns (uint256);
  
  // Verification functions
  function verifyNFTAuthenticity(uint256 tokenId) external view returns (
    bool isAuthentic,
    uint256 challengeId,
    address originalMinter,
    uint8 rank,
    uint256 blockTimestamp
  );
  
  function getContractInfo() external pure returns (string memory contractName, string memory version);
  
  // Soulbound functions
  function isSoulbound() external pure returns (bool);
  function getSoulboundInfo(uint256 tokenId) external view returns (
    bool isSoulboundToken,
    address boundTo,
    string memory reason
  );
  
  // Transfer functions (will revert for soulbound tokens)
  function transferFrom(address from, address to, uint256 tokenId) external;
  function safeTransferFrom(address from, address to, uint256 tokenId) external;
  function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external;
  
  // Approval functions (will revert for soulbound tokens)
  function approve(address to, uint256 tokenId) external;
  function setApprovalForAll(address operator, bool approved) external;
  function getApproved(uint256 tokenId) external view returns (address);
  function isApprovedForAll(address tokenOwner, address operator) external pure returns (bool);
  
  // ERC165 interface detection
  function supportsInterface(bytes4 interfaceId) external pure returns (bool);
}
