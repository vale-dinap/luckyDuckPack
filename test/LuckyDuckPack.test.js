const { assert } = require("chai");
const { expectRevertCustomError } = require("custom-error-test-helper");
const {
  BN,
  constants,
  expectEvent,
  shouldFail,
  time,
} = require("@openzeppelin/test-helpers");
const {
  LuckyDuckPack,
  LDPMinter,
  LDPRewarder,
  VRFCoordinator,
  Link,
  ERC20TokenA,
  ERC20TokenB,
  initContracts
} = require("./common/contractsInit.js");

const provenance = process.env.PROVENANCE;

contract("Token contract", async (accounts) => {

  var admin, creator, payout, userA, userB, userC;

  before(async function () {
    // Address aliases
    admin = accounts[0];
    creator = accounts[8];
    payout = accounts[9];
    userA = accounts[1];
    userB = accounts[2];
    userC = accounts[3];
  });

  describe("Constants", function () {
    before(async function () { // Using "before" rather than "beforeEach" as these tests are read-only
      // Create contracts
      [
        nftContract,
        minterContract,
        rewarderContract,
        VRFContract,
        linkContract,
        tokenAContract,
        tokenBContract
      ] = await initContracts(creator, payout);
    });

    it("Max supply is 10000", async () => {
      this.maxSupply = await nftContract.MAX_SUPPLY();
      assert.equal(this.maxSupply, 10000, "The max supply is not 10000");
    });

    it("Provenance is set", async () => {
      this.curProvenance = await nftContract.PROVENANCE();
      assert.equal(this.curProvenance, "a10f0c8e99734955d7ff53ac815a1d95aa1daa413e1d6106cb450d584c632b0b", "Provenance not set or incorrect");
    });

    it("Provenance timestamp is a non-zero value", async () => {
      this.curTimestamp = await nftContract.PROVENANCE_TIMESTAMP();
      assert.notEqual(this.curTimestamp, 0, "The provenance timestamp is zero");
    });

    it("The deployer address is stored correctly", async () => {
      this.deployerAddress = await nftContract.DEPLOYER();
      assert.equal(this.deployerAddress, admin, "The deployer address stored in the contract is incorrect");
    });

  });

});
