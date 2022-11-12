// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./lib/interfaces/ILDP.sol";

contract LDPMinterPayee is Ownable {
    address payable public constant rewarderContract=payable(0); // TODO: REPLACE THIS WITH ACTUAL ADDRESS OR METHOD TO SET
    uint256 paymentsWithdrawn;
    address public nftContract;
    address ducker;

    constructor(){
        ducker = msg.sender;
    }

    function setNftAddress(address newAddress) external onlyOwner{
        require(newAddress!=address(0), "Attempting to set zero address");
        nftContract = newAddress;
    }

    function withdraw() external onlyOwner{
        uint256 totalSupply = _nft().totalSupply();
        require(totalSupply>10, "No sales yet"); // The first 10 tokens are reserved to the team (not sold)
        uint256 amountSold = totalSupply-10;
        uint256 toWithdraw = amountSold-paymentsWithdrawn;
        if(toWithdraw>0){
            uint256 incentivesToStash = toWithdraw * 0.3 ether;
            (bool success, ) = rewarderContract.call{value: incentivesToStash}("");
            if(success) payable(msg.sender).transfer(address(this).balance);
            else revert("Something went wrong");
        }
    }

    function _nft() view private returns(ILDP){
        return ILDP(nftContract);
    }

    receive() external payable{}
}