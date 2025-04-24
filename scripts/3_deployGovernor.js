const { ethers } = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying governance contracts with the account:", deployer.address);
  console.log("Account balance:", (await ethers.provider.getBalance(deployer.address)).toString());

  // Base mainnet
  const tokenAddress = "0x645c85B68b94439F9CEC4630B4b8145C7EBED0d9";
  const timeLockAddress = "0xa584573413761D2CAd7d1929Ee5Fef5E983Ab3da";
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