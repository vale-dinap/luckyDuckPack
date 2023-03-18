const LuckyDuckPack = artifacts.require("LuckyDuckPack");
const LDPMinter = artifacts.require("LDPMinter");
const LDPRewarder = artifacts.require("LDPRewarder");

const creatorAddr = "REPLACE_ME";

module.exports = async (deployer) => {
  deployer.deploy(LuckyDuckPack);
  deployer.deploy(LDPMinter);
  deployer.deploy(LDPRewarder);

  NFTcontract = await LuckyDuckPack.deployed();
  minterContract = await LDPMinter.deployed();
  rewarderContract = await LDPRewarder.deployed();

  await minterContract.initializeContract(NFTcontract.address, rewarderContract.address, creatorAddr);
  await rewarderContract.setNftAddress(NFTcontract.address);
  //await NFTcontract.initialize(minterContract.address, rewarderContract.address, "base_uri_ips", "base_uri_ar"); // Need link tokens
};