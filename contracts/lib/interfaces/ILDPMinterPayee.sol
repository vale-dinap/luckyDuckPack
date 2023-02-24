// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @dev Interface to interact with the {LDPMinterPayee} contract.
 */
interface ILDPMinterPayee{
    /**
     * @dev Sends payment to the contract, which forwards a portion of the
     * funds (meant to be ridistributed as initial incentives) to the
     * {LDPRewarder} contract.
     */
    function processPayment(uint256 amount) external payable;
}