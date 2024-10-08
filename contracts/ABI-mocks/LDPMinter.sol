// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

///////////////////////////////////////////////////////////////////////////////////////////////////////
///// MINTER MOCK CONTRACT - ABI consistent with the production version - includes events/errors //////
///////////////////////////////////////////////////////////////////////////////////////////////////////

contract MockLDPMinter {

    /** 
     * NOTE: All variables and functions with the "TEST_" prefix will NOT be available in the production contract
     */

    // TEST-ONLY VARIABLES - NOT PRESENT IN PRODUCTION VERSION //

    uint256 TEST_mintedSupply = 0;

    // OTHER VARIABLES - ALSO AVAILABLE IN PRODUCTION VERSION //

    // Pricing - NOTE: Values might differ in the production version
    uint256 private constant _PRICE1 = 0.1 ether; // From 1 to 3333
    uint256 private constant _PRICE2 = 0.15 ether; // From 3334 to 6666
    uint256 private constant _PRICE3 = 0.2 ether; // From 6667 to 10000
    // When the admin sets this to 'true', minting is enabled and cannot be reverted back to 'false'
    bool public mintingStarted;

    // Events
    event MintingStarted(); // Emitted when the minting is opended

    // Custom errors
    error MaxMintsPerCallExceeded();
    error Underpaid(uint256 paid, uint256 required);
    error MintingNotStarted();
    error MintingAlreadyStarted();

    /**
     * @notice Mint (buy) tokens to the caller address. NonReentrant in the production version.
     * @param amount Number of tokens to be minted, max 10 per transaction.
     */
    function mint(uint256 amount) external payable {
        // Revert if minting hasn't started
        if (!mintingStarted) revert MintingNotStarted();
        // Revert if attempting to mint more than 10 tokens at once
        if (amount > 10) revert MaxMintsPerCallExceeded();
        // Revert if underpaying
        unchecked {
            if (msg.value < currentPrice() * amount)
                revert Underpaid(msg.value, currentPrice() * amount);
        }
        // Finally, mint the tokens
        TEST_mintedSupply += amount; // HERE WILL BE THE MINT CALL
        // The ERC721 contract will also emit mint events
    }

    /**
     * @notice Enable minting.
     * @dev This function can be called only once. Restricted to Owner in the production version.
     */
    function startMinting() external {
        if (mintingStarted) revert MintingAlreadyStarted();
        mintingStarted = true;
        emit MintingStarted();
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
        if (curSupply < 3334) return _PRICE1;
        else if (curSupply < 6667) return _PRICE3;
        else return _PRICE3;
    }     

}