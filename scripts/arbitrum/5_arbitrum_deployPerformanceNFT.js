const { ethers } = require("hardhat");

async function main() {
  console.log("🚀 Starting StelePerformanceNFT Deployment...\n");

  // Arbitrum - Stele contract address (must be deployed already)
  const steleAddress = "0xC9B7A308654B3c5604F1ebaF7AC9D28FA423E5EB"; // Replace with actual Stele contract address
  
  console.log(`📊 Stele Contract: ${steleAddress}\n`);

  // Deploy StelePerformanceNFT contract with Stele address
  console.log("🎨 Deploying StelePerformanceNFT contract...");
  const NFTFactory = await ethers.getContractFactory("StelePerformanceNFT");
  const nftContract = await NFTFactory.deploy(steleAddress);
  await nftContract.deployed();
  const nftAddress = await nftContract.address;
  console.log(`✅ StelePerformanceNFT deployed at: ${nftAddress}\n`);

  // Verify setup
  console.log("🔍 Verifying deployment...");
  const linkedSteleAddress = await nftContract.steleContract();
  
  console.log("🎯 Verification Results:");
  console.log(`   NFT.steleContract: ${linkedSteleAddress}`);
  console.log(`   Stele address match: ${linkedSteleAddress === steleAddress}\n`);

  // Note: After deployment, you need to call setPerformanceNFTContract on the Stele contract
  console.log("⚠️  IMPORTANT: Next Steps");
  console.log("   1. Call Stele.setPerformanceNFTContract() with the NFT address");
  console.log(`      stele.setPerformanceNFTContract("${nftAddress}")`);
  console.log("   2. Transfer NFT ownership to TimeLock if needed\n");

  // Final Summary
  console.log("🎉 DEPLOYMENT COMPLETE! 🎉");
  console.log("=" .repeat(50));
  console.log(`🎨 NFT Contract: ${nftAddress}`);
  console.log(`📊 Linked to Stele: ${steleAddress}`);
  console.log("=" .repeat(50));

  // Save deployment info
  const deploymentInfo = {
    timestamp: new Date().toISOString(),
    contracts: {
      StelePerformanceNFT: nftAddress,
      SteleContract: steleAddress
    },
    transaction: nftContract.deploymentTransaction?.hash
  };

  console.log("\n📋 Deployment Summary:");
  console.log(JSON.stringify(deploymentInfo, null, 2));
}

main()
  .then(() => console.log("\n✅ NFT Deployment completed successfully"))
  .catch((error) => {
    console.error("❌ Deployment failed:", error);
    process.exit(1);
  });