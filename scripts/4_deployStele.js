const { ethers } = require("hardhat");

async function main() {
  // Base Mainnet
  const usdTokenAddress = "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913"; // USDC
  const timeLockAddress = "0xAAC6C7109d81349C6d4c7F1897A4774A330EcCB5";
  const steleTokenAddress = "0x99deb697B05A1C86580E69fE37675d54a61998d9";

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