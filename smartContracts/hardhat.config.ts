import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@nomicfoundation/hardhat-ignition-ethers";
import "dotenv/config";
const config: HardhatUserConfig = {
  solidity: "0.8.24",
  defaultNetwork: "hardhat",
  networks: {
    hardhat: {},
    sepolia: {
      url: "https://eth-sepolia.g.alchemy.com/v2/demo",
      accounts: [process.env.SEPOLIA_KEY],
      chainId: 11155111,
    },
    localhost: {
      url: "http://localhost:8545",
      chainId: 31337,
    },
  },
};

export default config;
