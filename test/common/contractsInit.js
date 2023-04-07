const LuckyDuckPack = artifacts.require("LuckyDuckPackTest");
const LDPMinter = artifacts.require("LDPMinter");
const LDPRewarder = artifacts.require("LDPRewarder");
const VRFCoordinator = artifacts.require("VRFCoordinator");
const Link = artifacts.require("Link");
const ERC20TokenA = artifacts.require("CustomERC20A");
const ERC20TokenB = artifacts.require("CustomERC20A");

async function initContracts(creatorAddress, payoutAddress) {
    // Test ERC20 tokens
    tokenAContract = await ERC20TokenA.new();
    tokenBContract = await ERC20TokenB.new();
    // Link Mock
    linkContract = await Link.new();
    // VRF Coordinator Mock
    VRFContract = await VRFCoordinator.new(linkContract.address);
    // LDP Token
    nftContract = await LuckyDuckPack.new(VRFContract.address, linkContract.address);
    // LDP Rewarder
    rewarderContract = await LDPRewarder.new(nftContract.address, creatorAddress);
    // LDP Minter
    minterContract = await LDPMinter.new(nftContract.address, rewarderContract.address, payoutAddress);

    return [
        nftContract,
        minterContract,
        rewarderContract,
        VRFContract,
        linkContract,
        tokenAContract,
        tokenBContract
    ];
  }

module.exports = {
    LuckyDuckPack,
    LDPMinter,
    LDPRewarder,
    VRFCoordinator,
    Link,
    ERC20TokenA,
    ERC20TokenB,
    initContracts
};