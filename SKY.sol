// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import '@openzeppelin/contracts/finance/PaymentSplitter.sol';
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
    To-Do  
    * Remove multi merkle roots
    * Remove other special stuff about the CC0PY contract
    * Add Payment Splitter
    * If no reveal/unreaveal, remove all hiddenMetadataUri and mechanism associated with it.

    Info
    * There are public and WL mint. 
    * WL has only 1 root
    * Now, there is no limit for both public and WL
    * There are public mint stage, wl mint stage and reveal.
    * WL addresses has WL allowance and number of minted.

    Questions
    * Will there be any limit for each address to mint both per tx and total?
    --> Change: numberOfMints and numberOfAllowance mappings and require in the mint functions.
    * max supply?
    * Public and WL mint price?
    * Will start with reveal and no unreveal?
    * Token index starts from 0 or 1 ?? --> Change: contractor
    * Will WL mint all of their allowance at once? --> Change: Remove remaining allowance function
    * WL alloance? --> Change: wlAllowance
 */

/**
    @author 46f828e6f06dab230fd2aa5aab5f97dd47e11996586b01d9406444b3a228c647
*/

contract SKY is ERC721, ERC721Burnable, Ownable, PaymentSplitter, ReentrancyGuard {
    using Counters for Counters.Counter;
    using Strings for uint256;
  
    Counters.Counter private _tokenIdCounter;
  
    mapping(address => uint256) public numberOfMints;
    mapping(address => uint256) public numberOfAllowance;

    address[] private payees;
  
    bytes32 public merkleRoot;

    string private baseMetadataUri;
    string private hiddenMetadataUri;
  
    uint256 public maxSupply = 666;     // TEST
    uint256 public totalSupply;
    uint256 public wlMintPrice = 0.0099 ether;    // TEST
    uint256 public publicMintPrice = 0.0099 ether;    // TEST
    uint256 public wlAllowance = 5;    // TEST
  
    bool public isWhitelistMintOpen = false;
    bool public isPublicMintOpen = false;
    bool public isRevealed = true;
  
    constructor(
        address[] memory _payees, 
        uint256[] memory _shares,
        string memory _baseMetadataUri, 
        string memory _hiddenMetadataUri
    ) ERC721("CC0PY", "CC0PY") PaymentSplitter(_payees, _shares) {
        payees = _payees;
        baseMetadataUri = _baseMetadataUri;
        hiddenMetadataUri = _hiddenMetadataUri;            
        _tokenIdCounter.increment();    // TEST 
    }
  
    modifier mintCompliance(uint256 _mintAmount) {
        require(_mintAmount > 0, "Invalid mint amount!");
        require(totalSupply + _mintAmount <= maxSupply, "Max supply exceeded!");
        _;
    }   
  
    function _baseURI() internal view override returns (string memory) {
        return baseMetadataUri;
    }
  
    /**
         @dev Returns the base URI. 
    */
    function baseURI() public view returns (string memory) {
        if (isRevealed)
            return baseMetadataUri;
        else 
            return hiddenMetadataUri;
    }
  
    /**
         @dev Retuns the token URI. 
    */
    function tokenURI(uint256 _tokenId) public view virtual override returns (string memory){        
        require(_exists(_tokenId), 'ERC721Metadata: URI query for nonexistent token');
  
        if (!isRevealed)
            return hiddenMetadataUri;
        
        return super.tokenURI(_tokenId);
    }
  
    /**
         @dev Public Mint. Provide transfer amount (price * mint amount) and mint amount. 
    */
    function publicMint(uint256 _mintAmount) public payable mintCompliance(_mintAmount) nonReentrant {
        require(_mintAmount == 1, "Mint amount can not exceed 1");      // TEST
        require(isPublicMintOpen, "The public mint is not open yet!");
        require(numberOfMints[_msgSender()] == 0, "You have already minted at least 1 NFT!");   // TEST
    
        numberOfMints[_msgSender()] = _mintAmount;
  
        _safeMint(_msgSender()); // TEST -> use for loop if mint more than 1 at once
    }

    /**
        @dev Whiltelist Mint. Provide transfer amount (price * mint amount), mint amount and merkleProof. 
    */  
    function whitelistMint(uint256 _mintAmount, bytes32[] calldata _merkleProof) 
    public payable mintCompliance(_mintAmount) nonReentrant returns (uint256){
        require(isWhitelistMintOpen, "The whitelist sale is not enabled!");
        
        bytes32 leaf = keccak256(abi.encodePacked(_msgSender()));
        uint256 allowance = MerkleProof.verify(_merkleProof, merkleRoot, leaf) ? wlAllowance : 0;

        require(numberOfAllowance[_msgSender()] > 0, "This address is not whitelisted!");
        require(numberOfAllowance[_msgSender()] >= numberOfMints[_msgSender()] + _mintAmount, "Number of allowance exceeded!");
  
        numberOfMints[_msgSender()] += _mintAmount;
        for (uint256 i = 0; i < _mintAmount; i++) {
            _safeMint(_msgSender());
        }
        return numberOfAllowance[_msgSender()] - numberOfMints[_msgSender()];
    }
  
    /**
        @dev increase tokenID and total supply before mint
     */
    function _safeMint(address to) internal virtual {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
  
        totalSupply++;
  
        super._safeMint(to, tokenId);
    }
    
    /**
        @dev Returns the remaining allowance of Whitelisted address
     */
    function remainingAllowance(bytes32[] calldata _merkleProof) public returns (uint256) {         
        bytes32 leaf = keccak256(abi.encodePacked(_msgSender()));
        uint256 allowance = MerkleProof.verify(_merkleProof, merkleRoot, leaf) ? wlAllowance : 0;    
        return allowance - numberOfMints[_msgSender()];
    }

    /**
        @dev Sets the whitelist mint status.
    */
    function setWhitelistMintOpen(bool _state) public onlyOwner {
        isWhitelistMintOpen = _state;
    }
    
    /**
        @dev Sets the Public mint status.
    */
    function setPublicMintOpen(bool _state) public onlyOwner {
        isPublicMintOpen = _state;
    }
    
    /**
        @dev Sets the reveal status of the collection.
    */
    function setRevealed(bool _state) public onlyOwner {
        isRevealed = _state;
    }
  
    /**
        @dev Updates base metadata URI.
    */
    function updateBaseMetadataUri(string memory _baseMetadataUri) public onlyOwner {
        baseMetadataUri = _baseMetadataUri;
    }
    
    /**
        @dev Updates the hidden metadata URI.
    */
    function updateHiddenMetadataUri(string memory _hiddenMetadataUri) public onlyOwner {
        hiddenMetadataUri = _hiddenMetadataUri;
    }
    
    /**
        @dev Updates Public mint price.
    */
    function updatePublicPrice(uint256 _newPrice) public onlyOwner {
        publicMintPrice = _newPrice;
    }

    /**
        @dev Updates Whitelist mint price.
    */
    function updateWLPrice(uint256 _newPrice) public onlyOwner {
        wlMintPrice = _newPrice;
    }
    
    /**
        @dev Updates the merkle root for whitelist.
    */
    function updateMerkleRoot(bytes32 _newRoot) public onlyOwner {
        merkleRoot = _newRoot;
    }
    
    /**
      @dev Releases ether from contract.
    */
    function releaseTotal() external nonReentrant {
        for(uint256 i; i < payees.length; ++i){
            release(payable(payees[i]));
        }
    }
}
