const LuckyDuckPack = artifacts.require("LuckyDuckPack");
const LDPMinter = artifacts.require("LDPMinter");
const LDPRewarder = artifacts.require("LDPRewarder");

module.exports = function (deployer) {

  deployer.deploy(LuckyDuckPack);
  deployer.deploy(LDPMinter);
  deployer.deploy(LDPRewarder);
  
};