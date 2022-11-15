// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";

// TODO: add comments, double-check everything

contract LDPMinterPayee is Ownable {
    uint256 private constant incentivesPerMint = 0.3 ether;
    address payable public constant rewarderContract=payable(0); // TODO: REPLACE THIS WITH ACTUAL ADDRESS OR METHOD TO SET
    address public nftContract;
    address minterContract;
    address private _ducker;

    constructor(){
        _ducker = msg.sender;
    }

    /**
     * @dev Emitted if funds are manually sent to this contract (no sale involved).
     */
    event Donated(address indexed donator, uint256 indexed amount);

    /**
     * @dev Error when input is address(0).
     */
    error ZeroAddressUsed();

    /**
     * @dev Error when a payment fails.
     */
    error PaymentFailed();

    function setNftAddress(address newAddress) external onlyOwner{
        if (newAddress==address(0)) revert ZeroAddressUsed();
        nftContract = newAddress;
    }

    function setDuckerAddress(address newAddress) external onlyOwner{
        if (newAddress==address(0)) revert ZeroAddressUsed();
        _ducker = newAddress;
    }

    /**
     * @dev Admin function to withdraw the proceeds.
     */
    function withdrawProceeds() external onlyOwner{
        payable(_ducker).transfer(address(this).balance);
    }

    /**
     * @dev Callable only by the minter contract, forwards a portion of the funds
     * to the {LDPRewarder} contract in order to distribute them as initial incentives.
     */
    function processPayment(uint256 amount) external payable{
        require(msg.sender == minterContract);
        (bool paid, ) = rewarderContract.call{value: incentivesPerMint*amount}(""); // TODO: replace with function to send incentives
        if(!paid) revert PaymentFailed();
    }

    /**
     * @dev If anyone donates ETH to this contract I will make good use of it. :)
     */
    receive() external payable{
        emit Donated(tx.origin, msg.value);
    }
}