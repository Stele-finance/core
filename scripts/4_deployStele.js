const { ethers } = require("hardhat");

async function main() {
  // Base mainnet
  const usdTokenAddress = "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913"; // USDC
  const timeLockAddress = "0xa584573413761D2CAd7d1929Ee5Fef5E983Ab3da";
  
  const Stele = await ethers.getContractFactory("Stele");
  const stele = await Stele.deploy(usdTokenAddress);
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