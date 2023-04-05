const tokenA = artifacts.require("CustomERC20A");
const tokenB = artifacts.require("CustomERC20B");
const link = artifacts.require("Link");
const VRF = artifacts.require("VRFCoordinator");

module.exports = async (deployer, network) => {

  if(network == "test"){

    deployer.deploy(tokenA);
    deployer.deploy(tokenB);
    deployer.deploy(link);

    linkToken = await link.deployed();

    deployer.deploy(VRF, linkToken.address);
    
  }
  
};