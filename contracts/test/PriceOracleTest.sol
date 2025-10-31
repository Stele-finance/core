// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.28;

import {PriceOracle, IUniswapV3Factory} from "../libraries/PriceOracle.sol";

contract PriceOracleTest {
    using PriceOracle for *;

    // Wrapper functions for testing the library with spot prices
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

    function precisionMul(uint256 x, uint256 y, uint256 precision) external pure returns (uint256) {
        return PriceOracle.precisionMul(x, y, precision);
    }

    function getBestQuote(
        address uniswapV3Factory,
        address tokenA,
        address tokenB,
        uint128 amountIn
    ) external view returns (uint256) {
        return PriceOracle.getBestQuote(uniswapV3Factory, tokenA, tokenB, amountIn);
    }

    function mulDiv(uint256 a, uint256 b, uint256 denominator) external pure returns (uint256) {
        return PriceOracle.mulDiv(a, b, denominator);
    }
}
