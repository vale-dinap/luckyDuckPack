// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/erc20/IERC20.sol";
import "./lib/interfaces/ILDP.sol";
import "./lib/interfaces/IWETH.sol";
import "./WethUnwrapper.sol";

// TODO: incentives code
// TODO: withdraw single token earnings
// TODO: final check

/**
 * @dev Lucky Ducks Pack Rewarder contract
 *
 * This contract's address is the NFT collection's creator fees receiver.
 * When fees from a Lucky Ducks Pack token trade are received, token holders
 * are able to claim their share of revenues by calling {cashout}.
 *
 * A small portion of the revenues (6.25%) is forwarded to the collection creator,
 * token holders earn the remaining 93.75%, proportionally to the amount of tokens
 * they hold.
 *
 * Revenues are bound to tokens, not to holder addresses: in other words,
 * selling a token without claiming its revenues first will transfer the ability
 * to claim them to the buyer.
 *
 * Supported currencies are ETH and WETH by default. In the event that creator fees
 * are received in other tokens, a separate set of functions to manually
 * distribute/withdraw them is available and callable by anyone.
 *
 * This contract is fair, unstoppable, unpausable, mostly immutable: admin can only
 * amend the creator address, but has no way to access funds meant for token
 * holders nor change the contract's behaviour.
 *
 * In addition, all public/external functions involving transfers of funds (included
 * the admin/creator withdraws) rely on "transfer" calls to prevent reentrancy attacks.
 */
