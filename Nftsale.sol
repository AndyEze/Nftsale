// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract NFTSale is ERC721 {
    mapping(address => uint256) UserBalances;
    mapping(uint => bool) claimed;

    struct Nft {
        uint256 minPrice;
        uint256 endTime;
        uint256 bid;
        address payable seller;
        address payable bidder;
        bool isOnSale;
    }

    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;

    mapping(uint256 => Nft) nfts; // stores details of Nft on auction

    event OnSale(uint256 indexed tokenId, uint256 minPrice, uint256 endTime);
    event Bid(uint256 indexed tokenId, address indexed bidder, uint256 price);
    event SaleEnded(
        uint256 indexed tokenId,
        address indexed buyer,
        uint256 price
    );

    constructor(string memory name_, string memory symbol_)
        ERC721(name_, symbol_)
    {}

    modifier checkClaim(uint _index) {
        require(claimed[_index], "token hasn't been claimed");
        _;
    }

    modifier notClaimed(uint _index) {
        require(!claimed[_index], "token has been claimed");
        _;
    }

    /**
  Internal function to check if msg.sender is either owner or approved
  @param sender - address
  @param tokenId - token id
   */
    function isOwnerOrApproved(address sender, uint256 tokenId)
        internal
        view
        returns (bool)
    {
        require(_exists(tokenId));
        return (sender == ownerOf(tokenId) || sender == getApproved(tokenId));
    }

    function safeMint(address to) public {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(to, tokenId);
        claimed[tokenId] = true;
    }

    /**
  Owner can put a token on auction.
  @param tokenId - token id 
  @param price - minimum price required
  @param endTime - end time of auction
   */
    function putOnAuction(
        uint256 tokenId,
        uint256 price,
        uint256 endTime
    ) public checkClaim(tokenId) {
        require(
            isOwnerOrApproved(msg.sender, tokenId),
            "caller not an owner or approved"
        );
        require(nfts[tokenId].isOnSale == false, "Already on sale");
        nfts[tokenId].minPrice = price;
        nfts[tokenId].endTime = endTime;
        nfts[tokenId].seller = payable(msg.sender);
        nfts[tokenId].bid = 0;
        nfts[tokenId].isOnSale = true;
        claimed[tokenId] = false;
        emit OnSale(tokenId, price, endTime);
    }

    /**
  Bid for a token on sale. Bid amount has to be higher than current bid or minimum price.
  Accepts ether as the function is payable
  @param tokenId - token id 
   */
    function bid(uint256 tokenId) external payable notClaimed(tokenId) {
        require(nfts[tokenId].isOnSale == true, "Not on sale");
        require(nfts[tokenId].endTime > block.timestamp, "Sale ended");
        require(
            nfts[tokenId].bidder != msg.sender,
            "You can't outbid yourself"
        );
        if (nfts[tokenId].bid == 0) {
            require(
                msg.value > nfts[tokenId].minPrice,
                "value sent is lower than min price"
            );
        } else {
            require(
                msg.value > nfts[tokenId].bid,
                "value sent is lower than current bid"
            );
            UserBalances[nfts[tokenId].bidder] = addNumber(
                UserBalances[nfts[tokenId].bidder],
                nfts[tokenId].bid
            );
        }
        nfts[tokenId].bidder = payable(msg.sender);
        nfts[tokenId].bid = msg.value;
        emit Bid(tokenId, nfts[tokenId].bidder, msg.value);
    }

    /**
  Claim a token after end of sale
  @param tokenId - token id 
   */
    function claim(uint256 tokenId) external notClaimed(tokenId) {
        require(msg.sender == nfts[tokenId].bidder, "Not latest bidder");
        require(
            nfts[tokenId].endTime < block.timestamp,
            "Cannot claim before sale end time"
        );
        require(nfts[tokenId].isOnSale == true, "Not on sale");
        uint amount = nfts[tokenId].bid;
        nfts[tokenId].isOnSale = false;
        nfts[tokenId].bid = 0;
        claimed[tokenId] = true;
        UserBalances[nfts[tokenId].seller] = addNumber(
            UserBalances[nfts[tokenId].seller],
            amount
        );
        _transfer(nfts[tokenId].seller, nfts[tokenId].bidder, tokenId);
        emit SaleEnded(tokenId, nfts[tokenId].bidder, amount);
    }

    function withDrawEther() external payable {
        uint256 balance = UserBalances[msg.sender];
        require(balance > 0, "not enough money to withdraw");
        UserBalances[msg.sender] = 0;
        (bool success, ) = payable(msg.sender).call{value: balance}("");
        require(success, "withdrawal failed");
    }

    function getUserEtherBalance() public view returns (uint256) {
        return UserBalances[msg.sender];
    }

    /**
  Get status of a token
  @param tokenId - token id 
   */
    function getNFTBidStatus(uint256 tokenId)
        public
        view
        returns (bool, address)
    {
        return (nfts[tokenId].isOnSale, nfts[tokenId].bidder);
    }

    /**
  Add two uint
  @param a - number
  @param b - number
   */
    function addNumber(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize, which returns 0 for contracts in
        // construction, since the code is only stored at the end of the
        // constructor execution.

        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }
}
