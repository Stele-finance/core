// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Base64.sol";

library NFTSVG {
    using Strings for uint256;
    using Strings for address;

    struct SVGParams {
        uint256 challengeId;
        address user;
        uint32 totalUsers;
        uint256 finalScore;
        uint8 rank;
        uint256 returnRate;
        uint256 challengeType;
        uint256 challengeStartTime;
        uint256 seedMoney;
        int256 profitLossPercent;
    }

    function generateSVG(SVGParams memory params) internal pure returns (string memory) {
        return string(abi.encodePacked(
            '<svg width="300" height="400" viewBox="0 0 300 400" xmlns="http://www.w3.org/2000/svg">',
            generateDefs(),
            generateCard(),
            generateTitle(),
            generateRankBadge(params.rank),
            generateStatsGrid(params),
            generateSeparator(),
            generateInvestmentSummary(params),
            generateFooter(),
            '</svg>'
        ));
    }

    function generateDefs() internal pure returns (string memory) {
        return string(abi.encodePacked(
            '<defs>',
                '<linearGradient id="orangeGradient" x1="0%" y1="0%" x2="100%" y2="100%">',
                    '<stop offset="0%" style="stop-color:#ff8c42;stop-opacity:1" />',
                    '<stop offset="100%" style="stop-color:#e55100;stop-opacity:1" />',
                '</linearGradient>',
                '<linearGradient id="cardBackground" x1="0%" y1="0%" x2="0%" y2="100%">',
                    '<stop offset="0%" style="stop-color:#2a2a2e;stop-opacity:1" />',
                    '<stop offset="100%" style="stop-color:#1f1f23;stop-opacity:1" />',
                '</linearGradient>',
                '<filter id="cardShadow">',
                    '<feDropShadow dx="0" dy="2" stdDeviation="8" flood-color="#000" flood-opacity="0.06"/>',
                '</filter>',
            '</defs>'
        ));
    }

    function generateCard() internal pure returns (string memory) {
        return string(abi.encodePacked(
            '<rect width="300" height="400" rx="12" fill="url(#cardBackground)" stroke="#404040" stroke-width="1" filter="url(#cardShadow)"/>',
            '<rect x="0" y="0" width="300" height="4" rx="12" fill="url(#orangeGradient)"/>'
        ));
    }


    function generateTitle() internal pure returns (string memory) {
        return string(abi.encodePacked(
            '<text x="24" y="40" font-family="-apple-system, BlinkMacSystemFont, Segoe UI, sans-serif" font-size="20" font-weight="600" fill="#f9fafb">',
                'Trading Performance',
            '</text>',
            '<text x="24" y="60" font-family="-apple-system, BlinkMacSystemFont, Segoe UI, sans-serif" font-size="14" fill="#9ca3af">',
                'Stele Protocol',
            '</text>'
        ));
    }

    function generateRankBadge(uint8 rank) internal pure returns (string memory) {
        return string(abi.encodePacked(
            '<rect x="24" y="85" width="80" height="32" rx="16" fill="url(#orangeGradient)"/>',
            '<text x="64" y="103" font-family="-apple-system, BlinkMacSystemFont, Segoe UI, sans-serif" font-size="14" font-weight="600" fill="#ffffff" text-anchor="middle">',
                'Rank ', uint256(rank).toString(),
            '</text>'
        ));
    }

    function generateStatsGrid(SVGParams memory params) internal pure returns (string memory) {
        string memory challengeText = getChallengePeriodText(params.challengeType);
        string memory returnText = formatReturnRate(params.profitLossPercent);
        
        return string(abi.encodePacked(
            '<g font-family="-apple-system, BlinkMacSystemFont, Segoe UI, sans-serif">',
                '<text x="24" y="140" font-size="14" font-weight="500" fill="#9ca3af">Challenge</text>',
                '<text x="276" y="140" font-size="14" font-weight="600" fill="#f9fafb" text-anchor="end">#', params.challengeId.toString(), '</text>',
                '<text x="24" y="165" font-size="14" font-weight="500" fill="#9ca3af">Duration</text>',
                '<text x="276" y="165" font-size="14" font-weight="600" fill="#f9fafb" text-anchor="end">', challengeText, '</text>',
                '<text x="24" y="190" font-size="14" font-weight="500" fill="#9ca3af">Ranking</text>',
                '<text x="276" y="190" font-size="14" font-weight="600" fill="url(#orangeGradient)" text-anchor="end">', uint256(params.rank).toString(), getRankSuffix(params.rank), ' / ', uint256(params.totalUsers).toString(), '</text>',
                '<text x="24" y="215" font-size="14" font-weight="500" fill="#9ca3af">Return Rate</text>',
                '<text x="276" y="215" font-size="16" font-weight="700" fill="#10b981" text-anchor="end">', returnText, '</text>',
            '</g>'
        ));
    }

    function generateSeparator() internal pure returns (string memory) {
        return '<line x1="24" y1="245" x2="276" y2="245" stroke="#404040" stroke-width="1"/>';
    }

    function generateInvestmentSummary(SVGParams memory params) internal pure returns (string memory) {
        if (params.finalScore >= params.seedMoney) {
            return string(abi.encodePacked(
                '<g font-family="-apple-system, BlinkMacSystemFont, Segoe UI, sans-serif">',
                    '<text x="24" y="270" font-size="14" font-weight="500" fill="#9ca3af">Initial Investment</text>',
                    '<text x="276" y="270" font-size="14" font-weight="600" fill="#f9fafb" text-anchor="end">$', formatAmount(params.seedMoney), '</text>',
                    '<text x="24" y="295" font-size="14" font-weight="500" fill="#9ca3af">Current Value</text>',
                    '<text x="276" y="295" font-size="14" font-weight="600" fill="#f9fafb" text-anchor="end">$', formatAmount(params.finalScore), '</text>',
                    '<text x="24" y="320" font-size="14" font-weight="500" fill="#9ca3af">Profit/Loss</text>',
                    '<text x="276" y="320" font-size="14" font-weight="600" fill="#10b981" text-anchor="end">+$', formatAmount(params.finalScore - params.seedMoney), '</text>',
                '</g>'
            ));
        } else {
            return string(abi.encodePacked(
                '<g font-family="-apple-system, BlinkMacSystemFont, Segoe UI, sans-serif">',
                    '<text x="24" y="270" font-size="14" font-weight="500" fill="#9ca3af">Initial Investment</text>',
                    '<text x="276" y="270" font-size="14" font-weight="600" fill="#f9fafb" text-anchor="end">$', formatAmount(params.seedMoney), '</text>',
                    '<text x="24" y="295" font-size="14" font-weight="500" fill="#9ca3af">Current Value</text>',
                    '<text x="276" y="295" font-size="14" font-weight="600" fill="#f9fafb" text-anchor="end">$', formatAmount(params.finalScore), '</text>',
                    '<text x="24" y="320" font-size="14" font-weight="500" fill="#9ca3af">Profit/Loss</text>',
                    '<text x="276" y="320" font-size="14" font-weight="600" fill="#ef4444" text-anchor="end">-$', formatAmount(params.seedMoney - params.finalScore), '</text>',
                '</g>'
            ));
        }
    }


    function generateFooter() internal pure returns (string memory) {
        return '<text x="150" y="365" font-family="-apple-system, BlinkMacSystemFont, Segoe UI, sans-serif" font-size="12" font-weight="500" fill="#9ca3af" text-anchor="middle">Powered by Stele Protocol</text>';
    }

    function getChallengePeriodText(uint256 challengeType) internal pure returns (string memory) {
        if (challengeType == 0) return "1 Week";
        if (challengeType == 1) return "1 Month";
        if (challengeType == 2) return "3 Months";
        if (challengeType == 3) return "6 Months";
        if (challengeType == 4) return "1 Year";
        return "Unknown";
    }

    function formatReturnRate(int256 profitLossPercent) internal pure returns (string memory) {
        if (profitLossPercent >= 0) {
            uint256 absPercent = uint256(profitLossPercent);
            return string(abi.encodePacked(
                "+", 
                (absPercent / 10000).toString(), 
                ".", 
                formatDecimals((absPercent % 10000) / 100), 
                "%"
            ));
        } else {
            uint256 absPercent = uint256(-profitLossPercent);
            return string(abi.encodePacked(
                "-", 
                (absPercent / 10000).toString(), 
                ".", 
                formatDecimals((absPercent % 10000) / 100), 
                "%"
            ));
        }
    }

    function formatAmount(uint256 amount) internal pure returns (string memory) {
        // USDC has 6 decimals, so 1e6 = 1 USD
        if (amount >= 1e12) { // >= 1,000,000 USD (1M)
            return string(abi.encodePacked((amount / 1e12).toString(), "M"));
        } else if (amount >= 1e11) { // >= 100,000 USD (100K)  
            return string(abi.encodePacked((amount / 1e9).toString(), "K"));
        } else if (amount >= 1e6) { // >= 1 USD  
            return (amount / 1e6).toString();
        } else {
            // Less than 1 USD, show with decimals
            uint256 dollars = amount / 1e6;
            uint256 cents = (amount % 1e6) / 1e4; // 2 decimal places
            return string(abi.encodePacked(dollars.toString(), ".", formatDecimals(cents)));
        }
    }

    function formatDecimals(uint256 value) internal pure returns (string memory) {
        if (value < 10) {
            return string(abi.encodePacked("0", value.toString()));
        }
        return value.toString();
    }

    function getRankSuffix(uint8 rank) internal pure returns (string memory) {
        if (rank == 1) return "st";
        if (rank == 2) return "nd";
        if (rank == 3) return "rd";
        return "th";
    }

}