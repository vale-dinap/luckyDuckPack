// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "../interfaces/IWETH.sol";

/**
 * @dev Workaround to embed WETH unwraps in more complex logics without running out of gas.
 */
contract WethUnwrapper{
    // WETH contract
    IWETH public WETH;
    // Creator's address - only Creator is allowed to interact
    address public creator;

    /**
     * @dev Store Creator address and initialize WETH contract instance.
     */
    constructor(address _wethContract){
        creator=msg.sender;
        WETH = IWETH(_wethContract);
    }

    /**
     * @dev Ensures only Creator can interact.
     */
    modifier onlyCreator{
        require(msg.sender==creator, "Caller is not deployer");
        _;
    }

    /**
     * @dev Calls WETH contract to unwrap WETH balance.
     */
    function unwrap(uint256 amount) external onlyCreator {
        WETH.withdraw(amount);
    }

    /**
     * @dev Allows to send ETH balance to Creator.
     */
    function withdraw() external onlyCreator{
        (bool success, ) = msg.sender.call{value: address(this).balance}("");
        require(success);
    }

    /**
     * @dev Ensures WETH contract is able to send ETH to this.
     */
    receive() external payable{}
}