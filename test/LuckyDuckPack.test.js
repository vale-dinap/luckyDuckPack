const { assert } = require("chai");
const { expectRevertCustomError } = require("custom-error-test-helper");
const {
  BN,
  constants,
  expectEvent,
  expectRevert,
  time,
  ether
} = require("@openzeppelin/test-helpers");
const {
  LuckyDuckPack,
  LDPMinter,
  LDPRewarder,
  VRFCoordinator,
  Link,
  ERC20TokenA,
  ERC20TokenB,
  initMainContracts,
  initChainlinkMocks,
  initMockTokens,
} = require("./common/contractsInit.js");

const provenance = process.env.PROVENANCE;

contract("Token contract", async (accounts) => {
  var admin, creator, payout, userA, userB, userC;
  var revealFee;

  before(async function () {
    // Address aliases
    admin = accounts[0];
    creator = accounts[8];
    payout = accounts[9];
    userA = accounts[1];
    userB = accounts[2];
    userC = accounts[3];
    // Chainlink reveal fee
    revealFee = ether("2");
  });

  function timeout(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
  }

  describe("Constants", function () {
    before(async function () {
      // Using "before" rather than "beforeEach" as these tests are read-only
      // Create contracts
      [VRFContract, linkContract] = await initChainlinkMocks(admin);
      [nftContract, minterContract, rewarderContract] = await initMainContracts(
        creator,
        payout,
        VRFContract.address,
        linkContract.address
      );
    });

    it("Max supply is 10000", async () => {
      this.maxSupply = await nftContract.MAX_SUPPLY();
      assert.equal(this.maxSupply, 10000, "The max supply is not 10000");
    });

    it("Provenance is set", async () => {
      this.curProvenance = await nftContract.PROVENANCE();
      assert.equal(
        this.curProvenance,
        "a10f0c8e99734955d7ff53ac815a1d95aa1daa413e1d6106cb450d584c632b0b",
        "Provenance not set or incorrect"
      );
    });

    it("Provenance timestamp is a non-zero value", async () => {
      this.curTimestamp = await nftContract.PROVENANCE_TIMESTAMP();
      assert.notEqual(this.curTimestamp, 0, "The provenance timestamp is zero");
    });

    it("The deployer address is stored correctly", async () => {
      this.deployerAddress = await nftContract.DEPLOYER();
      assert.equal(
        this.deployerAddress,
        admin,
        "The deployer address stored in the contract is incorrect"
      );
    });
  });

  describe("Initialization", function () {

    beforeEach(async function () {
      // Create contracts
      [VRFContract, linkContract] = await initChainlinkMocks(admin);
      [nftContract, minterContract, rewarderContract] = await initMainContracts(
        creator,
        payout,
        VRFContract.address,
        linkContract.address
      );
      // Create initialization data
      init_data = [
        minterContract.address,
        rewarderContract.address,
        "contractUri_string",
        "baseUri_IPFS_string",
      ];
    });

    it("Only Admin can initilize", async () => {
      // Fund the contract with LINK tokens
      await linkContract.transfer(
        nftContract.address,
        revealFee,
        { from: admin }
      );
      // Check if reverts if called by non-admin
      await expectRevert(
        nftContract.initialize(...init_data, { from: userA }),
        "Ownable: caller is not the owner"
      );
      // Attempt to initialize from admin
      await nftContract.initialize(...init_data, { from: admin });
    });

    it("Can initialize only if the contract has enough LINK for reveal", async () => {
      // Assert that the initial balance is zero
      this.linkBal = Number(await linkContract.balanceOf(nftContract.address));
      assert.equal(this.linkBal, 0, "Initial LINK balance is not zero");
      // Check if reverts with no LINK
      await expectRevert(
        nftContract.initialize(...init_data, { from: admin }),
        "Not enough LINK for reveal"
      );
      // Fund the contract with nearly enough LINK (but not enough)
      await linkContract.transfer(
        nftContract.address,
        revealFee.sub(BN(1)), // Subtract 1 from the value
        { from: admin }
      );
      // Assert that reverts again
      await expectRevert(
        nftContract.initialize(...init_data, { from: admin }),
        "Not enough LINK for reveal"
      );
      // Fund the missing LINK
      await linkContract.transfer(
        nftContract.address,
        "1",
        { from: admin }
      );
      // Assert that passes
      await nftContract.initialize(...init_data, { from: admin });
    });

    it("Initialized data is successfully stored", async () => {
      // Fund the contract with LINK tokens
      await linkContract.transfer(
        nftContract.address,
        revealFee,
        { from: admin }
      );
      await nftContract.initialize(...init_data, {from: admin});
      // Check that all data was initialized properly
      this.initMinter = await nftContract.minterContract();
      this.initRewarder = (await nftContract.royaltyInfo(0,0))[0];
      this.initContractUri = await nftContract.contractURI();
      assert.equal(String(this.initMinter), String(minterContract.address), "Minter address not initialized properly");
      assert.equal(String(this.initRewarder), String(rewarderContract.address), "Rewarder address not initialized properly");
      assert.equal(this.initContractUri, init_data[2], "Contract URI not initialized properly");
    });

    it("Initialize can be called only once (admin keys burned)", async () => {
      // Fund the contract with LINK tokens
      await linkContract.transfer(
        nftContract.address,
        revealFee,
        { from: admin }
      );
      await nftContract.initialize(...init_data, {from: admin});
      // Try again: assert that it would fail due to missig role
      await expectRevert(
        nftContract.initialize(...init_data, { from: admin }),
        "Ownable: caller is not the owner"
      );
    });

  });

  describe("Minting", function () {

    beforeEach(async function () {
      // Create contracts
      [VRFContract, linkContract] = await initChainlinkMocks(admin);
      [nftContract, minterContract, rewarderContract] = await initMainContracts(
        creator,
        payout,
        VRFContract.address,
        linkContract.address
      );
      // Set a specific address as minter
      minterAddr = accounts[7];
      this.init_data = [
        minterAddr,
        rewarderContract.address,
        "contractUri_string",
        "baseUri_IPFS_string",
      ];
      // Initialize the contract
      await linkContract.transfer(
        nftContract.address,
        revealFee,
        { from: admin }
      );
      await nftContract.initialize(...this.init_data, {from: admin});
    });

    it("Only the minter contract can mint", async () => {
      this.numToMint = 1;
      // Assert that reverts if called from another address
      await expectRevertCustomError(
        LuckyDuckPack,
        nftContract.mint_Qgo(admin, this.numToMint, {from: admin}),
        "CallerIsNoMinter"
      );
      // Assert that works if called by the minter address
      this.supplyBefore = Number(await nftContract.totalSupply());
      await nftContract.mint_Qgo(admin, this.numToMint, {from: minterAddr});
      this.supplyAfter = Number(await nftContract.totalSupply());
      assert.equal(this.supplyAfter, this.supplyBefore+this.numToMint, "Minted supply mismatch");
    });

    it.only("Cannot mint over the max supply", async () => {
      this.maxSupply = 10000;
      this.batchSize = 50;
      this.numBatches = this.maxSupply/this.batchSize;
      for(let i=0; i<this.numBatches; ++i){
        await nftContract.mint_Qgo(admin, this.batchSize, {from: minterAddr});
        await timeout(50);
      }
      // Assert that the max supply has been reached
      this.curSupply = Number(await nftContract.totalSupply());
      assert.equal(this.curSupply, this.maxSupply, "Max supply not reached");
      // Assert it reverts by attempting to mint another token
      await expectRevertCustomError(
        LuckyDuckPack,
        nftContract.mint_Qgo(admin, 1, {from: minterAddr}),
        "MaxSupplyExceeded"
      );
    });

  });

});
