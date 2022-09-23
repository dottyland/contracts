require("@nomicfoundation/hardhat-toolbox");

/** @type import('hardhat/config').HardhatUserConfig */
const ALCHEMY_API_KEY = "iThq_d_qfOMsu_fH3947aks6FIW8Cew2";
const GOERLI_PRIVATE_KEY = "dde4ca9caddb09c9feb35a357d07d7f9d2e48e1e8649c13d26ee3dbe8e027685";
module.exports = {
  solidity: "0.8.9",
  networks: {
    goerli: {
      url: `https://eth-goerli.alchemyapi.io/v2/${ALCHEMY_API_KEY}`,
      accounts: [GOERLI_PRIVATE_KEY]
    }
  },
  etherscan:{
    apiKey:"ERZ93DCWGFS63MZ34AAMYHEVUDDZC1Y22Y"
  }
};
