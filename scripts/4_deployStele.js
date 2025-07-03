const { ethers } = require("hardhat");

async function main() {
  // Mainnet
  const wethTokenAddress = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"; // WETH
  const usdTokenAddress = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"; // USDC
  const timeLockAddress = "0xE4a26F02beAd76083BAfC2240096A3757962fC95";
  const steleTokenAddress = "0x71c24377e7f24b6d822C9dad967eBC77C04667b5";

  const Stele = await ethers.getContractFactory("Stele");
  const stele = await Stele.deploy(wethTokenAddress, usdTokenAddress, steleTokenAddress);
  const receipt = await stele.deploymentTransaction().wait();

  // get the deployed contract address
  const steleAddress = stele.target;
  console.log("Stele deployed to:", steleAddress);

  // transfer ownership to Governor
  await stele.transferOwnership(timeLockAddress);
  console.log("Stele ownership transferred to TimeLock");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});