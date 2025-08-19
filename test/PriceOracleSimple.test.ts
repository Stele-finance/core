import { expect } from "chai";
import { ethers } from "hardhat";
import { PriceOracleTest } from "../typechain-types";

describe("PriceOracle Simple Tests", function () {
  let priceOracle: PriceOracleTest;
  
  // Mainnet addresses
  const UNISWAP_V3_FACTORY = "0x1F98431c8aD98523631AE4a59f267346ea31F984";
  const WETH = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";
  const USDC = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48";
  const WBTC = "0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599";

  this.timeout(60000); // 60 second timeout

  before(async function () {
    console.log("Deploying PriceOracleTest contract...");
    const PriceOracleTestFactory = await ethers.getContractFactory("PriceOracleTest");
    priceOracle = await PriceOracleTestFactory.deploy();
    await priceOracle.waitForDeployment();
    console.log("PriceOracleTest deployed at:", await priceOracle.getAddress());
  });

  it("Should get ETH price in USDC", async function () {
    console.log("Testing ETH price in USDC...");
    
    const ethPriceUSD = await priceOracle.getETHPriceUSD(
      UNISWAP_V3_FACTORY,
      WETH,
      USDC
    );

    const formattedPrice = ethers.formatUnits(ethPriceUSD, 6);
    console.log(`1 ETH = ${formattedPrice} USDC`);
    
    // ETH price should be between $1000 and $10000 (reasonable range)
    expect(ethPriceUSD).to.be.greaterThan(ethers.parseUnits("1000", 6));
    expect(ethPriceUSD).to.be.lessThan(ethers.parseUnits("10000", 6));
  });

  it("Should get WBTC price in ETH", async function () {
    console.log("Testing WBTC price in ETH...");
    
    const wbtcPriceETH = await priceOracle.getTokenPriceETH(
      UNISWAP_V3_FACTORY,
      WBTC,
      WETH,
      ethers.parseUnits("1", 8) // 1 WBTC (8 decimals)
    );

    const formattedPrice = ethers.formatUnits(wbtcPriceETH, 18);
    console.log(`1 WBTC = ${formattedPrice} ETH`);

    // WBTC should be worth more than 1 ETH typically
    expect(wbtcPriceETH).to.be.greaterThan(ethers.parseEther("1"));
    expect(wbtcPriceETH).to.be.lessThan(ethers.parseEther("50")); // reasonable upper bound
  });

  it("Should calculate WBTC price in USDC", async function () {
    console.log("Testing WBTC price in USDC via ETH...");
    
    // Get WBTC price in ETH
    const wbtcPriceETH = await priceOracle.getTokenPriceETH(
      UNISWAP_V3_FACTORY,
      WBTC,
      WETH,
      ethers.parseUnits("1", 8)
    );

    // Get ETH price in USDC
    const ethPriceUSD = await priceOracle.getETHPriceUSD(
      UNISWAP_V3_FACTORY,
      WETH,
      USDC
    );

    // Calculate WBTC price in USDC
    const wbtcPriceUSD = (wbtcPriceETH * ethPriceUSD) / BigInt(10 ** 18);

    const ethPrice = ethers.formatUnits(ethPriceUSD, 6);
    const wbtcEthPrice = ethers.formatUnits(wbtcPriceETH, 18);
    const wbtcUsdPrice = ethers.formatUnits(wbtcPriceUSD, 6);

    console.log(`ETH Price: ${ethPrice} USDC`);
    console.log(`WBTC Price: ${wbtcEthPrice} ETH`);
    console.log(`WBTC Price: ${wbtcUsdPrice} USDC`);

    // WBTC should be worth more than ETH in USD terms
    expect(wbtcPriceUSD).to.be.greaterThan(ethPriceUSD);
    
    // WBTC price should be reasonable (between $10k and $100k)
    expect(wbtcPriceUSD).to.be.greaterThan(ethers.parseUnits("10000", 6));
    expect(wbtcPriceUSD).to.be.lessThan(ethers.parseUnits("100000", 6));
  });

  it("Should handle WETH correctly (1:1 ratio)", async function () {
    console.log("Testing WETH 1:1 ratio...");
    
    const amount = ethers.parseEther("1");
    const wethPriceETH = await priceOracle.getTokenPriceETH(
      UNISWAP_V3_FACTORY,
      WETH,
      WETH,
      amount
    );

    console.log(`1 WETH = ${ethers.formatUnits(wethPriceETH, 18)} ETH`);

    // WETH should have 1:1 ratio with ETH
    expect(wethPriceETH).to.equal(amount);
  });
});