import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@nomicfoundation/hardhat-ignition";
import "dotenv/config";

const config: HardhatUserConfig = {
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
      accounts: [process.env.PRIVATE_KEY || ""],
      chainId: 1,
    },
    base: {
      url: "https://mainnet.base.org",
      chainId: 8453,
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
      timeout: 60000,
      httpHeaders: {
        "User-Agent": "Hardhat"
      }
    },
  },
  etherscan: {
    apiKey: {
      base: process.env.INFURA_API_KEY || "",
    }
  },
  mocha: {
    timeout: 100000
  }
};

export default config;
