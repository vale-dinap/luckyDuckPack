const MAINNET_LuckyDuckPack = artifacts.require("LuckyDuckPack");
const MAINNET_LDPMinter = artifacts.require("LDPMinter");
const MAINNET_LDPRewarder = artifacts.require("LDPRewarder");
const TESTNET_LuckyDuckPack = artifacts.require("LuckyDuckPack_TESTNET");
const TESTNET_LDPMinter = artifacts.require("LDPMinter_TESTNET");
const TESTNET_LDPRewarder = artifacts.require("LDPRewarder_TESTNET");

const DO_DEPLOY = process.env.DEPLOY_NFT_CONTRACTS;
const USE_TESTNET_CONTRACTS = process.env.USE_NFT_TESTNET_CONTRACTS;

let LuckyDuckPack, LDPMinter, LDPRewarder;

if (USE_TESTNET_CONTRACTS){
  LuckyDuckPack = TESTNET_LuckyDuckPack;
  LDPMinter = TESTNET_LDPMinter;
  LDPRewarder = TESTNET_LDPRewarder;
}
else {
  LuckyDuckPack = MAINNET_LuckyDuckPack;
  LDPMinter = MAINNET_LDPMinter;
  LDPRewarder = MAINNET_LDPRewarder;
}

// Receiving the creator's cut of creator fees
const creatorAddress = process.env.CREATOR_ADDRESS;
// Payout address for minting
const payoutAddress = process.env.PAYOUT_ADDRESS;

module.exports = async (deployer, network) => {

  if(DO_DEPLOY) {

    if(network !=  "test") {

      await deployer.deploy(LuckyDuckPack);
      let NFTcontract = await LuckyDuckPack.deployed();

      await deployer.deploy(LDPRewarder, NFTcontract.address, creatorAddress);
      let rewarderContract = await LDPRewarder.deployed();

      await deployer.deploy(LDPMinter, NFTcontract.address, rewarderContract.address, payoutAddress);
    }

  }
  
};