const tokenA = artifacts.require("CustomERC20A");
const tokenB = artifacts.require("CustomERC20B");
const Link = artifacts.require("Link");
const VRFCoordinator = artifacts.require("VRFCoordinator");
const LuckyDuckPack = artifacts.require("LuckyDuckPackTest");
const LDPMinter = artifacts.require("LDPMinter");
const LDPRewarder = artifacts.require("LDPRewarder");

// Receiving the creator's cut of creator fees
const creatorAddress = process.env.CREATOR_ADDRESS;
// Payout address for minting
const payoutAddress = process.env.PAYOUT_ADDRESS;

const enableMigration = false;

module.exports = async (deployer, network) => {

  if(network == "test"){

    if (enableMigration == true){
      // Test ERC20 tokens
      await deployer.deploy(tokenA);
      await deployer.deploy(tokenB);
      // Link Mock
      await deployer.deploy(Link);

      // VRF Coordinator Mock
      let linkToken = await Link.deployed();
      await deployer.deploy(VRFCoordinator, linkToken.address);

      // LDP Token
      let vrf = await VRFCoordinator.deployed();
      await deployer.deploy(LuckyDuckPack, vrf.address, linkToken.address);

      // LDP Rewarder
      let NFTcontract = await LuckyDuckPack.deployed();
      await deployer.deploy(LDPRewarder, NFTcontract.address, creatorAddress);

      // LDP Minter
      let rewarderContract = await LDPRewarder.deployed();
      await deployer.deploy(LDPMinter, NFTcontract.address, rewarderContract.address, payoutAddress);
    }
    else{
      console.log("Migration of test contracts disabled, check the migration script.");
    }
    
  }
  
};