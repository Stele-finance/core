const { ethers } = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying governance contracts with the account:", deployer.address);
  console.log("Account balance:", (await ethers.provider.getBalance(deployer.address)).toString());

  // Mainnet
  const tokenAddress = "0x2665b58A57Aad89C0d0268F3A7677F6b76730801";
  const timeLockAddress = "0x68E7acEbB4CB8D87AA24009963B90de5275C8852";
  // Governor values
  const QUORUM_PERCENTAGE = 4; // 4%
  const VOTING_PERIOD = 272; // 1 hour for initial testing period, default : 7 days (45818 blocks)
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