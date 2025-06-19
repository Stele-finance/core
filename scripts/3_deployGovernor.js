const { ethers } = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying governance contracts with the account:", deployer.address);
  console.log("Account balance:", (await ethers.provider.getBalance(deployer.address)).toString());

  // Mainnet
  const tokenAddress = "0xB82f40c4b42960BA4387c5FaC5763a3e86a1BF3c";
  const timeLockAddress = "0x224C9D355e0F88bD6ef8e4168D1aE1c907B5762e";
  // Governor values
  const QUORUM_PERCENTAGE = 4; // 4%
  const VOTING_PERIOD = 45818; // 1 week
  const VOTING_DELAY = 1; // 1 block

  // Deploy Governor
  console.log("Deploying SteleGovernor...");
  const SteleGovernor = await ethers.getContractFactory("SteleGovernor");
  const governor = await SteleGovernor.deploy(
    tokenAddress,
    timeLockAddress,
    QUORUM_PERCENTAGE,
    VOTING_PERIOD,
    VOTING_DELAY
  );
  await governor.deploymentTransaction().wait();
  const governorAddress = governor.target;
  console.log("SteleGovernor deployed to:", governorAddress);

  // Setup roles
  console.log("Setting up roles...");
  
  // TimeLock roles to be set up
  const timeLock = await ethers.getContractAt("TimeLock", timeLockAddress)
  const proposerRole = await timeLock.PROPOSER_ROLE();
  const executorRole = await timeLock.EXECUTOR_ROLE();
  const adminRole = await timeLock.TIMELOCK_ADMIN_ROLE();

  // Grant proposer role to governor
  const proposerTx = await timeLock.grantRole(proposerRole, governorAddress);
  await proposerTx.wait();
  console.log("Proposer role granted to governor");

  // Grant executor role to everyone (address zero)
  const executorTx = await timeLock.grantRole(executorRole, ethers.ZeroAddress);
  await executorTx.wait();
  console.log("Executor role granted to everyone");

  // Revoke admin role from deployer
  const revokeTx = await timeLock.revokeRole(adminRole, deployer.address);
  await revokeTx.wait();
  console.log("Admin role revoked from deployer");

  console.log("Governance setup completed!");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
}); 