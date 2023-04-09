const LuckyDuckPack = artifacts.require("LuckyDuckPackTest");
const LDPMinter = artifacts.require("LDPMinter");
const LDPRewarder = artifacts.require("LDPRewarder");
const VRFCoordinator = artifacts.require("VRFCoordinator");
const Link = artifacts.require("Link");
const ERC20TokenA = artifacts.require("CustomERC20A");
const ERC20TokenB = artifacts.require("CustomERC20A");

async function initMainContracts(maxSupply, creatorAddress, payoutAddress, VRFContractAddress, linkContractAddress) {
    // LDP Token
    nftContract = await LuckyDuckPack.new(VRFContractAddress, linkContractAddress, maxSupply);
    // LDP Rewarder
    rewarderContract = await LDPRewarder.new(nftContract.address, creatorAddress);
    // LDP Minter
    minterContract = await LDPMinter.new(nftContract.address, rewarderContract.address, payoutAddress);

    return [
        nftContract,
        minterContract,
        rewarderContract
    ];
}

async function initChainlinkMocks(linkHolder) {
    // Link Mock
    linkContract = await Link.new(linkHolder);
    // VRF Coordinator Mock
    VRFContract = await VRFCoordinator.new(linkContract.address);

    return [
        VRFContract,
        linkContract
    ];
}

async function initMockTokens(supplyHolder) {
    // Test ERC20 tokens
    tokenAContract = await ERC20TokenA.new(supplyHolder);
    tokenBContract = await ERC20TokenB.new(supplyHolder);
    
    return [
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
    initMainContracts,
    initChainlinkMocks,
    initMockTokens
};