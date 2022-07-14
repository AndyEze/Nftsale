// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;
import './IERC721.sol';
import './IERC721Receiver.sol';

contract NFTSale is IERC721 {
  string private _name; 
  string private _symbol;

  mapping(uint256 => address) private _owners;
  mapping(address => uint256) private _balances;
  mapping(uint256 => address) private _approvedTokens;
  mapping(address => mapping(address => bool)) _approvedOperators;
  mapping(address => uint256) UserBalances;

  struct nft {
    uint256 minPrice;
    uint256 endTime;
    uint256 bid;
    address payable seller;
    address payable bidder;
    bool isOnSale;
  }

  uint public tokenId;

  mapping(uint256 => nft) nfts; // stores details of nft on auction

  modifier doesExist(uint _tokenId){
    require(_owners[_tokenId] != address(0), 'no token exists');
    _;
  }

  modifier notZeroAddress(address _to){
      require(_to != address(0), 'transfering to zero address');
      _;
  }

  event OnSale(uint256 indexed _tokenId, uint256 minPrice, uint256 endTime);
  event Bid(uint256 indexed _tokenId, address indexed bidder, uint256 price);
  event SaleEnded(uint256 indexed _tokenId, address indexed buyer, uint256 price);

  constructor(string memory name_, string memory symbol_) {
    _name = name_;
    _symbol = symbol_;
  }

  /**
  Get token contract name
   */
  function name() public view returns (string memory) {
    return _name;
  }

  /**
  Get token contract symbol
   */
  function symbol() public view returns (string memory) {
    return _symbol;
  }

  /**
  checks if a token already exist
  @param _tokenId - token id
   */
  function _exists(uint256 _tokenId) internal view returns (bool) {
    return _owners[_tokenId] != address(0);
  }

  /**
  Mint a token with id `_tokenId`
   */
  function mint() public {
    _safeMint(msg.sender, tokenId, "");
    tokenId++;
  }

  /**
  Mint safely as this function checks whether the receiver has implemented onERC721Received if its a contract
  @param to - to address
  @param _tokenId - token id
  @param data - data
   */
  function _safeMint(address to, uint256 _tokenId, bytes memory data) internal {
    _mint(to, _tokenId);
    require(_checkOnERC721Received(address(0), to, _tokenId, data), "receiver has not implemented ERC721Receiver");
  }

  /**
  Internal function to mint a token `_tokenId` to `to`
  @param to - to address
  @param _tokenId - token id
   */
  function _mint(address to, uint256 _tokenId) internal notZeroAddress(to){
    _balances[to] += 1;
    _owners[_tokenId] = to;
    emit Transfer(address(0), to, _tokenId);
  }

  /**
  Internal function to check if msg.sender is either owner or approved
  @param sender - address
  @param _tokenId - token id
   */
  function isOwnerOrApproved (address sender, uint256 _tokenId) internal view  doesExist(_tokenId) returns (bool)  {
    return (sender == _owners[_tokenId] || sender == _approvedTokens[_tokenId]);
  }

  /**
  Internal function to approve a token `_tokenId` to `to`
  @param to - to address
  @param _tokenId - token id
   */
  function _approve(address to, uint256 _tokenId) internal {
    _approvedTokens[_tokenId] = to;
    emit Approval(_owners[_tokenId], to, _tokenId);
  }

  /**
  IERC721 specification
   */
  function approve(address approved, uint256 _tokenId) public override { 
    address owner = _owners[_tokenId];
    require(msg.sender == _owners[_tokenId] || isApprovedForAll(owner, msg.sender), 'caller not an owner or not approved all');
    _approve(approved, _tokenId);
  }

  /**
  IERC721 specification
   */
  function getApproved(uint256 _tokenId) public view doesExist(_tokenId) override returns (address){
    return _approvedTokens[_tokenId];
  }

  /**
  IERC721 specification
   */
  function setApprovalForAll(address operator, bool approved) public override {
    require(operator != msg.sender, "approve to caller");
    _approvedOperators[msg.sender][operator] = approved;
    emit ApprovalForAll(msg.sender, operator, approved);
  }

  /**
  IERC721 specification
   */
  function isApprovedForAll(address owner, address operator) public view override returns (bool) {
    return _approvedOperators[owner][operator];
  }

  /**
  IERC721 specification
   */
  function balanceOf(address owner) public view override returns (uint256) {
    require(owner != address(0));
    return _balances[owner];
  }

  /**
  IERC721 specification
   */
  function ownerOf(uint256 _tokenId) public view doesExist(_tokenId) override returns (address) {
    return _owners[_tokenId];
  }

  /**
  Internal function to transfer a token from `from` to `to`
  @param from - from address
  @param to - to address
  @param _tokenId - token id
   */
  function _transfer(address from, address to, uint256 _tokenId) internal notZeroAddress(to){
    _owners[_tokenId] = to;
    _balances[to] += 1;
    _balances[from] -= 1;

    emit Transfer(from, to, _tokenId);
  }

  /**
  IERC721 specification
   */
  function safeTransferFrom(address from, address to, uint256 _tokenId) public override {
    safeTransferFrom(from, to, _tokenId, "");
  }

  /**
  IERC721 specification
   */
  function safeTransferFrom(address from, address to, uint256 _tokenId, bytes memory data) public override {
    require(isOwnerOrApproved(msg.sender, _tokenId), 'caller not an owner or approved');
    _transfer(from, to, _tokenId);
    require(_checkOnERC721Received(from, to, _tokenId, data), "receiver has not implemented ERC721Receiver");
  }

  /**
  Transfer a token from `from` to `to`
  @param from - from address
  @param to - to address
  @param _tokenId - token id
   */
  function transferFrom(address from, address to, uint256 _tokenId) public override {
    require(isOwnerOrApproved(msg.sender, _tokenId), 'caller not an owner or approved');
    _transfer(from, to, _tokenId);
  }

    /**
  Owner can put a token on auction.
  @param _tokenId - token id 
  @param price - minimum price required
  @param endTime - end time of auction
   */
  function putOnAuction(uint256 _tokenId, uint256 price, uint256 endTime) public {
    require(isOwnerOrApproved(msg.sender, _tokenId), 'caller not an owner or approved');
    require(nfts[_tokenId].isOnSale == false, 'Already on sale');
    nft storage _nft = nfts[_tokenId];
    _nft.minPrice = price;
    _nft.endTime = endTime;
    _nft.seller = payable(msg.sender);
    _nft.bid = 0;
    _nft.isOnSale = true;
    emit OnSale(_tokenId, price, endTime);
  }

  /**
  Bid for a token on sale. Bid amount has to be higher than current bid or minimum price.
  Accepts ether as the function is payable
  @param _tokenId - token id 
   */
  function bid(uint256 _tokenId) public payable {
    require(_owners[_tokenId] != msg.sender, 'owner cannot bid');
    require(nfts[_tokenId].isOnSale == true, 'Not on sale');
    require(nfts[_tokenId].endTime > block.timestamp, 'Sale ended');
    if (nfts[_tokenId].bid == 0) {
      require(msg.value > nfts[_tokenId].minPrice, 'value sent is lower than min price');
    } else {
      require(msg.value > nfts[_tokenId].bid, 'value sent is lower than current bid');
      UserBalances[nfts[_tokenId].bidder] = addNumer(UserBalances[nfts[_tokenId].bidder], nfts[_tokenId].bid);
    }
    nfts[_tokenId].bidder = payable(msg.sender);
    nfts[_tokenId].bid = msg.value;
    emit Bid(_tokenId, nfts[_tokenId].bidder, msg.value);
  }

  /**
  Claim a token after end of sale
  @param _tokenId - token id 
   */
  function claim(uint256 _tokenId) public {
    require(msg.sender == nfts[_tokenId].bidder, 'Not latest bidder');
    require(nfts[_tokenId].endTime < block.timestamp, 'Cannot claim before sale end time');
    require(nfts[_tokenId].isOnSale == true, 'Not on sale');
    UserBalances[nfts[_tokenId].seller] = addNumer(UserBalances[nfts[_tokenId].seller], nfts[_tokenId].bid);
    nfts[_tokenId].isOnSale = false;
    _transfer(nfts[_tokenId].seller, nfts[_tokenId].bidder, _tokenId);
    emit SaleEnded(_tokenId, nfts[_tokenId].bidder, nfts[_tokenId].bid);
  }

  function withDrawEther() public {
    uint256 balance = UserBalances[msg.sender];
    require(balance > 0, 'not enough money to withdraw');
    payable(msg.sender).transfer(balance);
  }

  function getUserEtherBalance() public view returns (uint256) {
    return UserBalances[msg.sender];
  }
  
  /**
  Get status of a token
  @param _tokenId - token id 
   */
  function getNFTBidStatus(uint256 _tokenId) public view returns (bool, address) {
    return (nfts[_tokenId].isOnSale, nfts[_tokenId].bidder);
  }

  /**
  Add two uint
  @param a - number
  @param b - number
   */
  function addNumer(uint256 a, uint256 b) internal pure returns (uint256) {
      uint256 c = a + b;
      require(c >= a, "SafeMath: addition overflow");

      return c;
  }

  /**
  Checks if the tartget is a contract and has implemented onERC721Received
   */
  function _checkOnERC721Received(
    address from,
    address to,
    uint256 _tokenId,
    bytes memory _data
  ) private returns (bool) {
      if (isContract(to)) {
          try IERC721Receiver(to).onERC721Received(msg.sender, from, _tokenId, _data) returns (bytes4 retval) {
              return retval == IERC721Receiver.onERC721Received.selector;
          } catch (bytes memory reason) {
              if (reason.length == 0) {
                  revert("receiver has not implemented ERC721Receiver");
              } else {
                  assembly {
                      revert(add(32, reason), mload(reason))
                  }
              }
          }
      } else {
          return true;
      }
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