contract LDPRewarder is Ownable, ReentrancyGuard {
    // Type defining revenues info
    struct Revenues {
        uint256 lifetimeEarnings; // Lifetime earnings of each NFT
        uint256 creatorLifetimeEarnings; // Lifetime earnings of the creator
        uint256 creatorLifetimeCollected; // Lifetime earnings collected by creator
        mapping(uint256 => uint256) lifetimeCollected; // NFT ID => amount
    }

    // Type defining incentives info
    /*struct Incentive{
        uint256 amount;
        mapping(uint256=>uint256) collected; // NFT ID => amount
        uint256 startTime;
        uint16 distributionDays;
    }*/

    // Store ETH revenues data
    Revenues private _revenues;
    // Store ERC20 tokens revenues data
    mapping(address => Revenues) private _erc20Revenues; // Token address => Revenues
    // Keeps track of the processed ERC20 revenues to identify and process new received funds
    mapping(address => uint256) private _processedErc20Revenues; // Token address => balance

    // Store incentives data
    /*Incentive private _incentives;*/

    // Creator address
    address payable private _creator;
    // Lucky Ducks Pack NFT contract
    ILDP public nft;
    // WETH token and WETH Unwrapper contracts
    IWETH private constant weth =
        IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    WethUnwrapper private immutable wethUnwrapper;

    /**
     * @dev Failsafe: set admin address as default beneficiary of
     * creator earnings.
     * Initialize the WETH unwrapper contract.
     */
    constructor() {
        _creator = payable(msg.sender);
        wethUnwrapper = new WethUnwrapper(address(weth));
    }

    // EVENTS //

    /**
     * @dev Emitted when ETH is withdrawn.
     */
    event WithdrawEth(address indexed account, uint256 indexed amount);
    /**
     * @dev Emitted when an ERC20-token is withdrawn.
     */
    event WithdrawErc20(
        address indexed account,
        uint256 indexed amount,
        address indexed token
    );

    /**
     * @dev Earnings in Wrapped Ether (WETH) are automatically converted to ETH
     * by the contract. This modifier prevents ERC20-related functions from
     * operating with WETH.
     */
    modifier noWeth(address tokenContract) {
        require(tokenContract != address(weth), "Not allowed with WETH");
        _;
    }

    // ADMIN FUNCTIONS //

    /**
     * @notice Link the token contract instance to the nft contract address.
     * Can be set only once and becomes immutable afterwards.
     */
    function setNftAddress(address nftAddr) external onlyOwner {
        require(address(nft) == address(0), "Overriding denied");
        nft = ILDP(nftAddr);
    }

    /**
     * @notice Admin function to amend the creator address.
     */
    function setCreatorAddress(address newAddress) external onlyOwner {
        require(newAddress != address(0));
        _creator = payable(newAddress);
    }

    // RECEIVE CALLBACK //

    /**
     * @dev When eth funds are received, this function:
     * -updates the ETH revenue records;
     * -unwraps any previously received WETH and adds
     *  these unwrapped funds to the ETH revenue records.
     */
    receive() external payable {
        _updateRevenueRecords(msg.value);
        _unwrapWethIfAny();
    }

    // USER FUNCTIONS //

    /**
     * @notice Allows LDP holders to withdraw the revenues generated by
     * their tokens.
     */
    function cashout() external nonReentrant {
        _holderCashout(msg.sender);
    }

    /**
     * @notice Similar to {cashout} but works with any ERC20 token.
     * @param tokenAddress Address of the ERC20 token contract.
     */
    function cashoutErc20(address tokenAddress) external noWeth(tokenAddress) {
        _updateErc20Revenues(tokenAddress);
        _holderCashout(msg.sender, tokenAddress);
    }

    /**
     * @notice Allows LDP holders to withdraw the revenues generated by
     * their tokens.
     */
    function creatorCashout() external nonReentrant {
        _creatorCashout();
    }

    /**
     * @notice Similar to {creatorCashout} but works with any ERC20 token.
     * @param tokenAddress Address of the ERC20 token contract.
     */
    function creatorCashoutErc20(address tokenAddress)
        external
        noWeth(tokenAddress)
    {
        _creatorCashout(tokenAddress);
    }

    /**
     * @notice Returns true if the revenue records of the provided ERC20 token
     * are up to date.
     * @param tokenAddress Address of the ERC20 token contract.
     */
    function isErc20RevenueRecordsUpToDate(address tokenAddress)
        external
        view
        returns (bool)
    {
        if (tokenAddress == address(weth)) return true;
        else
            return
                IERC20(tokenAddress).balanceOf(address(this)) ==
                _processedErc20Revenues[tokenAddress];
    }

    /**
     * @notice Force updating the revenue records of the provided ERC20 token;
     * while ETH and WETH are automatically updated by {receive}, this is not
     * possible with ERC20 tokens.
     * @param tokenAddress Address of the ERC20 token contract.
     */
    function forceUpdateErc20RevenueRecords(address tokenAddress)
        external
        noWeth(tokenAddress)
    {
        _updateErc20Revenues(tokenAddress);
    }

    /**
     * @notice Returns the revenues accrued by the specified token id.
     */
    function nftRevenues(uint256 tokenId) external view returns (uint256) {
        return _getNftRevenues(_revenues, tokenId);
    }

    /**
     * @notice ERC20-token version of {nftRevenues}.
     * @param tokenId Id of the LDP nft.
     * @param tokenAddress Address of the ERC20 token contract.
     */
    function nftRevenuesErc20(uint256 tokenId, address tokenAddress)
        external
        view
        returns (uint256)
    {
        if (tokenAddress == address(weth)) return 0;
        else return _getNftRevenues(_erc20Revenues[tokenAddress], tokenId);
    }

    /**
     * @notice Returns the sum of all revenues accrued by the tokens owned by the given account.
     * Use {isErc20RevenueRecordsUpToDate} to check if these records are up to date; if not,
     * records can be updated by calling {forceUpdateTokenRevenueRecords}.
     */
    function accountRevenues(address account)
        external
        view
        returns (uint256 accruedRevenues)
    {
        for (uint256 i; i < nft.balanceOf(account); ++i) {
            accruedRevenues += _getNftRevenues(
                _revenues,
                nft.tokenOfOwnerByIndex(account, i)
            );
        }
    }

    /**
     * @notice ERC20-token version of {accountRevenues}.
     * @param account Holder's address.
     * @param tokenAddress Address of the ERC20 token contract.
     */
    function accountRevenuesErc20(address account, address tokenAddress)
        external
        view
        returns (uint256 accruedRevenues)
    {
        if (tokenAddress == address(weth)) return 0;
        else {
            for (uint256 i; i < nft.balanceOf(account); ++i) {
                accruedRevenues += _getNftRevenues(
                    _erc20Revenues[tokenAddress],
                    nft.tokenOfOwnerByIndex(account, i)
                );
            }
        }
    }

    // INTERNAL LOGICS - Incentives

    /*function _processIncentives(uint256 tokenId) private returns(uint256){

    }*/

    // INTERNAL LOGICS

    /**
     * @dev If this smart-contract holds any WETH, unwrap it.
     * By doing so, the receive function is also called which causes
     * the unwrapped ETH to be added to the revenue records. This is
     * a workaround as normally the automatic revenues distribution
     * could not occur if the creator fees are received in WETH.
     */
    function _unwrapWethIfAny() private {
        uint256 bal = weth.balanceOf(address(this));
        if (bal > 0) {
            weth.transfer(address(wethUnwrapper), bal);
            wethUnwrapper.unwrap(bal);
            wethUnwrapper.withdraw();
        }
    }

    /**
     * @dev Send to `account` all ETH revenues accrued by its tokens.
     * @param account Holder's address
     */
    function _holderCashout(address account) private {
        uint256 amount;
        for (uint256 i; i < nft.balanceOf(account); ++i) {
            amount += _processWithdrawData(
                _revenues,
                nft.tokenOfOwnerByIndex(account, i)
            );
        }
        emit WithdrawEth(account, amount);
        payable(account).transfer(amount);
    }

    /**
     * @dev Function overload that works with any ERC20-token.
     * @param account Holder's address
     * @param tokenAddress Address of the ERC20 token contract
     */
    function _holderCashout(address account, address tokenAddress) private {
        uint256 amount;
        for (uint256 i; i < nft.balanceOf(account); ++i) {
            amount += _processWithdrawData(
                _erc20Revenues[tokenAddress],
                nft.tokenOfOwnerByIndex(account, i)
            );
        }
        emit WithdrawErc20(account, amount, tokenAddress);
        IERC20(tokenAddress).transfer(account, amount);
    }

    /**
     * @dev Send creator revenues to their address.
     */
    function _creatorCashout() private {
        uint256 earnings = _processWithdrawDataCreator(_revenues);
        emit WithdrawEth(_creator, earnings);
        _creator.transfer(earnings);
    }

    /**
     * @dev ERC20-token version of {_creatorCashout}.
     * @param tokenAddress Address of the ERC20 token contract.
     */
    function _creatorCashout(address tokenAddress) private {
        uint256 earnings = _processWithdrawDataCreator(
            _erc20Revenues[tokenAddress]
        );
        emit WithdrawErc20(_creator, earnings, tokenAddress);
        IERC20(tokenAddress).transfer(_creator, earnings);
    }

    /**
     * @dev Updates ETH revenue records. This function is embedded in
     * the receive() fallback, therefore automatically called whenever
     * new ETH is received.
     * @param newRevenues Amount of ETH to be added to revenue records.
     */
    function _updateRevenueRecords(uint256 newRevenues) private {
        uint256 creatorsCut;
        uint256 holdersCut;
        (creatorsCut, holdersCut) = _calculateCuts(newRevenues);
        _revenues.lifetimeEarnings += (holdersCut / 10000);
        _revenues.creatorLifetimeEarnings += creatorsCut;
    }

    /**
     * @dev Function overload to perform the same logics with any ERC20 token.
     * Note: this cannot be called automatically when receiving ERC20 token
     * transfers. As a workaround, it is called by {cashoutToken} before
     * performing the actual withdraw.
     * @param newRevenues Amount to be added to revenues
     * @param tokenAddress Address of the ERC20 token contract
     * @param tokenBalance Up-to-date token balance of this contract
     */
    function _updateRevenueRecords(
        uint256 newRevenues,
        address tokenAddress,
        uint256 tokenBalance
    ) private {
        uint256 creatorsCut;
        uint256 holdersCut;
        (creatorsCut, holdersCut) = _calculateCuts(newRevenues);
        _erc20Revenues[tokenAddress].lifetimeEarnings += holdersCut / 10000;
        _erc20Revenues[tokenAddress].creatorLifetimeEarnings += creatorsCut;
        _processedErc20Revenues[tokenAddress] = tokenBalance;
    }

    /**
     * @dev Calls {_updateRevenueRecords(uint256,address,uint256)}, but
     * only if the data of the specified ERC20 token is not up to date.
     * @param tokenAddress Address of the ERC20 token contract
     */
    function _updateErc20Revenues(address tokenAddress) private {
        uint256 curBalance = IERC20(tokenAddress).balanceOf(address(this));
        uint256 processedRevenues = _processedErc20Revenues[tokenAddress];
        if (curBalance != processedRevenues) {
            _updateRevenueRecords(
                curBalance - processedRevenues,
                tokenAddress,
                curBalance
            );
        }
    }

    /**
     * @dev Called when revenues are claimed: returns the amount of revenues
     * claimable by the specified token ID and records that these revenues
     * have now been collected.
     * @param tokenId Id of the LDP token
     */
    function _processWithdrawData(
        Revenues storage revenueRecords,
        uint256 tokenId
    ) private returns (uint256 accruedRevenues) {
        accruedRevenues =
            revenueRecords.lifetimeEarnings -
            revenueRecords.lifetimeCollected[tokenId];
        revenueRecords.lifetimeCollected[tokenId] = revenueRecords
            .lifetimeEarnings;
    }

    /**
     * @dev Called when creator revenues are claimed: returns the amount of
     * revenues claimable by the collection creator and records that these
     * revenues have now been collected.
     */
    function _processWithdrawDataCreator(Revenues storage revenueRecords)
        private
        returns (uint256 accruedRevenues)
    {
        accruedRevenues =
            revenueRecords.creatorLifetimeEarnings -
            revenueRecords.creatorLifetimeCollected;
        revenueRecords.creatorLifetimeCollected = revenueRecords
            .lifetimeEarnings;
    }

    /**
     * @dev Calculate holders and creator revenues from the given amount.
     */
    function _calculateCuts(uint256 amount)
        private
        pure
        returns (uint256 creatorsCut, uint256 holdersCut)
    {
        creatorsCut = amount / 16; // 6.25% to creator
        holdersCut = amount - creatorsCut; // 93.75% to holders
    }

    /**
     * @dev Returns the unclaimed revenues accrued by the given tokenId.
     */
    function _getNftRevenues(Revenues storage revenueRecords, uint256 tokenId)
        private
        view
        returns (uint256)
    {
        return
            revenueRecords.lifetimeEarnings -
            revenueRecords.lifetimeCollected[tokenId];
    }
}
