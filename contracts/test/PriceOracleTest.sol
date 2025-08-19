// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {PriceOracle, IUniswapV3Factory} from "../libraries/PriceOracle.sol";

contract PriceOracleTest {
    using PriceOracle for *;

    // Wrapper functions for testing the library
    function getETHPriceUSD(
        address uniswapV3Factory,
        address weth9,
        address usdToken
    ) external view returns (uint256) {
        return PriceOracle.getETHPriceUSD(uniswapV3Factory, weth9, usdToken);
    }

    function getTokenPriceETH(
        address uniswapV3Factory,
        address baseToken,
        address weth9,
        uint256 baseAmount
    ) external view returns (uint256) {
        return PriceOracle.getTokenPriceETH(uniswapV3Factory, baseToken, weth9, baseAmount);
    }

    function getQuoteFromPool(
        address pool,
        uint128 baseAmount,
        address baseToken,
        address quoteToken
    ) external view returns (uint256) {
        return PriceOracle.getQuoteFromPool(pool, baseAmount, baseToken, quoteToken);
    }

    function getTWAPTick(address pool, uint32 secondsAgo) external view returns (int24) {
        return PriceOracle.getTWAPTick(pool, secondsAgo);
    }

    function precisionMul(uint256 x, uint256 y, uint256 precision) external pure returns (uint256) {
        return PriceOracle.precisionMul(x, y, precision);
    }

    // Custom TWAP functions for testing different time windows
    function getETHPriceUSDWithCustomTWAP(
        address uniswapV3Factory,
        address weth9,
        address usdToken,
        uint32 secondsAgo
    ) external view returns (uint256) {
        uint16[3] memory fees = [500, 3000, 10000];
        uint256 quoteAmount = 0;

        for (uint256 i=0; i<fees.length; i++) {
            address pool = IUniswapV3Factory(uniswapV3Factory).getPool(weth9, usdToken, uint24(fees[i]));
            if (pool == address(0)) {
                continue;
            }

            uint256 _quoteAmount = getQuoteFromPoolWithCustomTWAP(pool, uint128(1 * 10**18), weth9, usdToken, secondsAgo);
            if (_quoteAmount > 0 && quoteAmount < _quoteAmount) {
                quoteAmount = _quoteAmount;
            }
        }

        return quoteAmount > 0 ? quoteAmount : 3000 * 1e6; // Fallback to $3000 if no pool available
    }

    function getQuoteFromPoolWithCustomTWAP(
        address pool,
        uint128 baseAmount,
        address baseToken,
        address quoteToken,
        uint32 secondsAgo
    ) public view returns (uint256) {
        int24 tick = PriceOracle.getTWAPTick(pool, secondsAgo);
        return PriceOracle.getQuoteAtTick(tick, baseAmount, baseToken, quoteToken);
    }
}