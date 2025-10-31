import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@nomicfoundation/hardhat-ignition";
import "dotenv/config";

const config: HardhatUserConfig = {
  solidity: {
    compilers: [
      {
        version: "0.8.28",
        settings: {
          optimizer: {
              enabled: true,
              runs: 470,
          },
          viaIR: true
        },

      },
    ],
  },
  networks: {
    hardhat: {
      chainId: 31337,
      forking: {
        url: "https://mainnet.infura.io/v3/" + process.env.INFURA_API_KEY,
        blockNumber: 23000000
      },
      //allowUnlimitedContractSize: true,
    },
    mainnet: {
      url: "https://mainnet.infura.io/v3/" + process.env.INFURA_API_KEY,
      accounts: [process.env.PRIVATE_KEY || ""],
      chainId: 1,
    },
    base: {
      url: "https://mainnet.base.org",
      chainId: 8453,
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
      httpHeaders: {
        "User-Agent": "Hardhat"
      }
    },
    arbitrum: {
      url: "https://arbitrum-mainnet.infura.io/v3/" + process.env.INFURA_API_KEY,
      chainId: 42161,
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
    },
  },
  etherscan: {
    apiKey: {
      base: process.env.INFURA_API_KEY || "",
      arbitrumOne: process.env.ARBISCAN_API_KEY || "",
    }
  },
  mocha: {
    timeout: 300000 // 5 minutes
  }
};

export default config;
