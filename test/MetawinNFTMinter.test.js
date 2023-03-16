const MetaWinnersDAC = artifacts.require("MetaWinnersDAC");
const MetaWinnersDACMinter = artifacts.require("MetaWinnersDACMinter");
const CompetitionDummy = artifacts.require("CompetitionDummy");
const { assert } = require('chai');
const truffleAssert = require('truffle-assertions');
const { BN, constants, expectEvent, shouldFail, time } = require('@openzeppelin/test-helpers');
const ether = require('@openzeppelin/test-helpers/src/ether');
//const toBytes = web3.utils.asciiToHex;
const pad32 = (input) => {return(web3.utils.padLeft(input, 32));}
const merkleTreeData = require("./data/merkleTreeData.json");
const { duration } = require('@openzeppelin/test-helpers/src/time');

contract("MetawinnersDACMinter: minting phases", async accounts => {
    // Setting up the test environment...

    // Contracts
    var NFTcontract, minterContract, competitionContract;
    // Addresses
    var owner;
    // Time
    var earlymintPhaseDelay, mintPhaseDelay, endPhaseDelay;

    before(async function() {
      // Contracts
      NFTcontract = await MetaWinnersDAC.deployed();
      minterContract = await MetaWinnersDACMinter.deployed();
      competitionContract = await CompetitionDummy.deployed();
      await competitionContract.setMinter(minterContract.address);
      // Addresses
      owner = await NFTcontract.getRoleMember("0x0000000000000000000000000000000000000000000000000000000000000000", 0);
      // Time
      earlymintPhaseDelay = time.duration.minutes(10).toNumber(); // 10 minutes
      mintPhaseDelay = time.duration.minutes(15).toNumber(); // 15 minutes
      endPhaseDelay = time.duration.minutes(20).toNumber(); // 20 minutes
    });

    // After each test: increase time by 10 seconds and mine a block
    afterEach(async function() {
      await time.increase(10);
      //await time.advanceBlock();
    });

    it("should allow owner to set the minting phases", async () => {
      this.currentTime = await time.latest();
      this.earlymintPhaseStartTime = this.currentTime.toNumber()+earlymintPhaseDelay;
      await minterContract.phase_setTimes(
        this.earlymintPhaseStartTime,
        mintPhaseDelay,
        endPhaseDelay,
        {from: owner});
      this.phasesSet = await minterContract.phase_startTimes();
      this.curPhase = await minterContract.phase_nameOfCurrent();
      assert.equal(this.curPhase, "Setup", "The current phase is not 'Setup'...");
      assert.equal(this.phasesSet[1].toNumber(), this.earlymintPhaseStartTime, "Early mint phase start time not set correctly");
      assert.equal(this.phasesSet[2].toNumber(), this.earlymintPhaseStartTime+mintPhaseDelay, "Mint phase start time not set correctly");
      assert.equal(this.phasesSet[3].toNumber(), this.earlymintPhaseStartTime+mintPhaseDelay+endPhaseDelay, "End phase start time not set correctly");
      //console.log(this.phasesSet.toString());
    });

    it("phase progression works properly; owner is allowed to reset only in end phase", async () => {
      this.phasesSet = await minterContract.phase_startTimes();
      // During setup phase
      this.currentPhase = await minterContract.phase_nameOfCurrent();
      assert.equal(this.currentPhase, "Setup", "Checked phase is not Setup, can't perform this test");
      await truffleAssert.reverts(
        minterContract.phase_reset({from: owner})
      );
      // During early-minting phase
      this.nextPhaseStart = this.phasesSet[1].toNumber();
      await time.increaseTo(this.nextPhaseStart+1);
      this.currentPhase = await minterContract.phase_nameOfCurrent();
      assert.equal(this.currentPhase, "Early-Minting", "Checked phase is not Early-Minting, can't perform this test");
      await truffleAssert.reverts(
        minterContract.phase_reset({from: owner})
      );
      // During minting phase
      this.nextPhaseStart = this.phasesSet[2].toNumber();
      await time.increaseTo(this.nextPhaseStart+1);
      this.currentPhase = await minterContract.phase_nameOfCurrent();
      assert.equal(this.currentPhase, "Minting", "Checked phase is not Minting, can't perform this test");
      await truffleAssert.reverts(
        minterContract.phase_reset({from: owner})
      );
      // During end phase
      this.nextPhaseStart = this.phasesSet[3].toNumber();
      await time.increaseTo(this.nextPhaseStart+1);
      this.currentPhase = await minterContract.phase_nameOfCurrent();
      assert.equal(this.currentPhase, "End", "Checked phase is not End, can't perform this test");
      await truffleAssert.passes(
        minterContract.phase_reset({from: owner})
      );
      // Now check if reset is actually performed
      this.phasesSet = await minterContract.phase_startTimes();
      //console.log(""+this.phasesSet);
      assert.equal(this.phasesSet[0].toNumber(), 0, "Reset not actually performed");
      assert.equal(this.phasesSet[1].toNumber(), 0, "Reset not actually performed");
      assert.equal(this.phasesSet[2].toNumber(), 0, "Reset not actually performed");
      assert.equal(this.phasesSet[3].toNumber(), 0, "Reset not actually performed");
      // Finally set phases again to perform next tests
      this.currentTime = await time.latest();
      this.earlymintPhaseStartTime = this.currentTime.toNumber()+earlymintPhaseDelay;
      await minterContract.phase_setTimes(
        this.earlymintPhaseStartTime,
        mintPhaseDelay,
        endPhaseDelay,
        {from: owner});
    })

    it("phase_timeToNext returns the right value", async () => {
      this.phasesSet = await minterContract.phase_startTimes();
      this.currentTime = await time.latest();
      this.curPhase = await minterContract.phase_indexOfCurrent();
      this.computedTimeToNext = this.phasesSet[this.curPhase.toNumber()+1].toNumber()-this.currentTime.toNumber();
      this.queriedTimeToNext = await minterContract.phase_timeToNext();
      assert.equal(this.computedTimeToNext, this.queriedTimeToNext, "Returned value incorrect");
    })

    it("phases can be properly extended", async () => {
      this.extendBy = 1000;
      this.curPhase = await minterContract.phase_indexOfCurrent();
      this.phasesSet = await minterContract.phase_startTimes();
      await minterContract.phase_extendCurrent(this.extendBy, {from: owner});
      this.phasesSetAfter = await minterContract.phase_startTimes();
      for(let i = this.curPhase.toNumber()+1; i<this.phasesSetAfter.length; ++i){
        assert.equal(this.phasesSet[i].toNumber()+this.extendBy, this.phasesSetAfter[i].toNumber(), "Phase times not updated properly");
      }
    })

    it("admin can end a phase earlier", async () => {
      this.currentTime = await time.latest();
      this.curPhase = await minterContract.phase_indexOfCurrent();
      this.phasesSet = await minterContract.phase_startTimes();
      this.computedTimeToNext = this.phasesSet[this.curPhase.toNumber()+1].toNumber()-this.currentTime.toNumber();
      await minterContract.phase_endCurrent({from: owner});
      this.phasesSetAfter = await minterContract.phase_startTimes();
      for(let i = this.curPhase.toNumber()+1; i<this.phasesSetAfter.length; ++i){
        assert.equal(this.phasesSet[i].toNumber()-this.computedTimeToNext, this.phasesSetAfter[i].toNumber(), "Phase times not updated properly");
      }
      await time.increase(1);
      this.curPhaseAfter = await minterContract.phase_indexOfCurrent();
      assert.equal(this.curPhase.toNumber()+1, this.curPhaseAfter.toNumber(), "Phase didn't end");
    })

})

