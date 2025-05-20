const { ethers } = require("hardhat");

async function main() {
  // Base Mainnet
  const usdTokenAddress = "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913"; // USDC
  const timeLockAddress = "0xB32B22F3875d1E9953F8dC2cAb2785bD8391eAbb";
  
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