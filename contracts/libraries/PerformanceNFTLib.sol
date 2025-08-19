// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;
import './StringUtils.sol';

library PerformanceNFTLib {
  // NFT metadata structure for performance records (ChallengeType comes from main contract)
  struct PerformanceNFT {
    uint256 challengeId;
    address user;
    uint256 finalScore;
    uint8 rank; // 1-5
    uint256 returnRate; // in basis points (10000 = 100%)
    uint8 challengeType; // Use uint8 instead of enum to avoid import issues
    uint256 challengeEndTime;
  }
  
  // Events
  event TransferAttemptBlocked(uint256 indexed tokenId, address from, address to, string reason);

  // Calculate return rate based on final score and initial value
  function calculateReturnRate(uint256 finalScore, uint256 initialValue) internal pure returns (uint256) {
    if (finalScore > initialValue) {
      // Profit case: ((finalScore - initialValue) / initialValue) * 10000
      return ((finalScore - initialValue) * 10000) / initialValue;
    } else {
      // Loss case: return 0 for simplicity
      return 0;
    }
  }

  // Get soulbound info
  function getSoulboundInfo(address owner) internal pure returns (bool, address, string memory) {
    return (true, owner, "Performance NFT bound to achievement owner");
  }
}
