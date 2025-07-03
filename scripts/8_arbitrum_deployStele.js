const { ethers } = require("hardhat");

async function main() {
  // Arbitrum
  const wethTokenAddress = "0x82aF49447D8a07e3bd95BD0d56f35241523fBab1"; // WETH
  const usdTokenAddress = "0xaf88d065e77c8cC2239327C5EDb3A432268e5831"; // USDC
  const timeLockAddress = "0x9Ce9a6fC0d94697797581dc5Fb6aAb7e923FD977";
  const steleTokenAddress = "0x5763a0523A672d7c88127e10533bA78853454510";

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