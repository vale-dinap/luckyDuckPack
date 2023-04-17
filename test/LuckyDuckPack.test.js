const { assert } = require("chai");
const { expectRevertCustomError } = require("custom-error-test-helper");
const {
  BN,
  constants,
  expectEvent,
  expectRevert,
  time,
  ether,
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
    return new Promise((resolve) => setTimeout(resolve, ms));
  }

  describe("Constants", function () {
    before(async function () {
      // Using "before" rather than "beforeEach" as these tests are read-only
      // Create contracts
      [VRFContract, linkContract] = await initChainlinkMocks(admin);
      [nftContract, minterContract, rewarderContract] = await initMainContracts(
        10000,
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
        10000,
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
      await linkContract.transfer(nftContract.address, revealFee, {
        from: admin,
      });
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
      await linkContract.transfer(nftContract.address, "1", { from: admin });
      // Assert that passes
      await nftContract.initialize(...init_data, { from: admin });
    });

    it("Initialized data is successfully stored", async () => {
      // Fund the contract with LINK tokens
      await linkContract.transfer(nftContract.address, revealFee, {
        from: admin,
      });
      await nftContract.initialize(...init_data, { from: admin });
      // Check that all data was initialized properly
      this.initMinter = await nftContract.minterContract();
      this.initRewarder = (await nftContract.royaltyInfo(0, 0))[0];
      this.initContractUri = await nftContract.contractURI();
      assert.equal(
        String(this.initMinter),
        String(minterContract.address),
        "Minter address not initialized properly"
      );
      assert.equal(
        String(this.initRewarder),
        String(rewarderContract.address),
        "Rewarder address not initialized properly"
      );
      assert.equal(
        this.initContractUri,
        init_data[2],
        "Contract URI not initialized properly"
      );
    });

    it("Initialize can be called only once (admin keys burned)", async () => {
      // Fund the contract with LINK tokens
      await linkContract.transfer(nftContract.address, revealFee, {
        from: admin,
      });
      await nftContract.initialize(...init_data, { from: admin });
      // Try again: assert that it would fail due to missig role
      await expectRevert(
        nftContract.initialize(...init_data, { from: admin }),
        "Ownable: caller is not the owner"
      );
    });
  });

  describe("Minting", function () {
    beforeEach(async function () {
      maxSupply = 10000;
      // Create contracts
      [VRFContract, linkContract] = await initChainlinkMocks(admin);
      [nftContract, minterContract, rewarderContract] = await initMainContracts(
        maxSupply,
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
      await linkContract.transfer(nftContract.address, revealFee, {
        from: admin,
      });
      await nftContract.initialize(...this.init_data, { from: admin });
    });

    it("Only the minter contract can mint", async () => {
      this.numToMint = 1;
      // Assert that reverts if called from another address
      await expectRevertCustomError(
        LuckyDuckPack,
        nftContract.mint_Qgo(admin, this.numToMint, { from: admin }),
        "CallerIsNoMinter"
      );
      // Assert that works if called by the minter address
      this.supplyBefore = Number(await nftContract.totalSupply());
      await nftContract.mint_Qgo(admin, this.numToMint, { from: minterAddr });
      this.supplyAfter = Number(await nftContract.totalSupply());
      assert.equal(
        this.supplyAfter,
        this.supplyBefore + this.numToMint,
        "Minted supply mismatch"
      );
    });

    // This test can take up to 8 minutes with maxSupply==10000
    xit("Cannot mint over the max supply", async () => {
      this.batchSize = 50;
      this.numBatches = maxSupply / this.batchSize;
      for (let i = 0; i < this.numBatches; ++i) {
        await nftContract.mint_Qgo(admin, this.batchSize, { from: minterAddr });
      }
      // Assert that the max supply has been reached
      this.curSupply = Number(await nftContract.totalSupply());
      assert.equal(this.curSupply, maxSupply, "Max supply not reached");
      // Assert it reverts by attempting to mint another token
      await expectRevertCustomError(
        LuckyDuckPack,
        nftContract.mint_Qgo(admin, 1, { from: minterAddr }),
        "MaxSupplyExceeded"
      );
    });
  });

  describe("Token Enumeration", function () {
    before(async function () {
      maxSupply = 10000;
      // Create contracts
      [VRFContract, linkContract] = await initChainlinkMocks(admin);
      [nftContract, minterContract, rewarderContract] = await initMainContracts(
        maxSupply,
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
      await linkContract.transfer(nftContract.address, revealFee, {
        from: admin,
      });
      await nftContract.initialize(...this.init_data, { from: admin });
    });

    it("Tokens are correctly enumerated for each owner", async () => {
      // Mint a few tokens
      this.amountToMint = 3;
      await nftContract.mint_Qgo(userA, this.amountToMint, {
        from: minterAddr,
      });
      // Gather the enumerated lists
      this.tokensA = [];
      for (let i = 0; i < this.amountToMint; ++i) {
        this.tokensA[i] = await nftContract.tokenOfOwnerByIndex(userA, i);
      }
      // Check that the list is correct
      this.balanceOfA = Number(await nftContract.balanceOf(userA));
      assert.equal(
        this.tokensA.length,
        this.balanceOfA,
        "User A tokens array length doesn't match address balance"
      );
      for (let i = 0; i < this.balanceOfA; ++i) {
        this.tokenOwner = await nftContract.ownerOf(this.tokensA[i]);
        assert.equal(
          this.tokenOwner,
          userA,
          "Owner mismatch (token ID: " + this.tokensA[i].toString() + ")"
        );
      }
      // Transfer one token, check if the list is updated properly
      this.tokenTransfered = this.tokensA[2];
      await nftContract.safeTransferFrom(userA, userB, this.tokenTransfered, {
        from: userA,
      });
      this.newBalanceOfA = Number(await nftContract.balanceOf(userA));
      this.newTokensOfA = [];
      for (let i = 0; i < this.newBalanceOfA; ++i) {
        this.newTokensOfA[i] = await nftContract.tokenOfOwnerByIndex(userA, i);
      }
      assert.equal(
        this.newTokensOfA.length,
        this.balanceOfA - 1,
        "User A tokens list length incorrect after token transfer"
      );
      assert.notIncludeMembers(
        this.newTokensOfA,
        [this.tokenTransfered],
        "Transferred token still in the previous owner's enumerated list"
      );
    });
  });

  describe("Reveal", function () {
    beforeEach(async function () {
      maxSupply = 50;
      // Create contracts
      [VRFContract, linkContract] = await initChainlinkMocks(admin);
      [nftContract, minterContract, rewarderContract] = await initMainContracts(
        maxSupply,
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
      await linkContract.transfer(nftContract.address, revealFee, {
        from: admin,
      });
      await nftContract.initialize(...this.init_data, { from: admin });
    });

    it("Cannot reveal before the collection is fully minted", async () => {
      // Mint max supply minus 1
      await nftContract.mint_Qgo(userA, maxSupply - 1, { from: minterAddr });
      // Assert that reveal reverts
      await expectRevert(nftContract.reveal(), "Minting still in progress");
    });

    it("Can reveal when the collection is fully minted", async () => {
      // Mock randomnes
      this.randomness = 35139;
      // Mint max supply
      await nftContract.mint_Qgo(userA, maxSupply, { from: minterAddr });
      // Assert that the reveal hasn't been performed up to this point
      await expectRevert(nftContract.revealedId(0), "Collection not revealed");
      // Assert that reveal passes
      this.totalSupply = await nftContract.totalSupply();
      assert.equal(this.totalSupply, maxSupply, "Collection not fully minted");
      this.truffleReceipt = await nftContract.reveal();
      this.requestId = String(this.truffleReceipt.logs[0].args[0]);
      await expectEvent(this.truffleReceipt, "RevealRequested");
      // Mock chainlink VRF callback
      await VRFContract.callBackWithRandomness(
        this.requestId,
        this.randomness,
        nftContract.address
      );
      // Assert that the revealed id is correct
      this.testId = 5;
      this.revealedId = await nftContract.revealedId(this.testId);
      assert.equal(
        this.revealedId,
        (this.testId + this.randomness) % maxSupply,
        "Revealed Id mismatch"
      );
      // Test with the last token of the collection
      this.testId2 = maxSupply - 1;
      this.revealedId2 = await nftContract.revealedId(this.testId2);
      assert.equal(
        this.revealedId2,
        (this.testId2 + this.randomness) % maxSupply,
        "Revealed Id mismatch"
      );
    });

    it("Reveal cannot be called more than once", async () => {
      // Mock randomnes
      this.randomness = 9;
      // Mint max supply
      await nftContract.mint_Qgo(userA, maxSupply, { from: minterAddr });
      // Assert that the reveal hasn't been performed up to this point
      await expectRevert(nftContract.revealedId(0), "Collection not revealed");
      // Call the reveal function the first time
      await nftContract.reveal();
      // Call the second time, assert that fails
      await expectRevert(nftContract.reveal(), "Reveal already requested");
    });
  });

  describe("Token URI", function () {
    beforeEach(async function () {
      maxSupply = 25;
      contractUri = "contractUri_string";
      baseUriIPFS = "baseUri_IPFS_string";
      baseUriArweave = "ARWEAVE_MANIFEST/";
      mockRandomness = 9;
      // Create contracts
      [VRFContract, linkContract] = await initChainlinkMocks(admin);
      [nftContract, minterContract, rewarderContract] = await initMainContracts(
        maxSupply,
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
        contractUri,
        baseUriIPFS,
      ];
      // Initialize the contract
      await linkContract.transfer(nftContract.address, revealFee, {
        from: admin,
      });
      await nftContract.initialize(...this.init_data, { from: admin });
      // Mint all
      await nftContract.mint_Qgo(userA, maxSupply, { from: minterAddr });
    });

    it("Before reveal, the unrevealed URI is returned for all tokens", async () => {
      for (let i = 0; i < maxSupply; ++i) {
        this.tokenUri = await nftContract.tokenURI(i);
        assert.equal(
          this.tokenUri,
          "unrevealedURI_string",
          "URI of token ID " + String(i) + " is not the Unrevealed URI"
        );
      }
    });

    it("After reveal, the IPFS URI is returned for all tokens", async () => {
      // Reveal the collection
      this.truffleReceipt = await nftContract.reveal();
      this.requestId = String(this.truffleReceipt.logs[0].args[0]);
      // Mock chainlink VRF callback
      await VRFContract.callBackWithRandomness(
        this.requestId,
        mockRandomness,
        nftContract.address
      );
      // Actual test
      for (let i = 0; i < maxSupply; ++i) {
        this.revealedId = await nftContract.revealedId(i);
        this.tokenUri = await nftContract.tokenURI(i);
        assert.equal(
          this.tokenUri,
          baseUriIPFS + String(this.revealedId),
          "URI of token ID " + String(i) + " is not the Revealed IPFS URI"
        );
      }
    });

    it("Only deployer address can set the Arweave baseURI (but cannot override it)", async () => {
      this.deployerAddress = await nftContract.DEPLOYER();
      await expectRevert(
        nftContract.setArweaveBaseUri(baseUriArweave, { from: userA }),
        "Permission denied."
      );
      await nftContract.setArweaveBaseUri(baseUriArweave, {
        from: this.deployerAddress,
      });
      await expectRevert(
        nftContract.setArweaveBaseUri(baseUriArweave, {
          from: this.deployerAddress,
        }),
        "Override denied."
      );
    });

    it("Deployer address can toggle between IPFS and Arweave baseURI", async () => {
      this.deployerAddress = await nftContract.DEPLOYER();
      this.testToken = 5;
      await nftContract.setArweaveBaseUri(baseUriArweave, {
        from: this.deployerAddress,
      });
      // Reveal the collection
      this.truffleReceipt = await nftContract.reveal();
      this.requestId = String(this.truffleReceipt.logs[0].args[0]);
      // Mock chainlink VRF callback
      await VRFContract.callBackWithRandomness(
        this.requestId,
        mockRandomness,
        nftContract.address
      );
      this.revealedId = await nftContract.revealedId(this.testToken);
      // Assert that nobody else can toggle
      await expectRevert(
        nftContract.toggleArweaveUri({ from: userA }),
        "Permission denied."
      );
      // Assert that the toggle works
      await nftContract.toggleArweaveUri({ from: this.deployerAddress });
      this.tokenUri = await nftContract.tokenURI(this.testToken);
      assert.equal(
        this.tokenUri,
        baseUriArweave + String(this.revealedId),
        "Not using Arweave after toggle"
      );
      // Assert the a second toggle switches back to IPFS
      await nftContract.toggleArweaveUri({ from: this.deployerAddress });
      this.tokenUri = await nftContract.tokenURI(this.testToken);
      assert.equal(
        this.tokenUri,
        baseUriIPFS + String(this.revealedId),
        "Not using IPFS after the second toggle"
      );
    });
  });
});