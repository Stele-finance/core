import { expect } from "chai";
import { ethers } from "hardhat";

// Challenge type definition
enum ChallengeType { OneWeek, OneMonth, ThreeMonths, SixMonths, OneYear }

describe("Stele Contract", function () {
  let deployer: any;
  let user1: any;
  let user2: any;
  let stele: any;
  let usdc: any;
  let wbtc: any;
  let usdcDecimals: number;
  let wbtcDecimals: number;

  // Base Mainnet token addresses
  const USDC = process.env.USDC || "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48";
  const WETH = process.env.WETH || "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";
  const WBTC = process.env.WBTC || "0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599";

  const USDT = process.env.USDT || "0xdAC17F958D2ee523a2206206994597C13D831ec7";
  const LINK = process.env.LINK || "0x514910771AF9Ca656af840dff83E8264EcF986CA";
  const UNI = process.env.UNI || "0x1f9840a85d5af5bf1d1762f925bdaddc4201f984";
  const DAI = process.env.DAI || "0x6B175474E89094C44Da98b954EedeAC495271d0F";
  const SHIB = process.env.SHIB || "0x95aD61b0a150d79219dCF64E1E6Cc01f0B64C4cE";
  const SUSHI = process.env.SUSHI || "0x6B3595068778DD592e39A122f4f5a5cF09C90fE2";
  const AAVE = process.env.AAVE || "0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9";
  const CRV = process.env.CRV || "0xD533a949740bb3306d119CC777fa900bA034cd52";
  const ONDO = process.env.ONDO || "0xfAbA6f8e4a5E8Ab82F62fe7C39859FA577269BE3";

  // Using USDT as a placeholder for STELE_TOKEN since it's a valid ERC20 contract
  const STELE_TOKEN = process.env.STELE_TOKEN || "0xdAC17F958D2ee523a2206206994597C13D831ec7";

  before("Setup", async function () {
    try {
      const [owner, otherAccount, thirdAccount] = await ethers.getSigners();
      deployer = owner;
      user1 = otherAccount;
      user2 = thirdAccount;

      // Deploy Stele contract
      const Stele = await ethers.getContractFactory("Stele");
      stele = await Stele.deploy(USDC, STELE_TOKEN);
      await stele.waitForDeployment();

      // Get USDC contract instance
      usdc = await ethers.getContractAt("IERC20Minimal", USDC);
      wbtc = await ethers.getContractAt("IERC20Minimal", WBTC);
      usdcDecimals = await stele.usdTokenDecimals();
      wbtcDecimals = await wbtc.decimals();

      // Initial setup
      await stele.setToken(WBTC);
      await stele.setToken(WETH);
    } catch (error) {
      console.error("Setup error:", error);
      throw error;
    }

    // Increase USDC balance by impersonating a whale account
    const usdcWhaleAddress = "0x47ac0Fb4F2D84898e4D9E7b4DaB3C24507a6D503"; // Binance wallet with lots of USDC
    const transferAmount = ethers.parseUnits("100000000", usdcDecimals); // 100 USDC (6 decimals)
    
    try {
      // Impersonate the whale account
      await ethers.provider.send("hardhat_impersonateAccount", [usdcWhaleAddress]);
      const whale = await ethers.getSigner(usdcWhaleAddress);
      
      // Fund the whale account with ETH for gas
      await ethers.provider.send("hardhat_setBalance", [
        usdcWhaleAddress,
        ethers.toQuantity(ethers.parseEther("10"))
      ]);
      
      // Transfer USDC from whale to deployer
      const usdcWhale = await ethers.getContractAt("IERC20Minimal", USDC, whale);
      await usdcWhale.transfer(deployer.address, transferAmount);
      
      // Stop impersonating
      await ethers.provider.send("hardhat_stopImpersonatingAccount", [usdcWhaleAddress]);
      
      console.log(`✅ Successfully transferred ${ethers.formatUnits(transferAmount, usdcDecimals)} USDC from whale account`);
    } catch (error) {
      console.log("⚠️ Failed to transfer from whale account, trying alternative method...");
      
      // Alternative: Try another whale address
      const altWhaleAddress = "0x3f5CE5FBFe3E9af3971dD833D26bA9b5C936f0bE"; // Binance alternative
      try {
        await ethers.provider.send("hardhat_impersonateAccount", [altWhaleAddress]);
        const altWhale = await ethers.getSigner(altWhaleAddress);
        
        await ethers.provider.send("hardhat_setBalance", [
          altWhaleAddress,
          ethers.toQuantity(ethers.parseEther("10"))
        ]);
        
        const usdcAltWhale = await ethers.getContractAt("IERC20Minimal", USDC, altWhale);
        await usdcAltWhale.transfer(deployer.address, transferAmount);
        
        await ethers.provider.send("hardhat_stopImpersonatingAccount", [altWhaleAddress]);
        
        console.log(`✅ Successfully transferred ${ethers.formatUnits(transferAmount, usdcDecimals)} USDC from alternative whale account`);
      } catch (altError) {
        console.log("❌ Failed to transfer USDC from whale accounts");
      }
    }

    // Check updated balance
    const usdcBalance = await usdc.balanceOf(deployer.address);
    console.log("=== Wallet Balance Information (After) ===");
    console.log(`USDC Balance: ${ethers.formatUnits(usdcBalance, usdcDecimals)} USDC`);
    console.log("=========================================");
  });

  describe("Initial Setup", function () {
    it("Contract should be deployed correctly", async function () {
      expect(await stele.usdToken()).to.equal(USDC);
    });

    it("Should emit SteleCreated event with correct parameters", async function () {
      const Stele = await ethers.getContractFactory("Stele");
      const stele = await Stele.deploy(USDC, STELE_TOKEN);
      const deployment = await stele.waitForDeployment();
      
      const receipt = await deployment.deploymentTransaction()?.wait();
      
      // Extract SteleCreated event from deployment transaction
      let steleCreatedEvent;
      for (const log of receipt?.logs || []) {
        try {
          const parsedLog = stele.interface.parseLog(log);
          if (parsedLog && parsedLog.name === 'SteleCreated') {
            steleCreatedEvent = parsedLog.args;
            break;
          }
        } catch (e) {
          continue;
        }
      }

      // Ensure event was found
      if (!steleCreatedEvent) {
        throw new Error("SteleCreated event not found in deployment transaction");
      }

      expect(steleCreatedEvent.usdToken).to.equal(USDC);
      expect(steleCreatedEvent.maxAssets).to.equal(10);
      expect(steleCreatedEvent.seedMoney).to.equal(ethers.parseUnits("1000", usdcDecimals));
      expect(steleCreatedEvent.entryFee).to.equal(ethers.parseUnits("10", usdcDecimals));
      expect(steleCreatedEvent.rewardRatio).to.deep.equal([50, 26, 13, 7, 4]);
    });

    it("Tokens should be set as investable", async function () {
      await stele.setToken(WBTC);
      await stele.setToken(WETH);
      expect(await stele.isInvestable(WBTC)).to.be.true;
      expect(await stele.isInvestable(WETH)).to.be.true;
    });
  });

  describe("Challenge Creation - 1 week", function () {
    it("Challenge should be created successfully", async function () {
      await stele.createChallenge(ChallengeType.OneWeek);
      const latestChallengeId = await stele.latestChallengesByType(ChallengeType.OneWeek);
      const challenge = await stele.challenges(latestChallengeId);
      expect(challenge.challengeType).to.equal(ChallengeType.OneWeek);
      expect(challenge.startTime).to.be.gt(0);
      expect(challenge.endTime).to.be.gt(challenge.startTime);
    });
  });

  describe("Challenge Participation", function () {
    it("User should be able to join a challenge - 1 week", async function () {
      try {
        const entryFee = await stele.entryFee();
        const usdTokenDecimals = await stele.usdTokenDecimals();
        
        // Calculate entry fee
        const entryFeeInUsd = ethers.parseUnits(entryFee.toString(), usdTokenDecimals);
        const formatedFee = ethers.formatUnits(entryFeeInUsd, usdTokenDecimals);
        console.log("Entry Fee in USD:", formatedFee); // $0.1
        
        // console.log("Calling getTokenPrice...");
        // const ethPrice = await stele.getTokenPriceETH(WETH, ethers.parseEther("1"), USDC);        
        // console.log("ETH Price in USD:", ethers.formatUnits(ethPrice, usdTokenDecimals));
        
        // if (!ethPrice) {
        //   throw new Error("Could not find ETH price in events");
        // }

        // Prepare USDC tokens for Base Mainnet
        console.log("Preparing USDC tokens...");
        
        // Check USDC balance
        const usdcBalance = await usdc.balanceOf(deployer.address);
        console.log("Current USDC balance:", ethers.formatUnits(usdcBalance, usdcDecimals));
        
        // Required USDC amount
        console.log("Required USDC amount:", ethers.formatUnits(entryFeeInUsd, usdcDecimals));
        
        // Warning for insufficient balance
        if (usdcBalance < entryFeeInUsd) {
          console.warn("⚠️ Warning: Insufficient USDC balance!");
          console.warn(`Required: ${ethers.formatUnits(entryFeeInUsd, usdcDecimals)} USDC, Available: ${ethers.formatUnits(usdcBalance, usdcDecimals)} USDC`);
          throw new Error("Insufficient USDC balance: Please acquire sufficient USDC on Base Mainnet before testing.");
        }
        
        // Output contract address
        console.log("Stele contract address:", await stele.getAddress());
        
        // Approve USDC token usage
        console.log("Approving USDC token usage...");
        const approvalTx = await usdc.approve(await stele.getAddress(), entryFeeInUsd);
        await approvalTx.wait();
        console.log("Approval transaction completed:", approvalTx.hash);
        
        // Check approved amount
        const allowance = await usdc.allowance(deployer.address, await stele.getAddress());
        console.log("Approved USDC amount:", ethers.formatUnits(allowance, usdcDecimals));
        
        if (allowance < entryFeeInUsd) {
          throw new Error("Approved USDC amount is less than required. There was an issue with the approval process.");
        }

        console.log("Calling joinChallenge...");
        const latestChallengeId = await stele.latestChallengesByType(ChallengeType.OneWeek);  
        const joinTx = await stele.joinChallenge(latestChallengeId);        
        const joinReceipt = await joinTx.wait();
        
        // Extract information from events
        let tokenAddress;
        let amount;
        let totalRewards;
        for (const log of joinReceipt.logs) {
          try {
            const parsedLog = stele.interface.parseLog(log);
            if (parsedLog && parsedLog.name === 'DebugJoin') {
              tokenAddress = parsedLog.args.tokenAddress;
              amount = parsedLog.args.amount;
              totalRewards = parsedLog.args.totalRewards;
              console.log("tokenAddress:", tokenAddress);
              console.log("amount:", amount.toString());
              console.log("totalRewards:", totalRewards.toString());
              break;
            }
          } catch (e) {
            console.log("Failed to parse log:", e);
            continue;
          }
        }
      } catch (error) {
        console.error("Test error:", error);
        throw error;
      } finally {
        // Remove event listeners
        stele.removeAllListeners();
      }
    });
  });

  describe("Asset Swap 1", function () {
    it("USDC 100 -> WBTC", async function () {
      try {
        const usdTokenDecimals = await stele.usdTokenDecimals();
        const swapAmount = ethers.parseUnits("100", usdTokenDecimals); // 100 * 10 ** 6 = 10000000

        // Swap from USDC to WBTC
        console.log("Calling swap...");
        console.log("From:", USDC);
        console.log("To:", WBTC);
        console.log("Amount:", swapAmount.toString());
     
        const latestChallengeId = await stele.latestChallengesByType(ChallengeType.OneWeek);
        const swapTx = await stele.swap(latestChallengeId, USDC, WBTC, swapAmount);
        const swapReceipt = await swapTx.wait();
        console.log("Swap transaction completed:", swapReceipt.hash);
        
        // Extract swap information from events
        for (const log of swapReceipt.logs) {
          try {
            const parsedLog = stele.interface.parseLog(log);
            if (parsedLog && parsedLog.name === 'Swap') {
              console.log("Swap event:");
              console.log("  Challenge ID:", parsedLog.args.challengeId.toString());
              console.log("  User:", parsedLog.args.user);
              console.log("  From Asset:", parsedLog.args.fromAsset);
              console.log("  To Asset:", parsedLog.args.toAsset);
              console.log("  From Amount:", parsedLog.args.fromAmount.toString());
              console.log("  To Amount:", parsedLog.args.toAmount.toString());
              break;
            }
          } catch (e) {
            console.log("Failed to parse log:", e);
            continue;
          }
        }
      } catch (error) {
        console.error("Swap test error:", error);
        throw error;
      }
      const latestChallengeId = await stele.latestChallengesByType(ChallengeType.OneWeek);
      // Get portfolio data
      const [tokenAddresses, amounts] = await stele.getUserPortfolio(latestChallengeId, deployer.address);
      console.log("Portfolio data:");
      console.log("  Token Addresses:", tokenAddresses);
      console.log("  Amounts:", amounts);
    });
  });

  describe("Asset Swap 2", function () {
    it("USDC 200 -> WBTC", async function () {
      try {
        const usdTokenDecimals = await stele.usdTokenDecimals();
        const swapAmount = ethers.parseUnits("200", usdTokenDecimals); // 200 * 10 ** 6 = 20000000

        // Swap from USDC to WBTC
        console.log("Calling swap...");
        console.log("From:", USDC);
        console.log("To:", WBTC);
        console.log("Amount:", swapAmount.toString());
     
        const latestChallengeId = await stele.latestChallengesByType(ChallengeType.OneWeek);
        const swapTx = await stele.swap(latestChallengeId, USDC, WBTC, swapAmount);
        const swapReceipt = await swapTx.wait();
        console.log("Swap transaction completed:", swapReceipt.hash);
        
        // Extract swap information from events
        for (const log of swapReceipt.logs) {
          try {
            const parsedLog = stele.interface.parseLog(log);
            if (parsedLog && parsedLog.name === 'Swap') {
              console.log("Swap event:");
              console.log("  Challenge ID:", parsedLog.args.challengeId.toString());
              console.log("  User:", parsedLog.args.user);
              console.log("  From Asset:", parsedLog.args.fromAsset);
              console.log("  To Asset:", parsedLog.args.toAsset);
              console.log("  From Amount:", parsedLog.args.fromAmount.toString());
              console.log("  To Amount:", parsedLog.args.toAmount.toString());
              break;
            }
          } catch (e) {
            console.log("Failed to parse log:", e);
            continue;
          }
        }
      } catch (error) {
        console.error("Swap test error:", error);
        throw error;
      }
      const latestChallengeId = await stele.latestChallengesByType(ChallengeType.OneWeek);
      // Get portfolio data
      const [tokenAddresses, amounts] = await stele.getUserPortfolio(latestChallengeId, deployer.address);
      console.log("Portfolio data:");
      console.log("  Token Addresses:", tokenAddresses);
      console.log("  Amounts:", amounts);
    });
  });


  describe("Asset Swap 3", function () {
    it("USDC 300 -> WBTC", async function () {
      try {
        const usdTokenDecimals = await stele.usdTokenDecimals();
        const swapAmount = ethers.parseUnits("300", usdTokenDecimals); // 300 * 10 ** 6 = 20000000

        // Swap from USDC to WBTC
        console.log("Calling swap...");
        console.log("From:", USDC);
        console.log("To:", WBTC);
        console.log("Amount:", swapAmount.toString());
     
        const latestChallengeId = await stele.latestChallengesByType(ChallengeType.OneWeek);
        const swapTx = await stele.swap(latestChallengeId, USDC, WBTC, swapAmount);
        const swapReceipt = await swapTx.wait();
        console.log("Swap transaction completed:", swapReceipt.hash);
        
        // Extract swap information from events
        for (const log of swapReceipt.logs) {
          try {
            const parsedLog = stele.interface.parseLog(log);
            if (parsedLog && parsedLog.name === 'Swap') {
              console.log("Swap event:");
              console.log("  Challenge ID:", parsedLog.args.challengeId.toString());
              console.log("  User:", parsedLog.args.user);
              console.log("  From Asset:", parsedLog.args.fromAsset);
              console.log("  To Asset:", parsedLog.args.toAsset);
              console.log("  From Amount:", parsedLog.args.fromAmount.toString());
              console.log("  To Amount:", parsedLog.args.toAmount.toString());
              break;
            }
          } catch (e) {
            console.log("Failed to parse log:", e);
            continue;
          }
        }
      } catch (error) {
        console.error("Swap test error:", error);
        throw error;
      }
      const latestChallengeId = await stele.latestChallengesByType(ChallengeType.OneWeek);
      // Get portfolio data
      const [tokenAddresses, amounts] = await stele.getUserPortfolio(latestChallengeId, deployer.address);
      console.log("Portfolio data:");
      console.log("  Token Addresses:", tokenAddresses);
      console.log("  Amounts:", amounts);
    });
  });

  describe("Asset Swap 4", function () {
    it("WBTC -> USDC", async function () {
      try {
        const swapAmount = ethers.parseUnits("0.0005", wbtcDecimals);

        // Swap from WBTC to USDC
        console.log("Calling swap...");
        console.log("From:", WBTC);
        console.log("To:", USDC);
        console.log("Amount:", swapAmount.toString());
        
        const latestChallengeId = await stele.latestChallengesByType(ChallengeType.OneWeek);
        const swapTx = await stele.swap(latestChallengeId, WBTC, USDC, swapAmount);
        const swapReceipt = await swapTx.wait();
        console.log("Swap transaction completed:", swapReceipt.hash);
        
        // Extract swap information from events
        for (const log of swapReceipt.logs) {
          try {
            const parsedLog = stele.interface.parseLog(log);
            if (parsedLog && parsedLog.name === 'Swap') {
              console.log("Swap event:");
              console.log("  Challenge ID:", parsedLog.args.challengeId.toString());
              console.log("  User:", parsedLog.args.user);
              console.log("  From Asset:", parsedLog.args.fromAsset);
              console.log("  To Asset:", parsedLog.args.toAsset);
              console.log("  From Amount:", parsedLog.args.fromAmount.toString());
              console.log("  To Amount:", parsedLog.args.toAmount.toString());
              break;
            }
          } catch (e) {
            console.log("Failed to parse log:", e);
            continue;
          }
        }

        // Get portfolio data
        const [tokenAddresses, amounts] = await stele.getUserPortfolio(latestChallengeId, deployer.address);
        console.log("Portfolio data:");
        console.log("  Token Addresses:", tokenAddresses);
        console.log("  Amounts:", amounts);
      } catch (error) {
        console.error("Swap test error:", error);
        throw error;
      }
    });
  });

  describe("Challenge Creation - 1 month", function () {
    it("Challenge should be created successfully", async function () {
      await stele.createChallenge(ChallengeType.OneMonth);
      const latestChallengeId = await stele.latestChallengesByType(ChallengeType.OneMonth);
      const challenge = await stele.challenges(latestChallengeId);
      expect(challenge.challengeType).to.equal(ChallengeType.OneMonth);
      expect(challenge.startTime).to.be.gt(0);
      expect(challenge.endTime).to.be.gt(challenge.startTime);
    });
  });

  describe("Swap until max assets - 1", function () {
    it("Should successfully swap until maxAssets limit and fail when exceeded", async function () {
      try {
        const latestChallengeId = await stele.latestChallengesByType(ChallengeType.OneWeek);
        const usdTokenDecimals = await stele.usdTokenDecimals();
        const swapAmount = ethers.parseUnits("10", usdTokenDecimals); // 10 USDC per swap

        // Set all new tokens as investable
        const newTokens = [USDT, LINK, UNI, DAI, SHIB, SUSHI];
        console.log("Setting tokens as investable...");
        for (const token of newTokens) {
          await stele.setToken(token);
          console.log(`✅ Set ${token} as investable`);
        }

        // List of tokens to swap to (excluding USDC which is already in portfolio)
        const tokensToSwap = [USDT, LINK, UNI, DAI, SHIB, SUSHI];
        
        console.log("\n=== Starting swaps to reach maxAssets limit ===");
        
        // Perform swaps until we reach the limit
        for (let i = 0; i < tokensToSwap.length; i++) {
          const targetToken = tokensToSwap[i];
          
          try {
            console.log(`\nSwap ${i + 1}: USDC -> ${targetToken}`);
            const swapTx = await stele.swap(latestChallengeId, USDC, targetToken, swapAmount);
            const swapReceipt = await swapTx.wait();
            
            // Extract SwapDebug event for detailed analysis
            for (const log of swapReceipt.logs) {
              try {
                const parsedLog = stele.interface.parseLog(log);
                if (parsedLog && parsedLog.name === 'Swap') {
                  console.log("🔍 Swap Debug Information:");
                  console.log(`  Challenge ID: ${parsedLog.args.challengeId}`);
                  console.log(`  User: ${parsedLog.args.user}`);
                  console.log(`  From Asset: ${parsedLog.args.fromAsset}`);
                  console.log(`  To Asset: ${parsedLog.args.toAsset}`);
                  console.log("  From Amount:", parsedLog.args.fromAmount.toString());
                  console.log("  To Amount:", parsedLog.args.toAmount.toString());
                }
              } catch (e) {
                continue;
              }
            }
            
            // Get current portfolio
            const [tokenAddresses, amounts] = await stele.getUserPortfolio(latestChallengeId, deployer.address);
            console.log(`✅ Swap successful. Portfolio now has ${tokenAddresses.length} tokens`);
            
            // If we've reached 10 tokens, the next swap should fail
            if (tokenAddresses.length === 10) {
              console.log("🎯 Reached maxAssets limit (10 tokens)");
              
              // Try one more swap - this should fail
              if (i + 1 < tokensToSwap.length) {
                const nextToken = tokensToSwap[i + 1];
                console.log(`\nTesting limit: Attempting swap ${i + 2}: USDC -> ${nextToken} (should fail)`);
                
                try {
                  await stele.swap(latestChallengeId, USDC, nextToken, swapAmount);
                  throw new Error("Swap should have failed when exceeding maxAssets limit");
                } catch (error: any) {
                  if (error.message.includes("should have failed")) {
                    throw error; // Re-throw if this is our custom error
                  }
                  console.log("✅ Swap correctly failed when trying to exceed maxAssets limit");
                  console.log(`Error: ${error.message}`);
                }
              }
              break;
            }
            
          } catch (error: any) {
            console.log(`❌ Swap ${i + 1} failed unexpectedly: ${error.message}`);
            throw error;
          }
        }

        // Final portfolio check
        const [finalTokens, finalAmounts] = await stele.getUserPortfolio(latestChallengeId, deployer.address);
        console.log("\n=== Final Portfolio ===");
        console.log(`Total tokens: ${finalTokens.length}`);
        for (let i = 0; i < finalTokens.length; i++) {
          console.log(`${i + 1}. ${finalTokens[i]}: ${finalAmounts[i].toString()}`);
        }
        
        // Verify we have exactly 8 tokens (maxAssets)
        expect(finalTokens.length).to.equal(8);
        
      } catch (error) {
        console.error("Max assets test error:", error);
        throw error;
      }
    });
  });

  describe("Swap until max assets - 2", function () {
    it("Should successfully swap until maxAssets limit and fail when exceeded", async function () {
      try {
        const latestChallengeId = await stele.latestChallengesByType(ChallengeType.OneWeek);
        const usdTokenDecimals = await stele.usdTokenDecimals();
        const swapAmount = ethers.parseUnits("10", usdTokenDecimals); // 10 USDC per swap

        // Set all new tokens as investable
        const newTokens = [AAVE, ONDO, CRV];
        console.log("Setting tokens as investable...");
        for (const token of newTokens) {
          await stele.setToken(token);
          console.log(`✅ Set ${token} as investable`);
        }

        // List of tokens to swap to (excluding USDC which is already in portfolio)
        const tokensToSwap = [AAVE, ONDO, CRV];
        
        console.log("\n=== Starting swaps to reach maxAssets limit ===");
        
        // Perform swaps until we reach the limit
        for (let i = 0; i < tokensToSwap.length; i++) {
          const targetToken = tokensToSwap[i];
          
          try {
            console.log(`\nSwap ${i + 1}: USDC -> ${targetToken}`);
            const swapTx = await stele.swap(latestChallengeId, USDC, targetToken, swapAmount);
            const swapReceipt = await swapTx.wait();
            
            // Extract SwapDebug event for detailed analysis
            for (const log of swapReceipt.logs) {
              try {
                const parsedLog = stele.interface.parseLog(log);
                if (parsedLog && parsedLog.name === 'Swap') {
                  console.log("🔍 Swap Debug Information:");
                  console.log(`  Challenge ID: ${parsedLog.args.challengeId}`);
                  console.log(`  User: ${parsedLog.args.user}`);
                  console.log(`  From Asset: ${parsedLog.args.fromAsset}`);
                  console.log(`  To Asset: ${parsedLog.args.toAsset}`);
                  console.log("  From Amount:", parsedLog.args.fromAmount.toString());
                  console.log("  To Amount:", parsedLog.args.toAmount.toString());
                }
              } catch (e) {
                continue;
              }
            }
            
            // Get current portfolio
            const [tokenAddresses, amounts] = await stele.getUserPortfolio(latestChallengeId, deployer.address);
            console.log(`✅ Swap successful. Portfolio now has ${tokenAddresses.length} tokens`);
            
            // Check USDC balance in portfolio
            let usdcBalance = 0n;
            for (let j = 0; j < tokenAddresses.length; j++) {
              if (tokenAddresses[j].toLowerCase() === USDC.toLowerCase()) {
                usdcBalance = amounts[j];
                break;
              }
            }
            console.log(`💰 Current USDC balance in portfolio: ${ethers.formatUnits(usdcBalance, usdTokenDecimals)} USDC`);
            
            // If we've reached 10 tokens, the next swap should fail
            if (tokenAddresses.length === 10) {
              console.log("🎯 Reached maxAssets limit (10 tokens)");
              
              // Try one more swap - this should fail
              if (i + 1 < tokensToSwap.length) {
                const nextToken = tokensToSwap[i + 1];
                console.log(`\nTesting limit: Attempting swap ${i + 2}: USDC -> ${nextToken} (should fail)`);
                
                try {
                  await stele.swap(latestChallengeId, USDC, nextToken, swapAmount);
                  throw new Error("Swap should have failed when exceeding maxAssets limit");
                } catch (error: any) {
                  if (error.message.includes("should have failed")) {
                    throw error; // Re-throw if this is our custom error
                  }
                  console.log("✅ Swap correctly failed when trying to exceed maxAssets limit");
                  console.log(`Error: ${error.message}`);
                }
              }
              break;
            }
            
          } catch (error: any) {
            console.log(`❌ Swap ${i + 1} failed unexpectedly: ${error.message}`);
            throw error;
          }
        }

        // Final portfolio check
        const [finalTokens, finalAmounts] = await stele.getUserPortfolio(latestChallengeId, deployer.address);
        console.log("\n=== Final Portfolio ===");
        console.log(`Total tokens: ${finalTokens.length}`);
        for (let i = 0; i < finalTokens.length; i++) {
          console.log(`${i + 1}. ${finalTokens[i]}: ${finalAmounts[i].toString()}`);
        }
        
        // Verify we have exactly 10 tokens (maxAssets)
        expect(finalTokens.length).to.equal(10);
        
      } catch (error) {
        console.error("Max assets test error:", error);
        throw error;
      }
    });
  });

  // describe("Challenge End and Rewards", function () {
  //   it("User should be able to receive rewards after challenge ends", async function () {
  //     const challenge = await stele.challenges(0);
  //     await time.increaseTo(challenge.endTime);
      
  //     await stele.connect(deployer).register(0);
  //     await stele.connect(deployer).getRewards(0);
      
  //     const userBalance = await usdc.balanceOf(deployer.address);
  //     expect(userBalance).to.be.gt(0);
  //   });
  // });


});
