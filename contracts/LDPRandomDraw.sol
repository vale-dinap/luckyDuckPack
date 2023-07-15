// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";

contract LDPRandomDraw is
    Ownable,                            // Admin role
    VRFConsumerBase                     // Chainlink Random
{

    // =============================================================
    //                     CONTRACT VARIABLES
    // =============================================================

    // Chainlink VRF (Verifiable Random Function)
    address private constant VRFcoordinator = 0xf0d54349aDdcf704F77AE15b96510dEA15cb7952; // Contract
    uint256 private constant fee = 2 * 10**18; // 2 LINK fee on Ethereum Mainnet
    bytes32 private constant keyHash = 0xAA77729D3466CA35AE8D28B3BBAC7CC36A5031EFDC430821C02BC31A238AF445;

    /**
     * @dev Initialize the VRF module to work with Chainlink;
     * store the deployer's address; set the provenance timestamp.
     */
    constructor()
        VRFConsumerBase(
            VRFcoordinator, // Chainlink VRF Coordinator
            0x514910771AF9Ca656af840dff83E8264EcF986CA // LINK Token address
        )
    {}

    /**
     * @notice Callback function used by Chainlink VRF to provide the random number.
     * This function can only be called by Chainlink.
     * @param requestId The unique request ID associated with the Chainlink VRF request
     * @param randomness The random value provided by Chainlink VRF
     */
    function fulfillRandomness(bytes32 requestId, uint256 randomness)
        internal
        override
    {
        
    }
}