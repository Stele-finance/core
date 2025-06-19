import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@nomicfoundation/hardhat-ethers";
require("@nomicfoundation/hardhat-ignition");
require('dotenv').config();

const ETHERSCAN_API_KEY = process.env.ETHERSCAN_API_KEY || "P35YFHFMUKNMPDAVG73MIB4W53N2E91IA3";

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    compilers: [
      {
        version: "0.8.8",
        settings: {
          optimizer: {
              enabled: true,
              runs: 1000000,
          },
        },
      },
      { version: "0.7.6",
        settings: {
          optimizer: {
              enabled: true,
              runs: 1000000,
          },
        },
      },
    ],
  },
  networks: {
    hardhat: {
      chainId: 31337,
      forking: {
        url: "https://mainnet.infura.io/v3/" + process.env.INFURA_API_KEY,
        //blockNumber: 14390000
      },
      //allowUnlimitedContractSize: true,
    },
    mainnet: {
      url: "https://mainnet.infura.io/v3/" + process.env.INFURA_API_KEY,
      accounts: [process.env.PRIVATE_KEY],
      chainId: 1,
    },
    base: {
      url: "https://base-mainnet.infura.io/v3/" + process.env.INFURA_API_KEY,
      accounts: [process.env.PRIVATE_KEY],
      chainId: 8453,
    },
    etherscan: {
      apiKey: {
        sepolia: ETHERSCAN_API_KEY,
      },
    },
  },
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts"
  },
  mocha: {
    timeout: 100000
  }
}; 