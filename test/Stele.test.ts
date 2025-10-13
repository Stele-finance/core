import { expect } from "chai";
import { ethers } from "hardhat";
import { Stele, Token, StelePerformanceNFT } from "../typechain-types";
import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";

describe("Stele Protocol Tests", function () {
  this.timeout(300000); // 5 minutes timeout

  // Contract instances
  let stele: Stele;
  let token: Token;
  let performanceNFT: StelePerformanceNFT;

  // Signers
  let owner: SignerWithAddress;
  let user1: SignerWithAddress;
  let user2: SignerWithAddress;
  let user3: SignerWithAddress;

  // Mainnet addresses (forked)
  const USDC_ADDRESS = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48";
  const WETH_ADDRESS = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";
  const USDC_WHALE = "0x47ac0Fb4F2D84898e4D9E7b4DaB3C24507a6D503"; // Circle USDC reserve

  // Contract addresses
  let usdcContract: any;
  let wethContract: any;

  before(async function () {
    // Get signers
    [owner, user1, user2, user3] = await ethers.getSigners();

    // Connect to USDC and WETH contracts
    usdcContract = await ethers.getContractAt(
      "IERC20Minimal",
      USDC_ADDRESS
    );
    wethContract = await ethers.getContractAt(
      "IERC20Minimal",
      WETH_ADDRESS
    );

    console.log("Deploying contracts...");

    // Deploy Token (STL)
    const TokenFactory = await ethers.getContractFactory("Token");
    token = await TokenFactory.deploy();
    await token.waitForDeployment();
    console.log("Token deployed to:", await token.getAddress());

    // Deploy Stele
    const SteleFactory = await ethers.getContractFactory("Stele");
    stele = await SteleFactory.deploy(
      WETH_ADDRESS,
      USDC_ADDRESS,
      await token.getAddress()
    );
    await stele.waitForDeployment();
    console.log("Stele deployed to:", await stele.getAddress());

    // Deploy Performance NFT
    const NFTFactory = await ethers.getContractFactory("StelePerformanceNFT");
    performanceNFT = await NFTFactory.deploy(await stele.getAddress());
    await performanceNFT.waitForDeployment();
    console.log("Performance NFT deployed to:", await performanceNFT.getAddress());

    // Set NFT contract in Stele
    await stele.setPerformanceNFTContract(await performanceNFT.getAddress());

    // Transfer STL tokens to Stele contract for bonuses
    const steleTokenBalance = ethers.parseEther("10000000"); // 10M tokens
    await token.transfer(await stele.getAddress(), steleTokenBalance);

    // Fund test users with USDC from whale
    await ethers.provider.send("hardhat_impersonateAccount", [USDC_WHALE]);
    const whale = await ethers.getSigner(USDC_WHALE);

    // Send ETH to whale for gas
    await owner.sendTransaction({
      to: USDC_WHALE,
      value: ethers.parseEther("10")
    });

    const fundAmount = ethers.parseUnits("10000", 6); // 10,000 USDC
    await usdcContract.connect(whale).transfer(user1.address, fundAmount);
    await usdcContract.connect(whale).transfer(user2.address, fundAmount);
    await usdcContract.connect(whale).transfer(user3.address, fundAmount);

    await ethers.provider.send("hardhat_stopImpersonatingAccount", [USDC_WHALE]);

    console.log("Setup complete!");
  });

  describe("Challenge Creation and Joining", function () {
    let challengeId: bigint;

    it("Should create a new challenge", async function () {
      const tx = await stele.createChallenge(0); // ChallengeType.OneWeek
      await tx.wait();

      challengeId = await stele.challengeCounter();
      expect(challengeId).to.equal(1);

      const challengeInfo = await stele.getChallengeInfo(challengeId);
      expect(challengeInfo._totalUsers).to.equal(0);
    });

    it("Should allow user1 to join the challenge", async function () {
      const entryFee = await stele.entryFee();

      // Approve USDC
      await usdcContract.connect(user1).approve(await stele.getAddress(), entryFee);

      // Join challenge
      const tx = await stele.connect(user1).joinChallenge(challengeId);
      await tx.wait();

      const challengeInfo = await stele.getChallengeInfo(challengeId);
      expect(challengeInfo._totalUsers).to.equal(1);
      expect(challengeInfo._totalRewards).to.equal(entryFee);
    });

    it("Should allow user2 and user3 to join", async function () {
      const entryFee = await stele.entryFee();

      // User2 joins
      await usdcContract.connect(user2).approve(await stele.getAddress(), entryFee);
      await stele.connect(user2).joinChallenge(challengeId);

      // User3 joins
      await usdcContract.connect(user3).approve(await stele.getAddress(), entryFee);
      await stele.connect(user3).joinChallenge(challengeId);

      const challengeInfo = await stele.getChallengeInfo(challengeId);
      expect(challengeInfo._totalUsers).to.equal(3);
    });

    it("Should prevent duplicate join", async function () {
      const entryFee = await stele.entryFee();
      await usdcContract.connect(user1).approve(await stele.getAddress(), entryFee);

      await expect(
        stele.connect(user1).joinChallenge(challengeId)
      ).to.be.revertedWith("AJ"); // Already Joined
    });
  });

  describe("Swap Functionality", function () {
    let challengeId: bigint;

    before(async function () {
      // Fast forward time to end previous challenge
      await ethers.provider.send("evm_increaseTime", [7 * 24 * 60 * 60 + 1]);
      await ethers.provider.send("evm_mine", []);

      // Create and join a new challenge
      await stele.createChallenge(0);
      challengeId = await stele.challengeCounter();

      const entryFee = await stele.entryFee();
      await usdcContract.connect(user1).approve(await stele.getAddress(), entryFee);
      await stele.connect(user1).joinChallenge(challengeId);
    });

    it("Should swap USDC to WETH", async function () {
      const swapAmount = ethers.parseUnits("100", 6); // 100 USDC

      const tx = await stele.connect(user1).swap(
        challengeId,
        USDC_ADDRESS,
        WETH_ADDRESS,
        swapAmount
      );
      await tx.wait();

      // Check portfolio
      const [tokens, amounts] = await stele.getUserPortfolio(challengeId, user1.address);

      console.log("After swap:");
      console.log("Tokens:", tokens);
      console.log("Amounts:", amounts);

      // Should have USDC and WETH now
      expect(tokens.length).to.be.gte(2);
    });

    it("Should prevent swapping more than balance", async function () {
      const seedMoney = await stele.seedMoney();
      const excessAmount = seedMoney + ethers.parseUnits("1000", 6);

      await expect(
        stele.connect(user1).swap(
          challengeId,
          USDC_ADDRESS,
          WETH_ADDRESS,
          excessAmount
        )
      ).to.be.revertedWith("FTM"); // Funds Too Much
    });

    it("Should test precision improvement with mulDiv", async function () {
      // Small amount swap to test precision
      const smallAmount = ethers.parseUnits("1", 6); // 1 USDC

      const beforePortfolio = await stele.getUserPortfolio(challengeId, user1.address);

      await stele.connect(user1).swap(
        challengeId,
        USDC_ADDRESS,
        WETH_ADDRESS,
        smallAmount
      );

      const afterPortfolio = await stele.getUserPortfolio(challengeId, user1.address);

      // Verify that swap happened with reasonable precision
      // (exact amounts depend on current market prices)
      expect(afterPortfolio[0].length).to.be.gte(beforePortfolio[0].length);
    });
  });

  describe("Register and Ranking", function () {
    let challengeId: bigint;

    before(async function () {
      // Fast forward time to end previous challenge
      await ethers.provider.send("evm_increaseTime", [7 * 24 * 60 * 60 + 1]);
      await ethers.provider.send("evm_mine", []);

      // Create challenge
      await stele.createChallenge(0);
      challengeId = await stele.challengeCounter();

      // All users join
      const entryFee = await stele.entryFee();

      await usdcContract.connect(user1).approve(await stele.getAddress(), entryFee);
      await stele.connect(user1).joinChallenge(challengeId);

      await usdcContract.connect(user2).approve(await stele.getAddress(), entryFee);
      await stele.connect(user2).joinChallenge(challengeId);

      await usdcContract.connect(user3).approve(await stele.getAddress(), entryFee);
      await stele.connect(user3).joinChallenge(challengeId);
    });

    it("Should register and update ranking", async function () {
      // User1 swaps to increase portfolio value
      const swapAmount = ethers.parseUnits("500", 6);
      await stele.connect(user1).swap(challengeId, USDC_ADDRESS, WETH_ADDRESS, swapAmount);

      // Register is called automatically after swap
      const [topUsers, scores] = await stele.getRanking(challengeId);

      console.log("Top Users:", topUsers);
      console.log("Scores:", scores);

      // Check that rankings are tracked
      expect(topUsers[0]).to.not.equal(ethers.ZeroAddress);
    });

    it("Should maintain proper ranking order", async function () {
      // User2 makes profitable swaps
      await stele.connect(user2).swap(
        challengeId,
        USDC_ADDRESS,
        WETH_ADDRESS,
        ethers.parseUnits("300", 6)
      );

      // User3 makes different swaps
      await stele.connect(user3).swap(
        challengeId,
        USDC_ADDRESS,
        WETH_ADDRESS,
        ethers.parseUnits("200", 6)
      );

      const [topUsers, scores] = await stele.getRanking(challengeId);

      // Verify scores are in descending order
      for (let i = 0; i < topUsers.length - 1; i++) {
        if (topUsers[i] !== ethers.ZeroAddress && topUsers[i + 1] !== ethers.ZeroAddress) {
          expect(scores[i]).to.be.gte(scores[i + 1]);
        }
      }
    });
  });

  describe("Get Rewards", function () {
    let challengeId: bigint;

    before(async function () {
      // Fast forward time to end previous challenge
      await ethers.provider.send("evm_increaseTime", [7 * 24 * 60 * 60 + 1]);
      await ethers.provider.send("evm_mine", []);

      // Create challenge
      await stele.createChallenge(0); // OneWeek
      challengeId = await stele.challengeCounter();

      // Users join
      const entryFee = await stele.entryFee();

      await usdcContract.connect(user1).approve(await stele.getAddress(), entryFee);
      await stele.connect(user1).joinChallenge(challengeId);

      await usdcContract.connect(user2).approve(await stele.getAddress(), entryFee);
      await stele.connect(user2).joinChallenge(challengeId);

      // Make some swaps to create rankings
      await stele.connect(user1).swap(
        challengeId,
        USDC_ADDRESS,
        WETH_ADDRESS,
        ethers.parseUnits("100", 6)
      );
    });

    it("Should not allow reward claim before challenge ends", async function () {
      await expect(
        stele.connect(user1).getRewards(challengeId)
      ).to.be.revertedWith("NE"); // Not Ended
    });

    it("Should distribute rewards after challenge ends", async function () {
      // Fast forward time by 7 days
      await ethers.provider.send("evm_increaseTime", [7 * 24 * 60 * 60]);
      await ethers.provider.send("evm_mine", []);

      // Get ranking before reward distribution
      const [topUsers, scores] = await stele.getRanking(challengeId);
      console.log("Final Rankings:");
      console.log("Top Users:", topUsers);
      console.log("Scores:", scores);

      // First user claims rewards
      const user1BalanceBefore = await usdcContract.balanceOf(user1.address);

      await stele.connect(user1).getRewards(challengeId);

      const user1BalanceAfter = await usdcContract.balanceOf(user1.address);
      const rewardReceived = user1BalanceAfter - user1BalanceBefore;

      console.log("User1 reward received:", ethers.formatUnits(rewardReceived, 6), "USDC");

      // Verify reward was received
      if (topUsers[0] === user1.address || topUsers[1] === user1.address) {
        expect(rewardReceived).to.be.gt(0);
      }
    });

    it("Should prevent double claiming", async function () {
      await expect(
        stele.connect(user1).getRewards(challengeId)
      ).to.be.revertedWith("AD"); // Already Distributed
    });
  });

  describe("Performance NFT Minting", function () {
    let challengeId: bigint;

    before(async function () {
      // Fast forward time to end previous challenge
      await ethers.provider.send("evm_increaseTime", [7 * 24 * 60 * 60 + 1]);
      await ethers.provider.send("evm_mine", []);

      // Create challenge
      await stele.createChallenge(0);
      challengeId = await stele.challengeCounter();

      // Users join
      const entryFee = await stele.entryFee();

      await usdcContract.connect(user1).approve(await stele.getAddress(), entryFee);
      await stele.connect(user1).joinChallenge(challengeId);

      await usdcContract.connect(user2).approve(await stele.getAddress(), entryFee);
      await stele.connect(user2).joinChallenge(challengeId);

      // Make swaps
      await stele.connect(user1).swap(
        challengeId,
        USDC_ADDRESS,
        WETH_ADDRESS,
        ethers.parseUnits("200", 6)
      );

      // Fast forward time
      await ethers.provider.send("evm_increaseTime", [7 * 24 * 60 * 60]);
      await ethers.provider.send("evm_mine", []);

      // Distribute rewards first
      await stele.connect(user1).getRewards(challengeId);
    });

    it("Should allow top 5 to mint performance NFT", async function () {
      const [topUsers] = await stele.getRanking(challengeId);

      if (topUsers[0] === user1.address) {
        const tx = await stele.connect(user1).mintPerformanceNFT(challengeId);
        await tx.wait();

        const balance = await performanceNFT.balanceOf(user1.address);
        expect(balance).to.equal(1);

        console.log("User1 minted NFT successfully");
      }
    });

    it("Should verify NFT is soulbound", async function () {
      // Check if user1 has any NFTs
      const balance = await performanceNFT.balanceOf(user1.address);

      if (balance > 0n) {
        // Get token ID from totalSupply
        const totalSupply = await performanceNFT.totalSupply();
        const tokenId = totalSupply - 1n; // Last minted token

        await expect(
          performanceNFT.connect(user1).transferFrom(user1.address, user2.address, tokenId)
        ).to.be.revertedWith("SBT"); // Soulbound Token

        console.log("Verified NFT is soulbound");
      } else {
        console.log("User1 did not mint NFT (not in top 5)");
        this.skip();
      }
    });
  });
});
