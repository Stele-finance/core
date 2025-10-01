// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// Direct Uniswap V3 interfaces without library imports
interface IUniswapV3Factory {
    function getPool(address tokenA, address tokenB, uint24 fee) 
        external view returns (address pool);
}

interface IUniswapV3Pool {
    function observe(uint32[] calldata secondsAgos)
        external
        view
        returns (
            int56[] memory tickCumulatives, 
            uint160[] memory secondsPerLiquidityCumulativeX128s
        );
    
    function slot0() external view returns (
        uint160 sqrtPriceX96,
        int24 tick,
        uint16 observationIndex,
        uint16 observationCardinality,
        uint16 observationCardinalityNext,
        uint8 feeProtocol,
        bool unlocked
    );
}

library PriceOracle {
    
    // Get USD price from ETH (1 ETH = ? USD)
    function getETHPriceUSD(address uniswapV3Factory, address weth9, address usdToken) 
        internal view returns (uint256) {
        uint16[3] memory fees = [500, 3000, 10000];
        uint256 quoteAmount = 0;

        for (uint256 i=0; i<fees.length; i++) {
            address pool = IUniswapV3Factory(uniswapV3Factory).getPool(weth9, usdToken, uint24(fees[i]));
            if (pool == address(0)) {
                continue;
            }

            uint256 _quoteAmount = getQuoteFromPool(pool, uint128(1 * 10**18), weth9, usdToken);
            if (_quoteAmount > 0 && quoteAmount < _quoteAmount) {
                quoteAmount = _quoteAmount;
            }
        }

        return quoteAmount > 0 ? quoteAmount : 3000 * 1e6; // Fallback to $3000 if no pool available
    }

    // Get token price in ETH
    function getTokenPriceETH(address uniswapV3Factory, address baseToken, address weth9, uint256 baseAmount) 
        internal view returns (uint256) { 
        if (baseToken == weth9) {
            return baseAmount; // 1:1 ratio for WETH to ETH
        }

        uint16[3] memory fees = [500, 3000, 10000];
        uint256 quoteAmount = 0;

        for (uint256 i=0; i<fees.length; i++) {
            address pool = IUniswapV3Factory(uniswapV3Factory).getPool(baseToken, weth9, uint24(fees[i]));
            if (pool == address(0)) {
                continue;
            }

            uint256 _quoteAmount = getQuoteFromPool(pool, uint128(baseAmount), baseToken, weth9);
            if (_quoteAmount > 0 && quoteAmount < _quoteAmount) {
                quoteAmount = _quoteAmount;
            }
        }

        return quoteAmount;
    }

    // TWAP calculation using direct interface calls
    function getTWAPTick(address pool, uint32 secondsAgo) internal view returns (int24 timeWeightedAverageTick) {
        if (secondsAgo == 0) {
            (, timeWeightedAverageTick, , , , , ) = IUniswapV3Pool(pool).slot0();
            return timeWeightedAverageTick;
        }

        uint32[] memory secondsAgos = new uint32[](2);
        secondsAgos[0] = secondsAgo;
        secondsAgos[1] = 0;

        (int56[] memory tickCumulatives, ) = IUniswapV3Pool(pool).observe(secondsAgos);
        
        int56 tickCumulativesDelta = tickCumulatives[1] - tickCumulatives[0];
        timeWeightedAverageTick = int24(tickCumulativesDelta / int56(uint56(secondsAgo)));

        // Always round to negative infinity
        if (tickCumulativesDelta < 0 && (tickCumulativesDelta % int56(uint56(secondsAgo)) != 0)) {
            timeWeightedAverageTick--;
        }
    }

    // Convert tick to price ratio
    function getQuoteAtTick(int24 tick, uint128 baseAmount, address baseToken, address quoteToken) 
        internal pure returns (uint256 quoteAmount) {
        uint160 sqrtRatioX96 = getSqrtRatioAtTick(tick);
        
        // Calculate the price ratio from sqrtRatioX96
        if (sqrtRatioX96 <= type(uint128).max) {
            uint256 ratioX192 = uint256(sqrtRatioX96) * sqrtRatioX96;
            quoteAmount = baseToken < quoteToken
                ? mulDiv(ratioX192, baseAmount, 1 << 192)
                : mulDiv(1 << 192, baseAmount, ratioX192);
        } else {
            uint256 ratioX128 = mulDiv(sqrtRatioX96, sqrtRatioX96, 1 << 64);
            quoteAmount = baseToken < quoteToken
                ? mulDiv(ratioX128, baseAmount, 1 << 128)
                : mulDiv(1 << 128, baseAmount, ratioX128);
        }
    }

    // Get sqrt ratio at tick (simplified version)
    function getSqrtRatioAtTick(int24 tick) internal pure returns (uint160 sqrtPriceX96) {
        uint256 absTick = tick < 0 ? uint256(-int256(tick)) : uint256(int256(tick));
        require(absTick <= uint256(int256(887272)), 'T');

        uint256 ratio = absTick & 0x1 != 0 ? 0xfffcb933bd6fad37aa2d162d1a594001 : 0x100000000000000000000000000000000;
        if (absTick & 0x2 != 0) ratio = (ratio * 0xfff97272373d413259a46990580e213a) >> 128;
        if (absTick & 0x4 != 0) ratio = (ratio * 0xfff2e50f5f656932ef12357cf3c7fdcc) >> 128;
        if (absTick & 0x8 != 0) ratio = (ratio * 0xffe5caca7e10e4e61c3624eaa0941cd0) >> 128;
        if (absTick & 0x10 != 0) ratio = (ratio * 0xffcb9843d60f6159c9db58835c926644) >> 128;
        if (absTick & 0x20 != 0) ratio = (ratio * 0xff973b41fa98c081472e6896dfb254c0) >> 128;
        if (absTick & 0x40 != 0) ratio = (ratio * 0xff2ea16466c96a3843ec78b326b52861) >> 128;
        if (absTick & 0x80 != 0) ratio = (ratio * 0xfe5dee046a99a2a811c461f1969c3053) >> 128;
        if (absTick & 0x100 != 0) ratio = (ratio * 0xfcbe86c7900a88aedcffc83b479aa3a4) >> 128;
        if (absTick & 0x200 != 0) ratio = (ratio * 0xf987a7253ac413176f2b074cf7815e54) >> 128;
        if (absTick & 0x400 != 0) ratio = (ratio * 0xf3392b0822b70005940c7a398e4b70f3) >> 128;
        if (absTick & 0x800 != 0) ratio = (ratio * 0xe7159475a2c29b7443b29c7fa6e889d9) >> 128;
        if (absTick & 0x1000 != 0) ratio = (ratio * 0xd097f3bdfd2022b8845ad8f792aa5825) >> 128;
        if (absTick & 0x2000 != 0) ratio = (ratio * 0xa9f746462d870fdf8a65dc1f90e061e5) >> 128;
        if (absTick & 0x4000 != 0) ratio = (ratio * 0x70d869a156d2a1b890bb3df62baf32f7) >> 128;
        if (absTick & 0x8000 != 0) ratio = (ratio * 0x31be135f97d08fd981231505542fcfa6) >> 128;
        if (absTick & 0x10000 != 0) ratio = (ratio * 0x9aa508b5b7a84e1c677de54f3e99bc9) >> 128;
        if (absTick & 0x20000 != 0) ratio = (ratio * 0x5d6af8dedb81196699c329225ee604) >> 128;
        if (absTick & 0x40000 != 0) ratio = (ratio * 0x2216e584f5fa1ea926041bedfe98) >> 128;
        if (absTick & 0x80000 != 0) ratio = (ratio * 0x48a170391f7dc42444e8fa2) >> 128;

        if (tick > 0) ratio = type(uint256).max / ratio;

        sqrtPriceX96 = uint160((ratio >> 32) + (ratio % (1 << 32) == 0 ? 0 : 1));
    }

    // Full precision multiplication
    function mulDiv(uint256 a, uint256 b, uint256 denominator) internal pure returns (uint256 result) {
        uint256 prod0;
        uint256 prod1;
        assembly {
            let mm := mulmod(a, b, not(0))
            prod0 := mul(a, b)
            prod1 := sub(sub(mm, prod0), lt(mm, prod0))
        }

        if (prod1 == 0) {
            require(denominator > 0);
            assembly {
                result := div(prod0, denominator)
            }
            return result;
        }

        require(denominator > prod1);

        uint256 remainder;
        assembly {
            remainder := mulmod(a, b, denominator)
        }
        assembly {
            prod1 := sub(prod1, gt(remainder, prod0))
            prod0 := sub(prod0, remainder)
        }

        uint256 twos = (~denominator + 1) & denominator;
        assembly {
            denominator := div(denominator, twos)
        }

        assembly {
            prod0 := div(prod0, twos)
        }
        assembly {
            twos := add(div(sub(0, twos), twos), 1)
        }
        prod0 |= prod1 * twos;

        uint256 inv = (3 * denominator) ^ 2;
        inv *= 2 - denominator * inv;
        inv *= 2 - denominator * inv;
        inv *= 2 - denominator * inv;
        inv *= 2 - denominator * inv;
        inv *= 2 - denominator * inv;
        inv *= 2 - denominator * inv;

        result = prod0 * inv;
        return result;
    }

    // Function to get quote from pool (may revert)
    function getQuoteFromPool(address pool, uint128 baseAmount, address baseToken, address quoteToken)
        internal view returns (uint256) {
        uint32 secondsAgo = 300; // 5 minutes TWAP
        int24 tick = getTWAPTick(pool, secondsAgo);
        return getQuoteAtTick(tick, baseAmount, baseToken, quoteToken);
    }

    // Precision multiplication helper function
    function precisionMul(uint256 x, uint256 y, uint256 precision) internal pure returns (uint256) {
        return (x * y) / precision;
    }
}