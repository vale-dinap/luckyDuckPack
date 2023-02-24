// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

///////////////////////////////////////////////////////////////////////////////////////////////////
///// DIVIDENDS DUMMY CONTRACT - ABI consistent with the production version - includes events /////
///////////////////////////////////////////////////////////////////////////////////////////////////

contract LDPRewarder {

    /** 
     * NOTE: All variables and functions with the "TEST_" prefix will NOT be available in the production contract
     */

    // TEST-ONLY VARIABLES - NOT PRESENT IN PRODUCTION VERSION //

    uint256 TEST_wethBalance;
    uint256 TEST_collectionEarningsLifetime;
    mapping (address => uint256) TEST_accountRevenues;
    mapping (uint256 => uint256) TEST_nftRevenues;


    // EVENTS AND ERRORS //

    /**
     * @dev Emitted when the contract receives ETH.
     */
    event ReceivedEth(uint256 indexed amount);
    /**
     * @dev Emitted when the WETH held by the contract is unwrapped.
     */
    event UnwrappedWeth();
    /**
     * @dev Emitted when ETH is withdrawn by calling one of the "cashout" functions.
     */
    event Cashout(address indexed account, uint256 indexed amount);
    /**
     * @dev Raised on payout errors.
     */
    error CashoutError();

    // RECEIVE FUNCTION //

    /**
     * @dev Update the revenue records when ETH are received.
     */
    receive() external payable {
        emit ReceivedEth(msg.value);
    }

    // USER FUNCTIONS //

    /**
     * @notice Cashout the revenues accrued by all owned NFTs.
     *
     * @dev TEST: this currently works on a test mapping; the production
     *            version checks all token IDs owned by msg.sender and performs
     *            the cashout on each, similar to {nftCashout};
     *            in this test version, the accrued earnings can be set by
     *            calling {TEST_setAccountRevenues};
     *            in the production version, the account revenues is equal to 
     *            the sum of the {nftRevenues} of all NFTs held by the given address.
     */
    function cashout() external {
        uint256 _revenues = TEST_accountRevenues[msg.sender];
        TEST_accountRevenues[msg.sender] = 0;
        emit Cashout(msg.sender, _revenues);
    }

    /**
     * @notice Cashout all revenues accrued by the specified NFT.
     *
     * @dev TEST: this currently works on a test mapping; the production
     *            version checks the owner of `tokenId` and sends them the
     *            accrued earnings;
     *            in this test version, the accrued earnings can be set by
     *            calling {TEST_setNftRevenues}.
     */
    function nftCashout(uint256 tokenId) external {
        uint256 _revenues = TEST_nftRevenues[tokenId];
        TEST_nftRevenues[tokenId] = 0;
        emit Cashout(msg.sender, _revenues);
    }

    /**
     * @notice Unwraps all the unprocessed WETH received by the contract.
     *
     * @dev TEST: by unwrapping contract WETH balance, this function will
     *            increase the contract ETH balance by the same amount.
     */
    function unwrapWeth() external {
        TEST_wethBalance = 0;
        emit UnwrappedWeth();
    }

    /**
     * @notice Check if the contract has any WETH pending to be unwrapped.
     *
     * @dev TEST: currently set to return a test variable, that can be set by calling
     *            {TEST_setWethBalance}.
     */
    function unprocessedWeth() external view returns (uint256) {
        return TEST_wethBalance;
    }

    /**
     * @notice Returns the total revenue generated by tokens held by `account`.
     *
     * @dev TEST: in this dummy contract, it simply returns the value set via
     *            {TEST_setAccountRevenues}; the production version will actually
     *            return the sum of {nftRevenues} of all NFTs held by `account`.
     */
    function accountRevenues(address account)
        external
        view
        returns (uint256 accruedRevenues)
    {
        accruedRevenues = TEST_accountRevenues[account];
    }

    /**
     * @notice Returns the revenues accrued by the token `tokenId`.
     *
     * @dev TEST: currently set to return a test variable, that can be set by calling
     *            {TEST_setNftRevenues}.
     */
    function nftRevenues(uint256 tokenId) external view returns (uint256) {
        return TEST_nftRevenues[tokenId];
    }

    /**
     * @notice Return the lifetime earnings distributed to NFT holders (ETH).
     *
     * @dev TEST: currently set to return a test variable, that can be set by calling
     *            {TEST_setCollectionEarningsLifetime}.
     */
    function collectionEarningsLifetime() external view returns (uint256) {
        return TEST_collectionEarningsLifetime;
    }

    // TEST-ONLY FUNCTIONS - NOT PRESENT IN PRODUCTION VERSION //

    function TEST_setWethBalance(uint256 bal) public {
        TEST_wethBalance = bal;
    }

    function TEST_setAccountRevenues(address account, uint256 amount) public {
        TEST_accountRevenues[account] = amount;
    }

    function TEST_setNftRevenues(uint256 tokenId, uint256 amount) public {
        TEST_nftRevenues[tokenId] = amount;
    }

    function TEST_setCollectionEarningsLifetime(uint256 amount) public {
        TEST_collectionEarningsLifetime = amount;
    }

}