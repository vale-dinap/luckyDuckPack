// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 * @dev Interface to interact with the {LuckyDucksPack} contract.
 */
interface ILDP{
    /**
     * @dev Mints a new token.
     * @param account Destination address.
     */
    function mint(address account) external;
    /**
     * @dev Returns the current total supply.
     */
    function totalSupply() view external returns(uint256);
    /**
     * @dev Returns the supply cap.
     */
    function MAX_SUPPLY() view external returns(uint256);
}