const PriceFeed = artifacts.require("./PriceFeed.sol");
const DateTime = artifacts.require("./DateTime.sol");
const owner = web3.eth.accounts[0]

module.exports = deployer => {
  deployer.deploy(DateTime);
  deployer.link(DateTime, PriceFeed);
  deployer.deploy(PriceFeed, { from: owner, gas: 4e6 });
};
