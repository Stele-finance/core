# Stele dapp smart contract

Ethereum Mainnet deploy

```shell
nvm use 23
npm install
npx hardhat compile
npx hardhat test --network hardhat

npx hardhat run scripts/1_deployToken.js --network mainnet
npx hardhat run scripts/2_deployTimeLock.js --network mainnet
npx hardhat run scripts/3_deployGovernor.js --network mainnet
npx hardhat run scripts/4_deployStele.js --network mainnet
```

In the root of project, create a file named .env and add the following
```shell
PRIVATE_KEY=your_private_key_here
INFURA_API_KEY=your_infura_api_key_here
```
