// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./lib/interfaces/ILDP.sol";

// TODO: build payment receiver contract. It must somehow check how
// many tokens have been minted and send 0.3 eth for each to the rewarder
// address as initial incentives

/**
 * @dev Lucky Ducks Pack minter contract.
 */
contract LDPMinter is Ownable, ReentrancyGuard{

    // Pricing
    uint256 private constant _price1 = 1.3 ether; // From 1 to 3333
    uint256 private constant _price2 = 1.8 ether; // From 3334 to 6666
    uint256 private constant _price3 = 2.3 ether; // From 6667 to 10000
    // Instance of the token contract
    ILDP constant nft = ILDP(address(0)); // TODO: REPLACE address(0) with NFT contract address
    // Minting start time (Unix timestamp)
    uint256 public mintingStartTime;
    // Address receiving payments
    address payable public payee;

    /**
     * @notice Store the address that will receive payments.
     */
    function setPayee(address payable payeeAddr) external onlyOwner{
        require(payeeAddr!=address(0));
        payee = payeeAddr;
    }

    /**
     * @notice Mint (buy) tokens to the caller address.
     * @param amount Number of tokens to be minted, max 10 per call.
     */
    function mint(uint256 amount) external payable nonReentrant {
        require(block.timestamp>mintingStartTime, "Minting not started");
        if(amount>10) revert("Attempted to mint more than 10");
        require(msg.value>=_currentPrice()*amount, "Price paid incorrect");
        (bool paid, ) = payee.call{value: msg.value}("");
        if(!paid) revert("Payment error");
        else _mintBatch(amount);
    }

    /**
     * @notice Set minting start time and reserve 10 tokens to admin's address.
     */
    function initializeMinting(uint256 startTime) external onlyOwner {
        if(mintingStartTime>0) revert("Already initialized");
        else{
            require(startTime>block.timestamp, "Input startTime is in the past");
            mintingStartTime = startTime;
            _mintBatch(10);
        }
    }

    /**
     * @notice Shows how many tokens are left to be minted.
     */
    function mintableSupply() view external returns(uint256){
        return nft.MAX_SUPPLY()-nft.totalSupply();
    }

    /**
     * @notice Shows the current price.
     */
    function currentPrice() view external returns(uint256){
        return _currentPrice();
    }

    /**
     * @dev Returns the current price (depends on the minted supply).
     */
    function _currentPrice() view private returns(uint256){
        uint256 curSupply = nft.totalSupply();
        if(curSupply<3334) return _price1;
        else if (curSupply<6667) return _price2;
        else return _price3;
    }

    /**
     * @dev Mint multiple tokens.
     */
    function _mintBatch(uint256 amount) private{
        for(uint256 i=0; i<amount; ++i){
            nft.mint(msg.sender);
        }
    }
}