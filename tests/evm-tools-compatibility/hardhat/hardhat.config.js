require("@nomicfoundation/hardhat-toolbox");
require("hardhat-deploy");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: "0.8.28",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  networks: {
    localhost: {
      url: "http://127.0.0.1:8545",
    },
    integraTestnet: {
      url: "https://testnet.integralayer.com/evm",
      chainId: 26218,
    },
    integraMainnet: {
      url: "https://mainnet.integralayer.com/evm",
      chainId: 26217,
    },
  },
  namedAccounts: {
    deployer: {
      default: 0,
    },
  },
  etherscan: {
    apiKey: {
      localhost: "empty",
    },
    customChains: [
      {
        network: "localhost",
        chainId: 262144,
        urls: {
          apiURL: "http://localhost/api",
          browserURL: "http://localhost",
        },
      },
      {
        network: "integraTestnet",
        chainId: 26218,
        urls: {
          apiURL: "https://testnet.blockscout.integralayer.com/api",
          browserURL: "https://testnet.blockscout.integralayer.com",
        },
      },
      {
        network: "integraMainnet",
        chainId: 26217,
        urls: {
          apiURL: "https://blockscout.integralayer.com/api",
          browserURL: "https://blockscout.integralayer.com",
        },
      },
    ],
  },
};
