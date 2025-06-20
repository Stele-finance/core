const { ethers } = require("hardhat");

async function main() {
  // Mainnet
  const usdTokenAddress = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"; // USDC
  const timeLockAddress = "0x224C9D355e0F88bD6ef8e4168D1aE1c907B5762e";
  const steleTokenAddress = "0xB82f40c4b42960BA4387c5FaC5763a3e86a1BF3c";

  const Stele = await ethers.getContractFactory("Stele");
  const stele = await Stele.deploy(usdTokenAddress, steleTokenAddress);
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