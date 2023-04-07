const LuckyDuckPack = artifacts.require("LuckyDuckPack");
const LDPMinter = artifacts.require("LDPMinter");
const LDPRewarder = artifacts.require("LDPRewarder");

// Receiving the creator's cut of creator fees
const creatorAddress = process.env.CREATOR_ADDRESS;
// Payout address for minting
const payoutAddress = process.env.PAYOUT_ADDRESS;

module.exports = async (deployer, network) => {

  if(network !=  "test"){

    await deployer.deploy(LuckyDuckPack);
    let NFTcontract = await LuckyDuckPack.deployed();

    await deployer.deploy(LDPRewarder, NFTcontract.address, creatorAddress);
    let rewarderContract = await LDPRewarder.deployed();

    await deployer.deploy(LDPMinter, NFTcontract.address, rewarderContract.address, payoutAddress);
  }
  
};