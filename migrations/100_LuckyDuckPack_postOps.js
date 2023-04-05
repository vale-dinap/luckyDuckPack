const LuckyDuckPack = artifacts.require("LuckyDuckPack");
const LDPMinter = artifacts.require("LDPMinter");
const LDPRewarder = artifacts.require("LDPRewarder");

const creatorAddr = 0x8A4F18A02d10F95Dbb0a27751547912038eE029C;
const payoutAddr = 0x0158bA51F86aEFa4F2b031Af40ae66aF8541F7b8;
const contractUri = "REPLACE_ME";
const baseUri = "REPLACE_ME";

module.exports = async (deployer) => {

  NFTcontract = await LuckyDuckPack.deployed();
  minterContract = await LDPMinter.deployed();
  rewarderContract = await LDPRewarder.deployed();

  // TRANSFER LINK TOKENS FIRST
  //await NFTcontract.initialize(minterContract.address, rewarderContract.address, contractUri, baseUri); // Need link tokens
  await rewarderContract.setNftAddress(NFTcontract.address);
  await rewarderContract.setCreatorAddress(creatorAddr);
  await minterContract.initializeContract(NFTcontract.address, rewarderContract.address, payoutAddr);
};