// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

///////////////////////////////////////////////////////////////////////////////////////////////////////
///// MINTER DUMMY CONTRACT - ABI consistent with the production version - includes custom errors /////
///////////////////////////////////////////////////////////////////////////////////////////////////////

contract LDPMinter {

    /** 
     * NOTE: All variables and functions with the "TEST_" prefix will NOT be available in the production contract
     */

    // TEST-ONLY VARIABLES - NOT PRESENT IN PRODUCTION VERSION //

    uint256 TEST_mintedSupply = 0;

    // OTHER VARIABLES - ALSO AVAILABLE IN PRODUCTION VERSION //

    // Pricing - NOTE: Values might differ in the production version
    uint256 private constant _price1 = 0.1 ether; // From 1 to 3333
    uint256 private constant _price2 = 0.15 ether; // From 3334 to 6666
    uint256 private constant _price3 = 0.2 ether; // From 6667 to 10000
    // Minting start time (Unix timestamp)
    uint256 public mintingStartTime;

    // Custom errors
    error MaxMintsPerCallExceeded();
    error PricePaidIncorrect();
    error MintingNotStarted();

    /**
     * @notice Mint (buy) tokens to the caller address.
     * @param amount Number of tokens to be minted, max 10 per transaction.
     */
    function mint(uint256 amount) external payable {
        // Revert if minting hasn't started
        if(block.timestamp < mintingStartTime) revert MintingNotStarted();
        // Revert if attempting to mint more than 10 tokens at once
        if (amount > 10) revert MaxMintsPerCallExceeded();
        // Revert if underpaying
        unchecked{
            if(msg.value < currentPrice() * amount) revert PricePaidIncorrect();
        }
        // Finally, mint the tokens
        // HERE WILL BE THE MINT CALL - THE LINKED ERC721 CONTRACT WILL SEND EVENTS
    }

    /**
     * @notice Shows how many tokens are left to be minted.
     * 
     * NOTE: This can be also retreived by fetching the ERC721 contract's event log.  
     */
    function mintableSupply() external view returns (uint256) {
        return 10000-TEST_mintedSupply;
    }

    /**
     * @notice Shows the current price.
     *
     * NOTE: The price depends on the minted supply. Alternatively to calling this,
     * function, frontend can fetch the token supply through the ERC721 contract's
     * event log and then use it to calculate the current price, by considering the
     * following:
     *      Price 1: Supply from    1 to 3333
     *      Price 2: Supply from 3334 to 6666
     *      Price 3: Supply from 6667 to 10000
     */
    function currentPrice() public view returns (uint256) {
        uint256 curSupply = TEST_mintedSupply;
        if (curSupply < 3334) return _price1;
        else if (curSupply < 6667) return _price2;
        else return _price3;
    }

    // TEST-ONLY FUNCTIONS - NOT PRESENT IN PRODUCTION VERSION //

    function TEST_increaseMintedSupply(uint256 amount) public {
        TEST_mintedSupply += amount;
    }        
}