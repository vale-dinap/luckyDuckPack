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

contract("Rewarder contract", async (accounts) => {
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
    maxSupply = 50;
  });
  beforeEach(async function () {
    // Create contracts
    [VRFContract, linkContract] = await initChainlinkMocks(admin);
    [nftContract, minterContract, rewarderContract] = await initMainContracts(
      maxSupply,
      creator,
      payout,
      VRFContract.address,
      linkContract.address
    );
    [mockTokenA, mockTokenB] = await initMockTokens(accounts[0]);
    // Set a specific address as minter
    minterAddr = accounts[7];
    this.init_data = [
      minterAddr,
      rewarderContract.address,
      "some_uri",
      "some_uri",
    ];
    // Initialize the contract
    await linkContract.transfer(nftContract.address, revealFee, {
      from: admin,
    });
    await nftContract.initialize(...this.init_data, { from: admin });
    // Mint all
    for (let i = 0; i < accounts.length; ++i) {
      await nftContract.mint_Qgo(accounts[i], maxSupply / accounts.length, {
        from: minterAddr,
      });
    }
  });

  function timeout(ms) {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }

  describe("ETH revenues", function () {
    it("All values are initially zero", async () => {
      this.balanceInitial = await web3.eth.getBalance(rewarderContract.address);
      this.earningsLifetimeInitial = await rewarderContract.methods[
        "collectionEarningsLifetime()"
      ]();
      this.nftRevenuesInitial = await rewarderContract.methods[
        "nftRevenues(uint256)"
      ](0);
      // Assert that all values are initially zero
      assert.equal(
        this.balanceInitial,
        0,
        "Initial contract balance is not zero"
      );
      assert.equal(
        this.earningsLifetimeInitial,
        0,
        "Initial lifetime earnings are not zero"
      );
      assert.equal(
        this.nftRevenuesInitial,
        0,
        "Initial nft revenues are not zero"
      );
    });

    xit("Received ETH is processed correctly", async () => {

    });
  });

  describe.skip("WETH revenues", function () {
    it("All values are initially zero", async () => {
      this.unprocessedWethInitial = await rewarderContract.unprocessedWeth();
      // Assert that all values are initially zero
      assert.equal(
        this.unprocessedWethInitial,
        0,
        "Initial unprocessed WETH is not zero"
      );
    });
  });

  describe("ERC20 revenues", function () {
    it("All values are initially zero", async () => {
      this.earningsLifetimeERC20Initial = await rewarderContract.methods[
        "collectionEarningsLifetime(address)"
      ](mockTokenA.address);
      this.nftRevenuesErc20Initial = await rewarderContract.methods[
        "nftRevenuesErc20(uint256,address)"
      ](0, mockTokenA.address);
      this.erc20recordsUpToDateInitial =
        await rewarderContract.isErc20RevenueRecordsUpToDate(
          mockTokenA.address
        );
      // Assert that all values are initially zero
      assert.equal(
        this.earningsLifetimeERC20Initial,
        0,
        "Initial lifetime earnings ERC20 are not zero"
      );
      assert.equal(
        this.nftRevenuesErc20Initial,
        0,
        "Initial ERC20 nft revenues are not zero"
      );
      assert.isTrue(
        this.erc20recordsUpToDateInitial,
        "Initial ERC20 records are not up to date"
      );
    });
  });
});
