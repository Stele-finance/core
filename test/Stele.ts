import { expect } from "chai";
import { ethers } from "hardhat";

describe("Stele Contract", function () {
  let deployer: any;
  let user1: any;
  let user2: any;
  let stele: any;
  let usdc: any;
  let cbbtc: any;
  let usdcDecimals: number;
  let cbbtcDecimals: number;

  // Base Mainnet token addresses
  const USDC = process.env.USDC || "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913";
  const WETH = process.env.WETH || "0x4200000000000000000000000000000000000006";
  const CBBTC = process.env.CBBTC || "0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf";
  
  before("Setup", async function () {
    try {
      const [owner, otherAccount, thirdAccount] = await ethers.getSigners();
      deployer = owner;
      user1 = otherAccount;
      user2 = thirdAccount;

      // Deploy Stele contract
      const Stele = await ethers.getContractFactory("Stele");
      stele = await Stele.deploy(USDC);
      await stele.waitForDeployment();

      // Get USDC contract instance
      usdc = await ethers.getContractAt("IERC20Minimal", USDC);
      cbbtc = await ethers.getContractAt("IERC20Minimal", CBBTC);
      usdcDecimals = await stele.usdTokenDecimals();
      cbbtcDecimals = await cbbtc.decimals();

      // Initial setup
      await stele.setToken(CBBTC);
      await stele.setToken(WETH);
    } catch (error) {
      console.error("Setup error:", error);
      throw error;
    }
  });

  describe("Initial Setup", function () {
    it("Contract should be deployed correctly", async function () {
      expect(await stele.usdToken()).to.equal(USDC);
    });

    it("Tokens should be set as investable", async function () {
      await stele.setToken(CBBTC);
      await stele.setToken(WETH);
      expect(await stele.isInvestable(CBBTC)).to.be.true;
      expect(await stele.isInvestable(WETH)).to.be.true;
    });
  });

  describe("Challenge Creation", function () {
    it("Challenge should be created successfully", async function () {
      const challengeType = 0; // OneWeek
      await stele.createChallenge(challengeType);
      
      const challenge = await stele.challenges(0);
      expect(challenge.challengeType).to.equal(challengeType);
      expect(challenge.startTime).to.be.gt(0);
      expect(challenge.endTime).to.be.gt(challenge.startTime);
    });
  });

  describe("Challenge Participation", function () {
    it("User should be able to join a challenge", async function () {
      try {
        const entryFee = await stele.entryFee();
        const usdTokenDecimals = await stele.usdTokenDecimals();
        
        // Calculate entry fee
        const entryFeeInUsd = ethers.parseUnits(entryFee.toString(), usdTokenDecimals) / 100n;
        const entryFeeInUsd2 = ethers.formatUnits(entryFeeInUsd, usdTokenDecimals);
        console.log("Entry Fee in USD:", entryFeeInUsd2); // $0.1
        
        console.log("Calling getTokenPrice...");
        const ethPriceTx = await stele.getTokenPrice(WETH, ethers.parseEther("1"), USDC);        
        const receipt = await ethPriceTx.wait();
        
        // Extract price information from events
        let ethPrice;
        for (const log of receipt.logs) {
          try {
            const parsedLog = stele.interface.parseLog(log);
            if (parsedLog && parsedLog.name === 'DebugTokenPrice') {
              ethPrice = parsedLog.args.quoteAmount;
              console.log("ETH Price in USD:", ethers.formatUnits(ethPrice, usdTokenDecimals));
              break;
            }
          } catch (e) {
            console.log("Failed to parse log:", e);
            continue;
          }
        }
        
        if (!ethPrice) {
          throw new Error("Could not find ETH price in events");
        }

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
        const joinTx = await stele.joinChallenge(0);        
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
    it("USDC 100 -> cbBTC", async function () {
      try {
        const usdTokenDecimals = await stele.usdTokenDecimals();
        const swapAmount = ethers.parseUnits("100", usdTokenDecimals); // 100 * 10 ** 6 = 10000000

        // Swap from USDC to CBBTC
        console.log("Calling swap...");
        console.log("From:", USDC);
        console.log("To:", CBBTC);
        console.log("Amount:", swapAmount.toString());
        
        const swapTx = await stele.swap(0, USDC, CBBTC, swapAmount);
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
              console.log("  fromPriceUSD:", parsedLog.args.fromPriceUSD.toString());
              console.log("  toPriceUSD:", parsedLog.args.toPriceUSD.toString());
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
    });
  });

  describe("Asset Swap 2", function () {
    it("cbBTC -> USDC", async function () {
      try {
        const swapAmount = ethers.parseUnits("0.0005", cbbtcDecimals);

        // Swap from CBBTC to USDC
        console.log("Calling swap...");
        console.log("From:", CBBTC);
        console.log("To:", USDC);
        console.log("Amount:", swapAmount.toString());
        
        const swapTx = await stele.swap(0, CBBTC, USDC, swapAmount);
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
              console.log("  fromPriceUSD:", parsedLog.args.fromPriceUSD.toString());
              console.log("  toPriceUSD:", parsedLog.args.toPriceUSD.toString());
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