//////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////

contract("MetawinnersDACMinter: Dutch auction", async accounts => {
  // Setting up the test environment...

  // Contracts
  var NFTcontract, minterContract, competitionContract;
  // Addresses
  var owner;
  // Dutch Auction
  var duration, startPrice, endPrice;

  before(async function() {
    // Contracts
    NFTcontract = await MetaWinnersDAC.deployed();
    minterContract = await MetaWinnersDACMinter.deployed();
    competitionContract = await CompetitionDummy.deployed();
    await competitionContract.setMinter(minterContract.address);
    // Addresses
    owner = await NFTcontract.getRoleMember("0x0000000000000000000000000000000000000000000000000000000000000000", 0);
    // Dutch Auction
    duration = time.duration.days(7).toNumber(); // 7 days
    startPrice = ether("5");
    endPrice = ether("0.05");
    //console.log(""+startPrice);
  });

  it("admin can set up the Dutch auction", async () => {
    this.currentTime = await time.latest();
    this.startTime = this.currentTime.toNumber() + 1;
    this.endTime = this.startTime + duration;
    this.timeStep = time.duration.days(1).toNumber(); // 1 day
    this.rulesSet = [startPrice, endPrice, this.startTime, this.endTime, this.timeStep];
    //console.log(""+this.rulesSet);
    await minterContract.dutchAuction_set(...this.rulesSet, {from:owner});
    // Query rules to ensure they have been set
    this.rules = await minterContract.dutchAuction_getSettings();
    //console.log(""+this.rules);
    assert.equal(this.startTime, this.rules[0], "Start time incorrect");
    assert.equal(this.endTime, this.rules[1], "End time incorrect");
    assert.equal(startPrice, this.rules[2], "Start price incorrect");
    assert.equal(endPrice, this.rules[3], "End price incorrect");
    assert.equal(this.timeStep, this.rules[4], "Time step incorrect");
  });

  it("price earlier than start time is startPrice", async () => {
    this.currentPrice = await minterContract.price_current();
    assert.equal(startPrice.toString(), this.currentPrice.toString(), "Unexpected value");
  });

  it("price later than end time is endPrice", async () => {
    this.rules = await minterContract.dutchAuction_getSettings();
    this.endTime = this.rules[1];
    await time.increaseTo(this.endTime+10);
    this.currentPrice = await minterContract.price_current();
    assert.equal(endPrice.toString(), this.currentPrice.toString(), "Unexpected value");
  });

  it("timeStep works as intended", async () => {
    this.currentTime = await time.latest();
    this.startTime = this.currentTime.toNumber() + 1;
    this.endTime = this.startTime + duration;
    this.timeStep = time.duration.days(1).toNumber(); // 1 day
    this.rulesSet = [startPrice, endPrice, this.startTime, this.endTime, this.timeStep];
    await minterContract.dutchAuction_set(...this.rulesSet, {from:owner});
    await time.increase(10);
    this.priceAtStepOne = await minterContract.price_current();
    await time.increase(10);
    this.priceAtStepOneB = await minterContract.price_current();
    await time.increase(this.timeStep);
    this.priceAtStepTwo = await minterContract.price_current();
    await time.increase(10);
    this.priceAtStepTwoB = await minterContract.price_current();
    await time.increase(this.timeStep);
    this.priceAtStepThree = await minterContract.price_current();
    //console.log(""+this.priceAtStepOne+", "+this.priceAtStepOneB+", "+this.priceAtStepTwo+", "+this.priceAtStepTwoB+", "+this.priceAtStepThree);
    assert.equal(this.priceAtStepOne.toString(), this.priceAtStepOneB.toString(), "Price not consistent across the first step");
    assert.equal(this.priceAtStepTwo.toString(), this.priceAtStepTwoB.toString(), "Price not consistent across the second step");
    assert.isAbove(Number(this.priceAtStepOne.toString()), Number(this.priceAtStepTwo.toString()), "Price not decreased after going from step 1 to step 2");
    assert.isAbove(Number(this.priceAtStepTwo.toString()), Number(this.priceAtStepThree.toString()), "Price not decreased after going from step 2 to step 3");
  });

  it("a much smaller timeStep would work as intended", async () => {
    this.currentTime = await time.latest();
    this.startTime = this.currentTime.toNumber() + 1;
    this.endTime = this.startTime + duration;
    this.timeStep = time.duration.hours(1).toNumber(); // 1 hour
    this.rulesSet = [startPrice, endPrice, this.startTime, this.endTime, this.timeStep];
    await minterContract.dutchAuction_set(...this.rulesSet, {from:owner});
    await time.increase(10);
    this.priceAtStepOne = await minterContract.price_current();
    await time.increase(10);
    this.priceAtStepOneB = await minterContract.price_current();
    await time.increase(this.timeStep);
    this.priceAtStepTwo = await minterContract.price_current();
    await time.increase(10);
    this.priceAtStepTwoB = await minterContract.price_current();
    await time.increase(this.timeStep);
    this.priceAtStepThree = await minterContract.price_current();
    //console.log(""+this.priceAtStepOne+", "+this.priceAtStepOneB+", "+this.priceAtStepTwo+", "+this.priceAtStepTwoB+", "+this.priceAtStepThree);
    assert.equal(this.priceAtStepOne.toString(), this.priceAtStepOneB.toString(), "Price not consistent across the first step");
    assert.equal(this.priceAtStepTwo.toString(), this.priceAtStepTwoB.toString(), "Price not consistent across the second step");
    assert.isAbove(Number(this.priceAtStepOne.toString()), Number(this.priceAtStepTwo.toString()), "Price not decreased after going from step 1 to step 2");
    assert.isAbove(Number(this.priceAtStepTwo.toString()), Number(this.priceAtStepThree.toString()), "Price not decreased after going from step 2 to step 3");
  });

})

