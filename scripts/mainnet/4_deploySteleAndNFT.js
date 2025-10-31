const { ethers } = require("hardhat");

async function main() {
  console.log("🚀 Starting Stele Ecosystem Deployment...\n");

  // Mainnet
  const wethTokenAddress = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"; // WETH
  const usdTokenAddress = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"; // USDC
  const timeLockAddress = "0x1F55E11F7a39D3ca3Ea28109b35d173905Cd614e";
  const steleTokenAddress = "0xc4f1E00cCfdF3a068e2e6853565107ef59D96089"; // Stele Token

  console.log(`💰 WETH: ${wethTokenAddress}`);
  console.log(`💵 USDC: ${usdTokenAddress}`);
  console.log(`🎯 Stele Token: ${steleTokenAddress}\n`);

  // Step 1: Deploy Stele contract (without NFT contract address)
  console.log("📝 Step 1: Deploying Stele contract...");
  const SteleFactory = await ethers.getContractFactory("Stele");
  const stele = await SteleFactory.deploy(
    wethTokenAddress,
    usdTokenAddress,
    steleTokenAddress
  );
  await stele.deployed();
  const steleAddress = await stele.address;
  console.log(`✅ Stele deployed at: ${steleAddress}\n`);

  // Step 2: Deploy StelePerformanceNFT contract with Stele address
  console.log("🎨 Step 2: Deploying StelePerformanceNFT contract...");
  const NFTFactory = await ethers.getContractFactory("StelePerformanceNFT");
  const nftContract = await NFTFactory.deploy(steleAddress);
  await nftContract.deployed();
  const nftAddress = await nftContract.address;
  console.log(`✅ StelePerformanceNFT deployed at: ${nftAddress}\n`);

  // Step 3: Set NFT contract address in Stele contract
  console.log("🔗 Step 3: Linking contracts...");
  const linkTx = await stele.setPerformanceNFTContract(nftAddress);
  await linkTx.wait();
  console.log(`✅ NFT contract address set in Stele contract\n`);

  // Step 4: Verify setup
  console.log("🔍 Step 4: Verifying deployment...");
  const linkedNFTAddress = await stele.performanceNFTContract();
  const linkedSteleAddress = await nftContract.steleContract();
  
  console.log("🎯 Verification Results:");
  console.log(`   Stele.performanceNFTContract: ${linkedNFTAddress}`);
  console.log(`   NFT.steleContract: ${linkedSteleAddress}`);
  console.log(`   Addresses match: ${linkedNFTAddress === nftAddress && linkedSteleAddress === steleAddress}\n`);

  // Step 5: Transfer ownership to TimeLock (if available)
  try {
    // Try to get TimeLock address from previous deployment
    console.log("🏛️ Step 5: Transferring ownership to TimeLock...");
    const steleOwnershipTx = await stele.transferOwnership(timeLockAddress);
    await steleOwnershipTx.wait();
    console.log(`✅ Stele ownership transferred to: ${timeLockAddress}`);
    
    const nftOwnershipTx = await nftContract.transferOwnership(timeLockAddress);
    await nftOwnershipTx.wait();
    console.log(`✅ NFT ownership transferred to: ${timeLockAddress}\n`);
  } catch (error) {
    console.log("⚠️  TimeLock transfer skipped (update address manually)\n");
  }

  // Final Summary
  console.log("🎉 DEPLOYMENT COMPLETE! 🎉");
  console.log("=" .repeat(50));
  console.log(`📊 Stele Contract: ${steleAddress}`);
  console.log(`🎨 NFT Contract: ${nftAddress}`);
  console.log(`🔗 Contracts Linked: ✅`);
  console.log("=" .repeat(50));

  // Save deployment addresses for verification
  const deploymentInfo = {
    timestamp: new Date().toISOString(),
    contracts: {
      Stele: steleAddress,
      StelePerformanceNFT: nftAddress,
      WETH: wethTokenAddress,
      USDC: usdTokenAddress,
      SteleToken: steleTokenAddress
    },
    transactions: {
      stele: stele.deploymentTransaction,
      nft: nftContract.deploymentTransaction,
      linking: linkTx.hash
    }
  };

  console.log("\n📋 Deployment Summary:");
  console.log(JSON.stringify(deploymentInfo, null, 2));
}

main()
  .then(() => console.log("✅ Deployment completed successfully"))
  .catch((error) => {
    console.error("❌ Deployment failed:", error);
  });