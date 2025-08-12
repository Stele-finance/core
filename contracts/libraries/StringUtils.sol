// SPDX-License-Identifier: MIT
pragma solidity =0.7.6;

library StringUtils {
  
  // Helper function to convert uint to string
  function uint2str(uint256 _i) internal pure returns (string memory) {
    if (_i == 0) {
      return "0";
    }
    uint256 j = _i;
    uint256 len;
    while (j != 0) {
      len++;
      j /= 10;
    }
    bytes memory bstr = new bytes(len);
    uint256 k = len;
    while (_i != 0) {
      k = k - 1;
      uint8 temp = (48 + uint8(_i - _i / 10 * 10));
      bytes1 b1 = bytes1(temp);
      bstr[k] = b1;
      _i /= 10;
    }
    return string(bstr);
  }

  // Convert signed integer to string (supports negative numbers)
  function int2str(int256 _i) internal pure returns (string memory) {
    if (_i == 0) {
      return "0";
    }
    
    bool negative = _i < 0;
    uint256 absValue = negative ? uint256(-_i) : uint256(_i);
    
    uint256 j = absValue;
    uint256 len;
    while (j != 0) {
      len++;
      j /= 10;
    }
    
    // Add 1 for negative sign if needed
    if (negative) len++;
    
    bytes memory bstr = new bytes(len);
    uint256 k = len;
    
    while (absValue != 0) {
      k = k - 1;
      uint8 temp = (48 + uint8(absValue - absValue / 10 * 10));
      bytes1 b1 = bytes1(temp);
      bstr[k] = b1;
      absValue /= 10;
    }
    
    if (negative) {
      bstr[0] = "-";
    }
    
    return string(bstr);
  }

  // Convert Unix timestamp to YYYY/MM/DD format
  function timestampToDate(uint256 timestamp) internal pure returns (string memory) {
    // Calculate days since Unix epoch (Jan 1, 1970)
    uint256 daysSinceEpoch = timestamp / 86400; // 86400 seconds in a day
    
    // Calculate year (simplified calculation, good enough for dates after 2000)
    uint256 year = 1970;
    uint256 daysInYear = 365;
    
    while (daysSinceEpoch >= daysInYear) {
      // Check for leap year
      if ((year % 4 == 0 && year % 100 != 0) || (year % 400 == 0)) {
        daysInYear = 366;
      } else {
        daysInYear = 365;
      }
      
      if (daysSinceEpoch >= daysInYear) {
        daysSinceEpoch -= daysInYear;
        year++;
      } else {
        break;
      }
    }
    
    // Days in each month (non-leap year)
    uint256[12] memory daysInMonth = [uint256(31), 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    
    // Adjust February for leap year
    if ((year % 4 == 0 && year % 100 != 0) || (year % 400 == 0)) {
      daysInMonth[1] = 29;
    }
    
    // Calculate month and day
    uint256 month = 1;
    for (uint256 i = 0; i < 12; i++) {
      if (daysSinceEpoch >= daysInMonth[i]) {
        daysSinceEpoch -= daysInMonth[i];
        month++;
      } else {
        break;
      }
    }
    
    uint256 day = daysSinceEpoch + 1; // Days are 1-indexed
    
    // Format as YYYY/MM/DD
    return string(abi.encodePacked(
      uint2str(year), "/",
      month < 10 ? "0" : "", uint2str(month), "/",
      day < 10 ? "0" : "", uint2str(day)
    ));
  }
}