//////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////

contract("MetaWinnersDACMinter: main", async accounts => {

    // Setting up the test environment...

    // Contracts
    var NFTcontract, minterContract, competitionContract;
    // Addresses
    var owner, payoutAddress, teamTokensReceiver;
    // Merkle tree
    var anyMerkleProof;
    // Time
    var earlymintPhaseDelay, mintPhaseDelay, endPhaseDelay;

    before(async function() {
        // Contracts
        NFTcontract = await MetaWinnersDAC.deployed();
        minterContract = await MetaWinnersDACMinter.deployed();
        competitionContract = await CompetitionDummy.deployed();
        await competitionContract.setMinter(minterContract.address);
        // Addresses
        owner = await NFTcontract.getRoleMember("0x0000000000000000000000000000000000000000000000000000000000000000", 0);
        payoutAddress = "0x1544d2de126e3a4b194cfad2a5c6966b3460ebe3"; // Metawin.eth
        teamTokensReceiver = accounts[8];
        // Merkle tree
        anyMerkleProof = [pad32("0x0bad0010"), pad32("0x60a70020"), pad32("0xbeef0030")];
        // Time
        earlymintPhaseDelay = time.duration.minutes(10).toNumber(); // 10 minutes
        mintPhaseDelay = time.duration.minutes(15).toNumber(); // 15 minutes
        endPhaseDelay = time.duration.minutes(20).toNumber(); // 20 minutes
        /*
        for(let i=0; i<merkleTreeData.whitelist.accounts.length; ++i){
          let address = merkleTreeData.whitelist.accounts[i].address;
          accounts.push(address);
          await web3.eth.sendTransaction({to:address, from:accounts[0], value: web3.utils.toWei('0.05', 'ether')});
        }
        for(let i=0; i<merkleTreeData.freemint.accounts.length; ++i){
          let address = merkleTreeData.freemint.accounts[i].address;
          if(!accounts.includes(address)){
            accounts.push(address);
            await web3.eth.sendTransaction({to:address, from:accounts[0], value: web3.utils.toWei('0.05', 'ether')});
          }
        }*/
    });

    // After each test: increase time by 10 seconds and mine a block
    afterEach(async function() {
      await time.increase(10);
      //await time.advanceBlock();
    });

    // And here we go...

    // PRELIMINARY CHECKS

    it("initially assign minter role to the owner", async () => {
        await NFTcontract.setMinter(owner, {from: owner});
        this.assignedMinter = await NFTcontract.minter();
        assert.equal(this.assignedMinter, owner, "the owner doesn't have the minter role");
    })

    it("should initially revert minting calls", async () => {
      await truffleAssert.reverts(
        minterContract.mintBuy(1, { from: accounts[1] })
      );
      await truffleAssert.reverts(
        minterContract.mintFree(1, 1, anyMerkleProof, { from: accounts[1] })
      );
    })

    // SETUP PHASE

    it("should allow owner to set the earlymint merkleRoot", async () => {
      await truffleAssert.passes(
        minterContract.earlymint_setMerkleRoot(merkleTreeData.freemint.merkleRoot, {from: owner})
      );
    });

    it("should prevent anyone else to set the earlymint merkleRoot", async () => {
      await truffleAssert.reverts(
        minterContract.earlymint_setMerkleRoot(merkleTreeData.freemint.merkleRoot, {from: accounts[1]})
      );
    });

    it("should allow owner to link Minter and ERC721 contracts", async () => {
      const ERC721_addr = NFTcontract.address;
      const minter_addr = minterContract.address;
      await truffleAssert.passes(
        NFTcontract.setMinter(minter_addr, {from: owner})
      );
      await truffleAssert.passes(
        minterContract.setNFTaddress(ERC721_addr, {from: owner})
      );
    });

    it("should allow owner to amend the mints limit", async () => {
      const maxMints_cur = await minterContract.mintingCap();
      const newValue = 200;
      assert.notEqual(maxMints_cur, newValue, "Values are already the same, can't perform the test");
      await truffleAssert.passes(
        minterContract.setMintingCap(newValue, {from: owner})
      );
      const maxMints_new = await minterContract.mintingCap();
      assert.equal(maxMints_new, newValue, "Max mints hasn't been updated");
    });

    it("should allow owner to reserve tokens to the team", async () => {
      let totalSupplyBefore = await NFTcontract.totalSupply();
      let numTokensToReserve = 15;
      await truffleAssert.passes(
        minterContract.mintTeamReserve(numTokensToReserve, teamTokensReceiver, {from: owner})
      );
      let totalSupplyAfter = await NFTcontract.totalSupply();
      assert.equal(totalSupplyAfter.toNumber(), totalSupplyBefore.toNumber()+numTokensToReserve, "New total supply different than expected");
    });

    it("should allow owner to link Minter and Competition contracts", async () => {
      const competition_addr = competitionContract.address;
      await truffleAssert.passes(
        minterContract.reward_setCompetitionContractAddress(competition_addr, {from: owner})
      );
    });

    it("should allow owner to set the default competition ID", async () => {
      this.newCompetitionId = 42;
      await truffleAssert.passes(
        minterContract.reward_setDefaultCompetition(this.newCompetitionId, {from: owner})
      );
    });

    it("should allow owner to set the minting phases", async () => {
      this.currentTime = await time.latest();
      this.earlymintPhaseStartTime = this.currentTime.toNumber()+earlymintPhaseDelay;
      //console.log(this.freemintPhaseStartTime.toString() +" "+ this.whitelistPhaseDelay.toString());
      await minterContract.phase_setTimes(
        this.earlymintPhaseStartTime,
        mintPhaseDelay,
        endPhaseDelay,
        {from: owner});
      this.phasesSet = await minterContract.phase_startTimes();
      this.curPhase = await minterContract.phase_nameOfCurrent();
      assert.equal(this.curPhase, "Setup", "The current phase is not 'Setup'...");
      assert.equal(this.phasesSet[1].toNumber(), this.earlymintPhaseStartTime, "Early mint phase start time not set correctly");
      assert.equal(this.phasesSet[2].toNumber(), this.earlymintPhaseStartTime+mintPhaseDelay, "Mint phase start time not set correctly");
      assert.equal(this.phasesSet[3].toNumber(), this.earlymintPhaseStartTime+mintPhaseDelay+endPhaseDelay, "End phase start time not set correctly");
      //console.log(this.phasesSet.toString());
    });

    // EARLYMINT PHASE

    it("ensure that the earlymint phase starts when planned", async () => {
      this.phasesSet = await minterContract.phase_startTimes();
      this.earlymintPhaseStart = this.phasesSet[1].toNumber();
      await time.increaseTo(this.earlymintPhaseStart-1); // One second before the new phase starts
      this.phaseBefore = await minterContract.phase_nameOfCurrent();
      await time.increase(2);  // One second after the new phase starts
      this.phaseAfter = await minterContract.phase_nameOfCurrent();
      assert.equal(this.phaseBefore, "Setup", "Previous phase is not 'Setup'...");
      assert.equal(this.phaseAfter, "Early-Minting", "New phase is not 'Early-Minting'...");
    });

    /*it("ensure that the earlymint phase starts when planned", async () => {
      this.phasesSet = await minterContract.phase_startTimes();
      this.earlymintPhaseStart = this.phasesSet[1].toNumber();
      await time.increaseTo(this.earlymintPhaseStart-1); // One second before the new phase starts
      this.phaseBefore = await minterContract.phase_nameOfCurrent();
      await time.increase(2);  // One second after the new phase starts
      this.phaseAfter = await minterContract.phase_nameOfCurrent();
      assert.equal(this.phaseBefore, "Setup", "Previous phase is not 'Setup'...");
      assert.equal(this.phaseAfter, "Early-Minting", "New phase is not 'Early-Minting'...");
    });*/

    /*
    it("accounts in Freemint list can now claim", async () => {
      this.accountData = merkleTreeData.freemint.accounts[0];
      this.account = this.accountData.address;
      accounts.push(this.account);
      //console.log(this.account);
      this.amount = this.accountData.entries;
      //console.log(this.amount);
      this.proof = this.accountData.merkleProof;
      //console.log(this.proof);
      await truffleAssert.passes(
        minterContract.mintFree(this.amount, this.amount, this.proof, { from: this.account })
      );
      this.tokensAfter = await NFTcontract.balanceOf(this.account);
      assert.equal(this.tokensAfter, this.amount, "Account hasn't received the tokens");
    });*/
    
});