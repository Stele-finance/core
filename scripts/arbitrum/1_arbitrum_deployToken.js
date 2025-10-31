const { ethers } = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);
  console.log("Account balance:", (await ethers.provider.getBalance(deployer.address)).toString());

  const SteleToken = await ethers.getContractFactory("Token");
  const token = await SteleToken.deploy();
  await token.deployed();
  const tokenAddress = await token.address;
  console.log("SteleToken deployed to:", tokenAddress);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});