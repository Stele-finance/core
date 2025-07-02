const { ethers } = require("hardhat");

async function main() {
  // Arbitrum
  const usdTokenAddress = "0xaf88d065e77c8cC2239327C5EDb3A432268e5831"; // USDC
  const timeLockAddress = "0x4a31eBF27F7Bd63A116f331f58052b3fA732F487";
  const steleTokenAddress = "0x6BE212Ea54749297710A0BC15991CDf3B6e7923A";

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