const { ethers } = require("hardhat");

async function main() {
  // Mainnet
  const usdTokenAddress = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"; // USDC
  const timeLockAddress = "0x68E7acEbB4CB8D87AA24009963B90de5275C8852";
  const steleTokenAddress = "0x2665b58A57Aad89C0d0268F3A7677F6b76730801";

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